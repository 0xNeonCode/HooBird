// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'package:flutter_test/flutter_test.dart';
import 'package:hoobird/main.dart';
import 'package:hoobird/security_label.dart';
import 'package:hoobird/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Startbild zeigt HooBird und korrigiert nicht den Bildfehler Uhats', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final controller = HoobirdController(prefs: prefs);
    await tester.pumpWidget(HoobirdApp(controller: controller));
    expect(find.text('HooBird'), findsOneWidget);
    expect(find.text('Anmelden'), findsOneWidget);
    expect(find.text('Uhats'), findsNothing);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Hell'), findsOneWidget);
    expect(find.text('Dunkel'), findsOneWidget);
  });

  test('Sicherheitszeile trennt Verschlüsselung von Identitätsprüfung', () {
    expect(
      securityLabel(encrypted: true, identityVerified: false),
      'Verschlüsselt · Identität nicht verifiziert',
    );
    expect(
      securityLabel(encrypted: true, identityVerified: true),
      'Verschlüsselt · Identität verifiziert',
    );
    expect(
      securityLabel(encrypted: false, identityVerified: true),
      'Nicht verschlüsselt',
    );
  });
}
