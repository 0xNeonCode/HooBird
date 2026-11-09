// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vod;
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vodozemac/vodozemac.dart' as olm;

import 'endpoints.dart';
import 'pickle_key.dart';
import 'policy_api.dart';

/// A binary built for a non-loopback server drops a saved session that still
/// points at another address. It does not call that old server.
Future<void> dropStoredSessionWhenBuildServerDiffers(SharedPreferences prefs) async {
  if (!buildEndpointsPinned) return;
  final stored = prefs.getString('homeserver');
  await prefs.setString('homeserver', buildHomeserver);
  await prefs.setString('policy_url', buildPolicyUrl);
  if (stored == null || stored == buildHomeserver) return;
  final directory = await getApplicationSupportDirectory();
  for (final name in ['hoobird.sqlite', 'hoobird.sqlite-wal', 'hoobird.sqlite-shm']) {
    final file = File(p.join(directory.path, name));
    if (file.existsSync()) file.deleteSync();
  }
}

Future<void> prepareDesktopDatabase() async {
  if (Platform.isLinux || Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}

Future<Client> openHoobirdClient() async {
  final directory = await getApplicationSupportDirectory();
  final database = await openDatabase(p.join(directory.path, 'hoobird.sqlite'));
  return Client(
    'HooBird',
    database: await MatrixSdkDatabase.init('hoobird', database: database),
  );
}

class HoobirdController extends ChangeNotifier {
  HoobirdController({
    required this.prefs,
    this.client,
    this.bootstrapError,
  }) {
    themeMode = _readTheme(prefs.getString('theme'));
    deviceId = prefs.getString('device_id') ?? _newDeviceId();
    policyUrl = resolvedEndpoint(prefs.getString('policy_url'), buildPolicyUrl);
    homeserver = resolvedEndpoint(prefs.getString('homeserver'), buildHomeserver);
    sendTyping = prefs.getBool('send_typing') ?? true;
    sendReceipts = prefs.getBool('send_receipts') ?? false;
    hideNotificationContent = prefs.getBool('hide_notification_content') ?? true;
  }

  final SharedPreferences prefs;
  Client? client;
  final String? bootstrapError;
  late ThemeMode themeMode;
  late String deviceId;
  late String policyUrl;
  late String homeserver;
  late bool sendTyping;
  late bool sendReceipts;
  late bool hideNotificationContent;
  bool busy = false;
  String? error;
  Map<String, dynamic>? me;
  String? recoveryKeyShownOnce;
  String? deviceEd25519;
  String fingerprintStatus = 'Fingerabdruck wird vorbereitet.';
  Future<olm.Account?>? _accountFuture;

  bool get loggedIn => client?.isLogged() ?? false;

  String? get accessToken => client?.accessToken;

  PolicyApi get api => PolicyApi(policyUrl);

  Future<void> login(String username, String password) async {
    final matrix = client;
    if (matrix == null) {
      error = bootstrapError ?? 'Der Matrix-Client ist nicht bereit.';
      notifyListeners();
      return;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      final rejected = endpointRejection(policyUrl) ?? endpointRejection(homeserver);
      if (rejected != null) {
        throw PolicyException(0, 'endpoint_rejected', rejected);
      }
      await prefs.setString('device_id', deviceId);
      await prefs.setString('policy_url', policyUrl);
      await prefs.setString('homeserver', homeserver);
      final payload = await api.login(username, password, deviceId);
      final token = payload['access_token'] as String?;
      final userId = payload['user_id'] as String?;
      final returnedDevice = payload['device_id'] as String? ?? deviceId;
      if (token == null || userId == null) {
        throw PolicyException(500, 'bad_login', 'Die Anmeldung lieferte keine Sitzung.');
      }
      final server = Uri.parse(homeserver);
      final current = matrix.homeserver;
      if (current == null || !sameEndpoint(current.toString(), homeserver)) {
        await matrix.checkHomeserver(server);
      }
      if (!matrix.isLogged()) {
        final account = await localAccount();
        if (account == null) {
          throw PolicyException(
            0,
            'fingerprint_unavailable',
            'Der Geräteschlüssel ist nicht bereit. Die Anmeldung wurde abgebrochen, damit kein anderer Schlüssel hochgeladen wird.',
          );
        }
        await matrix.init(
          newToken: token,
          newUserID: userId,
          newDeviceID: returnedDevice,
          newDeviceName: 'HooBird',
          newHomeserver: server,
          newOlmAccount: account.toPickleEncrypted(pickleKeyOf(userId)),
        );
        final uploaded = await matrix.encryption?.olmManager.uploadKeys(uploadDeviceKeys: true);
        if (uploaded != true) {
          throw PolicyException(
            0,
            'device_keys_rejected',
            'Die Geräteschlüssel wurden nicht angenommen. Die Anmeldung bleibt ohne diese Schlüssel.',
          );
        }
      }
      deviceId = returnedDevice;
      me = await api.me(token);
      recoveryKeyShownOnce = null;
    } on PolicyException catch (exc) {
      error = exc.message;
    } catch (exc) {
      error = 'Anmeldung fehlgeschlagen: $exc';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> refreshMe() async {
    final token = accessToken;
    if (token == null) return;
    try {
      me = await api.me(token);
      error = null;
    } on PolicyException catch (exc) {
      error = exc.message;
    }
    notifyListeners();
  }

  Future<void> logout() async {
    busy = true;
    notifyListeners();
    final matrix = client;
    try {
      if (matrix != null) {
        matrix.backgroundSync = false;
        try {
          await matrix.abortSync();
        } catch (_) {}
        // logout already closes the database. A second dispose races with
        // that close and the SDK logs database_closed.
        await matrix.logout();
      }
    } catch (_) {}
    me = null;
    recoveryKeyShownOnce = null;
    busy = false;
    notifyListeners();
  }

  Future<void> ensureRecoveryKey() async {
    final matrix = client;
    if (matrix == null || !matrix.isLogged()) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final state = await matrix.getCryptoIdentityState();
      if (state.initialized) {
        recoveryKeyShownOnce = null;
        error =
            'Die Krypto-Identität ist schon eingerichtet. Der bestehende Sicherungsschlüssel wird nicht erneut angezeigt und von diesem Zurücksetzen nicht ersetzt.';
      } else {
        final key = await matrix.initCryptoIdentity();
        recoveryKeyShownOnce = key;
      }
    } catch (exc) {
      error = 'Sicherungsschlüssel konnte nicht angelegt werden: $exc';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> setSendTyping(bool value) async {
    sendTyping = value;
    await prefs.setBool('send_typing', value);
    notifyListeners();
  }

  Future<void> setSendReceipts(bool value) async {
    sendReceipts = value;
    await prefs.setBool('send_receipts', value);
    notifyListeners();
  }

  Future<void> setHideNotificationContent(bool value) async {
    hideNotificationContent = value;
    await prefs.setBool('hide_notification_content', value);
    if (Platform.isAndroid) {
      const channel = MethodChannel('dev.hoobird.spike.hoobird/notify');
      try {
        await channel.invokeMethod<void>('lockscreen', {'hideContent': value});
      } on PlatformException {
        // The preference is still stored. Push delivery is not built.
      }
    }
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    themeMode = mode;
    await prefs.setString('theme', switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
    notifyListeners();
  }

  Future<void> prepareFingerprint() async {
    await localAccount();
    notifyListeners();
  }

  Future<olm.Account?> localAccount() {
    return _accountFuture ??= _loadAccount();
  }

  Future<olm.Account?> _loadAccount() async {
    try {
      await initVodozemac();
      var secret = prefs.getString('pending_olm_secret');
      if (secret == null || secret.length < 16) {
        final random = Random.secure();
        secret = List.generate(32, (_) => String.fromCharCode(33 + random.nextInt(90))).join();
        await prefs.setString('pending_olm_secret', secret);
      }
      final stored = prefs.getString('pending_olm_pickle');
      final account = stored == null
          ? olm.Account()
          : olm.Account.fromPickleEncrypted(
              pickle: stored,
              pickleKey: pickleKeyOf(secret),
            );
      if (stored == null) {
        await prefs.setString(
          'pending_olm_pickle',
          account.toPickleEncrypted(pickleKeyOf(secret)),
        );
      }
      deviceEd25519 = account.identityKeys.ed25519.toBase64();
      fingerprintStatus = deviceEd25519!;
      return account;
    } catch (_) {
      deviceEd25519 = null;
      fingerprintStatus = 'Fingerabdruck noch nicht verfügbar';
      return null;
    }
  }

  void setDeviceId(String value) {
    deviceId = value.trim();
    notifyListeners();
  }

  void setEndpoints({required String policy, required String server}) {
    policyUrl = policy.trim();
    homeserver = server.trim();
    notifyListeners();
  }

  static ThemeMode _readTheme(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static String _newDeviceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(4, (_) => random.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'HB${hex.toUpperCase()}';
  }
}

Future<void> initVodozemac() async {
  if (olm.isInitialized()) return;
  if (Platform.isLinux) {
    final executableDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = [
      p.join(executableDir, 'lib'),
      executableDir,
      p.join(Directory.current.path, 'build/linux/x64/release/bundle/lib'),
    ];
    for (final dir in candidates) {
      if (File(p.join(dir, 'libvodozemac_bindings_dart.so')).existsSync()) {
        await vod.init(libraryPath: dir.endsWith('/') ? dir : '$dir/');
        return;
      }
    }
  }
  await vod.init();
}
