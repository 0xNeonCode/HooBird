// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vod;
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'policy_api.dart';

const defaultPolicyUrl = 'http://127.0.0.1:18018';
const defaultHomeserver = 'http://127.0.0.1:18008';

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
    policyUrl = prefs.getString('policy_url') ?? defaultPolicyUrl;
    homeserver = prefs.getString('homeserver') ?? defaultHomeserver;
  }

  final SharedPreferences prefs;
  Client? client;
  final String? bootstrapError;
  late ThemeMode themeMode;
  late String deviceId;
  late String policyUrl;
  late String homeserver;
  bool busy = false;
  String? error;
  Map<String, dynamic>? me;
  String? recoveryKeyShownOnce;

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
      if (matrix.homeserver == null) {
        await matrix.checkHomeserver(server);
      }
      if (!matrix.isLogged()) {
        await matrix.init(
          newToken: token,
          newUserID: userId,
          newDeviceID: returnedDevice,
          newDeviceName: 'HooBird',
          newHomeserver: server,
        );
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
    try {
      await client?.logout();
    } catch (_) {
      await client?.clear();
    }
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

  Future<void> setTheme(ThemeMode mode) async {
    themeMode = mode;
    await prefs.setString('theme', switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
    notifyListeners();
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
