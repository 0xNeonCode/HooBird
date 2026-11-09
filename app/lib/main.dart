// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'endpoints.dart';
import 'session.dart';
import 'theme.dart';
import 'ui/gate.dart';
import 'ui/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await prepareDesktopDatabase();
  final prefs = await SharedPreferences.getInstance();
  String? bootstrapError;
  Client? client;
  try {
    final rejected = endpointRejection(buildHomeserver) ?? endpointRejection(buildPolicyUrl);
    if (rejected != null) {
      throw StateError(rejected);
    }
    await dropStoredSessionWhenBuildServerDiffers(prefs);
    await initVodozemac();
    client = await openHoobirdClient();
    final stored = resolvedEndpoint(prefs.getString('homeserver'), buildHomeserver);
    await client.init(
      newHomeserver: Uri.parse(stored),
    );
  } catch (exc) {
    bootstrapError = 'Start fehlgeschlagen: $exc';
    client = null;
  }
  runApp(
    HoobirdApp(
      controller: HoobirdController(
        prefs: prefs,
        client: client,
        bootstrapError: bootstrapError,
      ),
    ),
  );
}

class HoobirdApp extends StatelessWidget {
  const HoobirdApp({super.key, required this.controller});

  final HoobirdController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'HooBird',
          theme: hoobirdTheme(Brightness.light),
          darkTheme: hoobirdTheme(Brightness.dark),
          themeMode: controller.themeMode,
          home: controller.loggedIn
              ? HomeShell(controller: controller)
              : GatePage(controller: controller),
        );
      },
    );
  }
}
