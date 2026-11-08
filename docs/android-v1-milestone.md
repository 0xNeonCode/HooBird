# Android-Meilenstein

Dieser Stand ist ein lauffähiger erster Schritt zur vereinbarten Android-App. Er ist nicht die fertige Version 1, kein Store-Release und keine Sicherheitsfreigabe. Ein externes Audit und eine Prüfung auf echten Geräten fehlen.

## Gebaut

- Flutter-App für Android mit den Reitern Chats, Kontakte und Einstellungen, Eule nur an der Übersicht und am Start, Hell, Dunkel und System. Deutsch. Keine fest eingebauten Beispielkontakte.
- Anmeldung über die Policy-API. Das Gerät erzeugt sein Olm-Konto vor der Anmeldung und zeigt die ed25519-Kennung. Die Anmeldung übergibt genau dieses Konto an das Matrix-SDK. Das SDK lädt nach einem übergebenen Konto nicht von selbst die Geräteschlüssel hoch. Die App ruft deshalb anschließend `uploadKeys(uploadDeviceKeys: true)` auf. Einmal-Schlüssel ohne schon veröffentlichten, passenden Geräteschlüssel lehnt der Server ab. Ein Kinderkonto kommt an diesen Upload erst heran, nachdem ein Elternteil die angezeigte ed25519-Kennung gespeichert hat.
- Direkt- und Gruppenräume, Text und JPEG. Vor dem Senden eines JPEG werden APP1-, APP13- und Kommentar-Segmente entfernt. Das nimmt EXIF, XMP und GPS aus diesen Segmenten. Sprachnachrichten, Antworten, Reaktionen und die übrigen Bequemlichkeiten der Zielversion sind nicht in dieser Oberfläche.
- Mehrere Geräte über Matrix. Der Sicherungsschlüssel ist der persönliche Schlüssel des Kontos. Ein Passwort-Reset gibt ihn nicht zurück. Eltern lesen keine Nachrichten und bekommen keine Schlüssel.
- Serverseitig: gespeicherte ed25519-Kennung, Ablehnung eines anderen Schlüssel-Uploads, Ablehnung von Einmal-Schlüsseln bevor der passende Geräteschlüssel veröffentlicht ist, Ablehnung der Kinderanmeldung wenn die Umwicklung von `upload_keys_for_user` nicht sitzt, und ein wiederholter Rauswurf des gesperrten Kontakts aus den schon betretenen Räumen des Kindes.
- Quelltext und Lizenzhinweis in der App, einschließlich AGPL Abschnitt 13 für einen veränderten Netzbetrieb. Die Kombination bleibt AGPL-3.0, weil `flutter_vodozemac` 0.9.0 keine geprüfte „or-later“-Zeile hat. Ein privater Meldeweg ist nicht eingeschaltet. Die App nennt deshalb keine Melde-URL.

## Nicht gebaut

Antworten und Sprung zur Stelle, Reaktionen, sichtbares Bearbeiten und Löschen, Weiterleiten und Mehrfachauswahl, Suche, Anheften, Archiv, Stummschalten, Lesebestätigungen, Tippen, Sprachnachricht mit Vorschau, Sperre und Geschwindigkeit, Bildvorschau über den Dateinamen hinaus, Gruppenverwaltung, Erwähnungen, kontrollierte Einladungen in der Oberfläche, Blockieren und Melden mit ausgewähltem Inhalt, Push ohne Klartext, QR für die Elternverknüpfung, SAS- oder QR-Abgleich, Bluetooth, Umfragen, allgemeine Dateien, verschwindende Nachrichten, Anrufe, Produktionssignatur, Store, externer Audit.

Löschen, soweit es später kommt, holt keine schon gesehene oder abfotografierte Kopie zurück. Das steht in der Lizenzseite, auch ohne eine Löschfunktion.

## Was ein Test belegen kann und was nicht

