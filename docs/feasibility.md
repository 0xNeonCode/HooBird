# Machbarkeit

Stand der Prüfung: 7. November 2026. Das ist ein begrenzter Prototyp auf einer wegwerfbaren lokalen Maschine. Bestandene Tests sind kein Audit, keine Kapazitätsaussage und keine Freigabe für eine geschlossene Beta.

## SDK-Vergleich

### Famedly Dart, benutzt

| Paket | Version | Veröffentlicht | Lizenz | Grenze |
| --- | --- | --- | --- | --- |
| `matrix` | 16.0.1 | 2026-11-06 | AGPL-3.0-or-later | Dart `>=3.11 <4` |
| `flutter_vodozemac` | 0.9.0 | 2026-10-19 | AGPL-3.0-Text im Archiv; „or-later“ im Paket nicht gefunden | Flutter `>=3.38`, Dart `^3.10` |
| Rust-Crate `vodozemac` im Binding | 0.10.0, festgenagelt in `Cargo.toml` des Pakets | — | das Upstream-Repo `matrix-org/vodozemac` ist Apache-2.0; `main` stand am selben Tag bei 0.11.2 | das Binding kompiliert 0.10.0, nicht automatisch 0.11.2 |

Quelle der Pakete: pub.dev. Die Binding-Lizenz ist die LICENSE-Datei im pub-cache-Archiv 0.9.0. Eine SPDX-Zeile „or-later“ steht dort nicht. Die Tabelle vom 7. November 2026 hatte für dieses Paket „AGPL-3.0-or-later“ genannt. Das Inventar vom 8. November 2026 korrigiert das. `matrix` 16.0.1 nennt in der `pubspec.yaml` weiterhin `AGPL-3.0-or-later` und `SPDX-FileCopyrightText: 2019-Present Famedly GmbH`. Die Crate `vodozemac` 0.10.0 hat in der lokal entpackten `Cargo.toml` `license = "Apache-2.0"`.

`flutter_vodozemac` hat Linux, Android, iOS, macOS und Windows als FFI-Plugin. Android kompiliert das Rust-Crate über cargokit und das NDK. `compileSdk` ist 36, `minSdk` 19. Es gibt kein mitgeliefertes Android-AAR, das wir nur einbinden. iOS und macOS haben zusätzlich ein vorgebautes Binärpaket. Für Android gilt das nicht.

Die öffentliche Einrichtung im SDK 16 ist `Client.initCryptoIdentity()` und `Client.restoreCryptoIdentity()`. `KeyManager.loadAllKeys()` liest die serverseitige Megolm-Kopie, nachdem der Sicherungsschlüssel sie öffnen kann. Das ist die Bibliothek, nicht selbst gebaute Kryptografie.

Eigener Code ist auf AGPL-3.0-or-later gesetzt. Die Begründung steht in `COPYRIGHT.md`. Synapse 1.163.0 trägt im Image den Ausdruck `AGPL-3.0-or-later OR LicenseRef-Element-Commercial`. Genutzt wird die AGPL-Seite. Eine Element-Commercial-Lizenz liegt nicht vor.

### matrix-rust-sdk, nicht benutzt

Am 7. November 2026 listet `bindings/README.md` auf `matrix-org/matrix-rust-sdk` `main` die von den Maintainern gepflegten Bindings: Swift über `apple`, UniFFI für die Krypto-Crate (Kotlin, Swift, Python, Ruby) und UniFFI für das SDK. Zusätzlich genannt werden externe WASM- und Node.js-Bindings der Krypto-Crate. Ein Dart-Binding steht dort nicht.

Eine eigene Dart-Brücke wäre kein etabliertes Binding und liegt außerhalb dieses Meilensteins. Deshalb bleibt der Flutter-Weg bei Famedly plus Vodozemac.

### Generischer Testclient

`matrix-nio` 0.26.0 mit Extra `e2e` spricht Vodozemac. Die Lizenz von nio ist ISC. Diese Version hat keine Cross-Signing-API und keine Wiederherstellung einer serverseitigen Schlüsselkopie. `AsyncClient` hat weder `restore_key_backup` noch `load_all_keys`. Nio beweist Megolm gegen den Server. Es beweist nicht die Schlüsselwiederherstellung. Dafür ist der Dart-Test da.

