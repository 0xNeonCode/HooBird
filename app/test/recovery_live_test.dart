// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vod;
import 'package:http/http.dart' as http;
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:hoobird/pickle_key.dart';
import 'package:vodozemac/vodozemac.dart' as olm;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const policyBase = 'http://127.0.0.1:18018';
const homeserver = 'http://127.0.0.1:18008';

/// Passwort des lokalen Bootstrap-Admins. Es kommt aus der Umgebung und ist
/// nur für den Compose-Stack gültig, der mit derselben Datei gestartet wurde.
/// Passwort, das dieser Lauf für ein frisch angelegtes lokales Konto vergibt.
/// Es steht nicht im Quelltext und gilt nur für diesen Testlauf.
String _disposablePassword() {
  final bytes = List<int>.generate(18, (_) => Random.secure().nextInt(256));
  return 'local-${base64Url.encode(bytes)}';
}

String get adminPassword {
  final value = Platform.environment['HOOBIRD_ADMIN_PASSWORD'] ??
      Platform.environment['ADMIN_PASSWORD'];
  if (value == null || value.isEmpty) {
    throw StateError(
      'ADMIN_PASSWORD fehlt. Wert aus runtime/localhost.env exportieren. '
      'Er gilt nur für den lokalen Stack.',
    );
  }
  return value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Sicherungsschlüssel stellt Megolm wieder her, falscher Schlüssel und Passwort-Reset nicht',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      HttpOverrides.global = null;
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      Logs().level = Level.warning;
      final libraryDir = Directory('build/linux/x64/release/bundle/lib');
      final library = File('${libraryDir.path}/libvodozemac_bindings_dart.so');
      expect(
        library.existsSync(),
        isTrue,
        reason: 'Zuerst flutter build linux ausführen, damit libvodozemac_bindings_dart.so existiert.',
      );
      await vod.init(libraryPath: '${libraryDir.path}/');

      final httpClient = http.Client();
      final root = await Directory.systemTemp.createTemp('hoobird-recovery-');
      final clients = <Client>[];
      final parentPassword = _disposablePassword();
      var password = _disposablePassword();
      final resetPassword = _disposablePassword();
      try {
        final admin = await _policyLogin(httpClient, 'hoobird-admin', adminPassword, 'ADMINREC01');
        final suffix = Random().nextInt(1 << 32).toRadixString(16);
        final parent = await _create(
          httpClient,
          admin['access_token'] as String,
          username: 'eltern$suffix',
          password: parentPassword,
          role: 'parent',
        );
        final parentToken = (await _policyLogin(
          httpClient,
          parent['username'] as String,
          parentPassword,
          'ELTERNREC01',
        ))['access_token'] as String;
        final child = await _create(
          httpClient,
          parentToken,
          username: 'kind$suffix',
          password: password,
          role: 'child',
        );
        final childId = child['user_id'] as String;
        final childName = child['username'] as String;

        final first = await _loginChild(
          root,
          httpClient,
          parentToken,
          'kind1',
          childName,
          childId,
          password,
          'RECKIND01',
        );
        clients.add(first);
        final recoveryKey = await first.initCryptoIdentity();
        expect(recoveryKey.length, greaterThan(20));
        final state = await first.getCryptoIdentityState();
        expect(state.initialized, isTrue);
        expect(state.connected, isTrue);

        final roomId = await first.createRoom(
          name: 'Wiederherstellung',
          preset: CreateRoomPreset.privateChat,
          creationContent: {'m.federate': false},
          visibility: Visibility.private,
        );
        final room = await _waitEncrypted(first, roomId);
        final marker = 'Recovery-Marker-$suffix';
        final eventId = await room.sendTextEvent(marker);
        expect(eventId, isNotNull);
        final sentId = eventId!;
        await _waitBackup(first);
        // No live device remains, so a new login cannot be handed the session
        // by the sender. An earlier run saw plaintext while the sender stayed
        // online; that path is recorded as observed, not as this assertion.
        await _stop(first);

        final second = await _loginChild(
          root,
          httpClient,
          parentToken,
          'kind2',
          childName,
          childId,
          password,
          'RECKIND02',
        );
        clients.add(second);
        final before = await second.getRoomById(roomId)!.getEventById(sentId);
        expect(before, isNotNull);
        expect(before!.body.contains(marker), isFalse);
        expect(
          before.type == EventTypes.Encrypted || before.messageType == MessageTypes.BadEncrypted,
          isTrue,
        );

        await expectLater(
          second.restoreCryptoIdentity('${recoveryKey.substring(0, recoveryKey.length - 1)}x'),
          throwsA(anything),
        );
        expect((await second.getCryptoIdentityState()).connected, isFalse);

        await second.restoreCryptoIdentity(recoveryKey);
        await second.encryption!.keyManager.loadAllKeys();
        final restored = await second.getRoomById(roomId)!.getEventById(sentId);
        expect(restored!.body, marker);
        await _stop(second);

        final reset = await httpClient.post(
          Uri.parse('$policyBase/_hoobird/v1/accounts/${Uri.encodeComponent(childId)}/reset-password'),
          headers: {
            'authorization': 'Bearer $parentToken',
            'content-type': 'application/json',
          },
          body: jsonEncode({'new_password': resetPassword}),
        );
        expect(reset.statusCode, 200, reason: reset.body);
        expect(reset.body.contains('recovery_key'), isTrue);
        expect(reset.body.contains('"recovery_key_returned":false'), isTrue);
        expect(reset.body.contains(recoveryKey), isFalse);
        password = resetPassword;

        final third = await _loginChild(
          root,
          httpClient,
          parentToken,
          'kind4',
          childName,
          childId,
          password,
          'RECKIND04',
        );
        clients.add(third);
        final withoutKey = await third.getRoomById(roomId)!.getEventById(sentId);
        expect(withoutKey!.body.contains(marker), isFalse);
        await third.restoreCryptoIdentity(recoveryKey);
        await third.encryption!.keyManager.loadAllKeys();
        final afterReset = await third.getRoomById(roomId)!.getEventById(sentId);
        expect(afterReset!.body, marker);

        final replacement = await third.initCryptoIdentity();
        expect(replacement, isNot(recoveryKey));
        final marker2 = 'Neue-Identitaet-$suffix';
        final roomAgain = third.getRoomById(roomId)!;
        final event2 = await roomAgain.sendTextEvent(marker2);
        await _waitBackup(third);
        await _stop(third);

        final fourth = await _loginChild(
          root,
          httpClient,
          parentToken,
          'kind5',
          childName,
          childId,
          password,
          'RECKIND05',
        );
        clients.add(fourth);
        await expectLater(fourth.restoreCryptoIdentity(recoveryKey), throwsA(anything));
        await fourth.restoreCryptoIdentity(replacement);
        await fourth.encryption!.keyManager.loadAllKeys();
        final oldEvent = await fourth.getRoomById(roomId)!.getEventById(sentId);
        final newEvent = await fourth.getRoomById(roomId)!.getEventById(event2!);
        // The device that rotates the crypto identity still holds the old
        // Megolm session and uploads it into the new backup. The old recovery
        // key no longer connects. The new key can read both messages.
        expect(oldEvent!.body, marker);
        expect(newEvent!.body, marker2);
      } finally {
        for (final client in clients) {
          try {
            await client.dispose();
          } catch (_) {}
        }
        httpClient.close();
        await root.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

void _bindUia(Client client, String Function() password) {
  final handled = <UiaRequest>{};
  client.onUiaRequest.stream.listen((request) {
    if (request.state != UiaRequestState.waitForUser) return;
    if (!handled.add(request)) return;
    if (!request.nextStages.contains(AuthenticationTypes.password)) return;
    final userId = client.userID;
    if (userId == null) return;
    request
        .completeStage(
          AuthenticationPassword(
            session: request.session,
            password: password(),
            identifier: AuthenticationUserIdentifier(user: userId),
          ),
        )
        .catchError((Object _) => null);
  });
}

Future<Client> _loginChild(
  Directory root,
  http.Client httpClient,
  String parentToken,
  String name,
  String username,
  String userId,
  String password,
  String deviceId,
) async {
  final account = olm.Account();
  await _authorize(
    httpClient,
    parentToken,
    userId,
    deviceId,
    account.identityKeys.ed25519.toBase64(),
  );
  final session = await _policyLogin(httpClient, username, password, deviceId);
  final database = await databaseFactory.openDatabase('${root.path}/$name.sqlite');
  final client = Client(
    name,
    database: await MatrixSdkDatabase.init(name, database: database),
  );
  _bindUia(client, () => password);
  await client.checkHomeserver(Uri.parse(homeserver));
  await client.init(
    newToken: session['access_token'] as String,
    newUserID: userId,
    newDeviceID: session['device_id'] as String? ?? deviceId,
    newDeviceName: name,
    newHomeserver: Uri.parse(homeserver),
    newOlmAccount: account.toPickleEncrypted(pickleKeyOf(userId)),
  );
  final uploaded = await client.encryption!.olmManager.uploadKeys(uploadDeviceKeys: true);
  expect(uploaded, isTrue, reason: 'Geräteschlüssel müssen vor dem Sicherungsschlüssel auf dem Server sein');
  return client;
}

Future<void> _stop(Client client) async {
  client.backgroundSync = false;
  try {
    await client.abortSync();
  } catch (_) {}
  // Give the sync that abortSync cannot cancel a moment to leave the
  // database. logout closes it. dispose would close it again.
  await Future<void>.delayed(const Duration(milliseconds: 200));
  try {
    await client.logout();
  } catch (_) {}
}

Future<Room> _waitEncrypted(Client client, String roomId) async {
  for (var i = 0; i < 20; i++) {
    final room = client.getRoomById(roomId);
    if (room != null && room.encrypted) return room;
    await client.oneShotSync();
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  throw TestFailure('Raum wurde nicht als verschlüsselt sichtbar');
}

Future<void> _waitBackup(Client client) async {
  Object? last;
  for (var i = 0; i < 20; i++) {
    try {
      await client.encryption!.keyManager.uploadInboundGroupSessions();
      await client.encryption!.keyManager.getRoomKeysBackupInfo();
      return;
    } catch (exc) {
      last = exc;
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  }
  throw TestFailure('Schlüsselbackup nicht erreichbar: $last');
}

Future<Map<String, dynamic>> _policyLogin(
  http.Client httpClient,
  String username,
  String password,
  String deviceId,
) async {
  final response = await httpClient.post(
    Uri.parse('$policyBase/_hoobird/v1/login'),
    headers: {'content-type': 'application/json'},
    body:
        '{"username":"$username","password":"$password","device_id":"$deviceId","device_name":"HooBird"}',
  );
  expect(response.statusCode, 200, reason: response.body);
  return Map<String, dynamic>.from(_json(response.body) as Map);
}

Future<Map<String, dynamic>> _create(
  http.Client httpClient,
  String token, {
  required String username,
  required String password,
  required String role,
  String? deviceId,
}) async {
  final device = deviceId == null ? '' : ',"device_id":"$deviceId"';
  final response = await httpClient.post(
    Uri.parse('$policyBase/_hoobird/v1/accounts'),
    headers: {
      'authorization': 'Bearer $token',
      'content-type': 'application/json',
    },
    body: '{"username":"$username","password":"$password","role":"$role"$device}',
  );
  expect(response.statusCode, 200, reason: response.body);
  return Map<String, dynamic>.from(_json(response.body) as Map);
}

Future<void> _authorize(
  http.Client httpClient,
  String token,
  String childId,
  String deviceId,
  String ed25519,
) async {
  final response = await httpClient.post(
    Uri.parse('$policyBase/_hoobird/v1/children/${Uri.encodeComponent(childId)}/devices'),
    headers: {
      'authorization': 'Bearer $token',
      'content-type': 'application/json',
    },
    body: '{"device_id":"$deviceId","ed25519":"$ed25519"}',
  );
  expect(response.statusCode, 200, reason: response.body);
}

Object? _json(String body) {
  return body.isEmpty ? <String, dynamic>{} : jsonDecode(body);
}