Die frischen Läufe dieses Commits stehen unten, sobald sie ausgeführt sind. Ein bestandener Test ist keine Aussage, dass ein generischer Client keinen Weg an der Richtlinie vorbei findet, den der Test nicht aufgerufen hat. Die Umwicklung von `upload_keys_for_user` ist ein Prozess-Hack, weil Synapse 1.163 dafür keinen Modul-Callback hat. Sie gilt für diesen Prozess. Ein anderer Homeserver oder ein Update, das die Methode anders aufruft, ist nicht abgedeckt. Die Sperre und der Rauswurf sind keine gemeinsame Transaktion. Der Eltern-QR beweist weder Alter noch Sorgeberechtigung und ist hier nicht gebaut.

## Frische Läufe

Ausgeführt am 2026-11-08 auf dem isolierten Loopback-Stack (Synapse `127.0.0.1:18008`, Policy `127.0.0.1:18018`). Ältere Zählungen aus der Veröffentlichung werden hier nicht wiederholt.

- `python3 -m pytest`: 30 bestanden, 0 fehlgeschlagen, 60,23 s. Darin verschlüsselter Text, Gruppe, JPEG ohne GPS-Segment, WAV, zweites Gerät, sowie die Ablehnung eines falschen Geräteschlüssels, von Einmal-Schlüsseln vor dem Geräteschlüssel, eines zweiten Fingerabdrucks und der Einladungs-Sperre nach dem Rauswurf.
- `flutter analyze`: keine Beanstandungen.
- `flutter test test/widget_test.dart test/media_prep_test.dart`: 4 bestanden. Die Widget-Tests laden die native Vodozemac-Bibliothek nicht. Die ed25519-Zeile bleibt dort „noch nicht verfügbar“.
- `flutter test test/recovery_live_test.dart`: 1 bestanden. Der Test legt ein Kindergerät mit der angezeigten ed25519-Kennung an, sendet einen verschlüsselten Text, stellt ihn mit dem persönlichen Sicherungsschlüssel auf einem zweiten Gerät wieder her, lehnt einen falschen Schlüssel ab, prüft dass ein Passwort-Reset den Sicherungsschlüssel nicht zurückgibt, und liest nach dem Reset nur mit demselben Schlüssel. Der automatische Einmal-Schlüssel-Upload des SDK vor dem Geräteschlüssel wurde mit `device_keys_required` abgelehnt. Das ist die gewollte Sperre. Beim Schließen der Test-Clients schrieb das SDK `database_closed`. Die Prüfungen davor waren schon bestanden. Bild und Ton sind in diesem Dart-Lauf nicht enthalten.
- `flutter build apk --debug`: gebaut, `app/build/app/outputs/flutter-apk/app-debug.apk`, 180242872 Bytes, SHA-256 `ef3a4ca333a5d5c95d1b2c5a728f405244e41cf826e29b0f6dbca5f8099371a0`. Enthält arm64-v8a, armeabi-v7a und x86_64. Debug-signiert, kein Store-Build, kein Produktionsschlüssel. Die Ablage für Übertragungsdateien hat diese Größe abgelehnt. Eine Kopie nur mit arm64-v8a wurde mit dem lokalen Android-Debug-Keystore neu signiert: `hoobird-arm64-debug-non-production.apk`, 96214047 Bytes, SHA-256 `f3b2a649a7897aaf849c7c6bbeb73d8060fea0f475eeced9a17078e820824753`.
- `flutter build linux --release`: gebaut. Dient der nativen Bibliothek für den Wiederherstellungstest und den Fenstern unten. Kein Android-Emulator-Systemabbild ist installiert, und es wurde kein Emulator und kein physisches Gerät gestartet.
- Dieselben Flutter-Fenster, hell und dunkel, gegen den lokalen Stack: Start mit echter ed25519-Zeile, leere Chatliste nach Anmeldung eines synthetischen Erwachsenenkontos, Kontakte, Einstellungen. Keine Beispielkontakte, kein Passwort im Bild.

Ein bestandener Lauf ersetzt kein externes Audit und keine Prüfung auf einem echten Android-Gerät.

`gitleaks` 8.28.0 fand in den zwei bisherigen Commits nichts. Ein Scan des Arbeitsbaums fand 33 Treffer, alle in ignorierten lokalen Dateien: Laufzeitumgebung, generiertes Homeserver-YAML und Build-Artefakte. Diese Dateien werden nicht eingecheckt.