## Was Synapse 1.163.0 wirklich anbietet

Geprüft in `matrixdotorg/synapse:v1.163.0`.

Vorhandene Spam-Checker-Callbacks, die das Modul registriert: `check_event_for_spam`, `user_may_join_room`, `user_may_invite`, `federated_user_may_invite`, `user_may_send_3pid_invite`, `user_may_create_room`, `user_may_publish_room`, `check_media_file_for_spam`, `check_login_for_spam`, `should_drop_federated_event`.

`user_may_join_room` gilt nicht für den Admin-Join und nicht für das Anlegen des Raums. `check_login_for_spam` läuft beim Login, nicht bei der Registrierung. `device_id` ist dort die Gerätekennung der Sitzung.

Zusätzlich, weil der Spam-Checker den Raumzustand nicht mitliefert: Third-Party-Rules `check_event_allowed` und `on_create_room`. `check_event_allowed` ist in Synapse als experimentell gekennzeichnet. Der Prototyp benutzt es trotzdem, weil nur dort der aktuelle Zustand ankommt. `on_create_room` erzwingt nicht-föderiert, privat, Megolm, Einladung, Historie `joined`, kein Gastzugang.

Nicht vorhanden und deshalb nicht gehookt: ein Modul-Callback für `/keys/upload`, `/keys/device_signing/upload` und `/keys/signatures/upload`. Nach dem Widerruf löscht der Policy-Dienst das Synapse-Gerät. Das alte Token stirbt. Ein neues Login mit derselben freigegebenen Kennung ist wieder möglich. Die Kennung ist kein Fingerabdruck.

Föderation ist serverseitig aus: kein Federation-Listener, `federation_domain_whitelist: []`, `should_drop_federated_event` liefert wahr, Räume werden auf `m.federate: false` gezwungen, `trusted_key_servers: []`. Der Test ruft die Federation-Version und einen Join nach `#matrix:matrix.org` auf.

Registrierung ist aus. Konten entstehen über die Policy-API und das Admin-API. Ein Passwort-Reset ruft nicht den Admin-Endpunkt auf, der den Cross-Signing-Master ersetzt.

## Tests

Befehle aus `/workspace`, Stack bereits healthy:

```bash
.venv/bin/pytest -q
cd app && flutter test test/widget_test.dart
cd app && flutter build linux
cd app && flutter test test/recovery_live_test.dart
```

| Prüfung | Art | Ergebnis |
| --- | --- | --- |
| Reine Richtlinienregeln, Block gegen erneute Freigabe, Medienmagie, EXIF-Entfernung vor der Verschlüsselung | Unit, ohne Netz | bestanden, Teil von `pytest` |
| Registrierung aus, Föderation abgelehnt, Kinderkonto darf kein Erwachsenenkonto anlegen, Matrix-ID bleibt bei Namenswechsel, E-Mail beweist keine Identität, generischer Client scheitert an unerlaubter Direktnachricht, Gruppe, Sperre, zweitem Elternteil, Geschwister nur bei gegenseitiger Freigabe, nicht eingeladenes Elternteil kommt nicht in den Raum, Wettlauf lässt Inhalt danach scheitern, Kindergerät ohne Freigabe kommt nicht herein, Widerruf macht `/keys/upload` zu 401, JPEG-Upload abgelehnt, Zufallsbytes angenommen, Historie und Join-Regel nicht aufweichbar, 3pid-Einladung abgelehnt | Integration gegen Synapse und Policy | bestanden, Teil von `pytest` |
| Datenbankdump der Policy-Konten und von `event_json` in eine zweite Datenbank, Signierschlüssel ist eine Datei und enthält nicht das Wort recovery | Integration, live Daten bleiben stehen | bestanden, Teil von `pytest` |
| Megolm-Text in einer Gruppe mit Kind und freigegebenem Erwachsenen, zweites Gerät, Bild und WAV verschlüsselt hochgeladen, Marker nicht in `event_json`, neues Mitglied sieht das alte Ereignis nicht | Integration mit matrix-nio | bestanden: `tests/test_e2ee.py` |
| Nio hat keine Backup-API | Unit | bestanden |
| Widget: Start zeigt HooBird, nicht „Uhats“; Sicherheitszeile trennt Verschlüsselung von Verifikation | Flutter-Widget, kein Server | bestanden |
| Dart-SDK: ohne lebendes Gerät kein Klartext; falscher Sicherungsschlüssel scheitert; richtiger stellt den Text wieder her; Passwort-Reset gibt den Schlüssel nicht zurück und der neue Login liest ohne Schlüssel nichts; nach `initCryptoIdentity` verbindet der alte Schlüssel nicht mehr, der neue liest alte und neue Nachricht, weil das drehende Gerät die lokale Sitzung neu hochlädt | Flutter-Test gegen den lokalen Server, `test/recovery_live_test.dart` | bestanden, etwa 2 s Laufzeit nach aufgebautem Native-Code |
| Linux-Client gegen den Seed-Raum | manuell unter Xvfb, kein Emulator | die Oberfläche zeigte den Raum „Familie“, die Zeile „Verschlüsselt · Identität nicht verifiziert“, fremde Ereignisse als „Schlüssel auf diesem Gerät nicht vorhanden“ und die eigene gesendete Zeile im Klartext. `event_json` enthielt diese Zeile 0-mal |
| Physisches Android, APK, Emulator | — | nicht ausgeführt. `flutter doctor` findet kein Android-SDK |
| QR, SAS, Bluetooth, Push, Antworten, Reaktionen, Suche, Anheften, Meldungsfluss | — | nicht gebaut |
| To-Device-Weitergabe, solange das erste Gerät online bleibt | beobachtet, nicht als stabiler Test festgehalten | ein früher Lauf zeigte den Klartext auf dem zweiten Gerät ohne `restoreCryptoIdentity`. Ein späterer Lauf hat das nicht als stabile Erwartung wiederholt. Der automatisierte Test stoppt das erste Gerät, bevor das zweite kommt |

Der letzte vollständige `pytest`-Lauf endete mit 26 bestandenen Tests in 55,52 s. Das Protokoll liegt in `docs/evidence/pytest.txt`. Ein grüner Lauf ist keine Aussage über ungetestete Pfade.

## Grenzen, die bleiben

- Die Mitgliedschaftsprüfung und das Schreiben des Ereignisses sind keine Transaktion. Der Wettlauf ist getestet: Inhalt danach scheitert, die Mitgliedschaft kann kurz falsch sein.
- Die Medienprüfung sieht nur den Anfang der Datei.
- Die Form von `m.room.encrypted` ist keine Prüfung, dass Vodozemac den Inhalt erzeugt hat.
- Ein Elternteil, das selbst im Raum sitzt, entschlüsselt mit den eigenen Schlüsseln. Das ist Teilnahme, keine Admin-Schnittstelle. Die Policy-Antwort setzt `messages_included` und `keys_included` auf falsch.
- EXIF wird vor dem Verschlüsseln entfernt. Der Server kann EXIF im Geheimtext nicht sehen und nicht entfernen.
- `bcrypt_rounds: 4` und die Geheimnisse in Compose sind nur für diese Wegwerfdatenbank.
- Passwort-Reset eines Elternkontos ist nicht implementiert.
- Die Linux-Oberfläche zeigt echte SDK-Zustände. Sie enthält nicht die spätere Produktliste.

## Empfehlung

Weiter am privaten Prototyp mit Famedly `matrix` 16.0.1 und `flutter_vodozemac` 0.9.0. Nicht mit einer selbst gebauten Dart-Brücke zum Rust-SDK.

Nicht weiter in eine geschlossene Beta oder eine Veröffentlichung. Davor fehlen mindestens: ein Lauf auf physischen Android-Geräten, eine Entscheidung zur Gerätebindung jenseits der Kennung, ein klares Verhalten für den Wettlauf und für spätere Gruppenänderungen, QR/SAS nur mit dem SDK und nicht selbst erfunden, ein richtiger Umgang mit der AGPL, Push ohne Klartext, und eine Überprüfung durch jemand anderen als diesen Prototyp. Kapazität ist nicht gemessen und wird nicht geschätzt.
