# Xiaomi-Check heute Abend

Kurze Liste für ein physisches Xiaomi (arm64). Das ist ein Debug-Stand, kein Store-Build und keine Sicherheitsfreigabe.

## Welche App, welcher Server

Die Datei für das Xiaomi heißt `hoobird-arm64-v8a-debug-testserver-4.apk`. Sie ist debug-signiert. Es ist kein Produktionsschlüssel und keine Store-Fassung. SHA-256 `0f1e7a895fc664daf6507fca8da52edfce4a21c4995e8c9305f29666cc3a7b01`, 81642424 Bytes. Dieselbe Zeile steht in `docs/android-v1-milestone.md` unter dem achten Lauf. Die vorherige Testserver-Datei `hoobird-arm64-v8a-debug-testserver-3.apk` bleibt liegen, SHA-256 `0eaaf2a0115719f3a38bd1ec8f342bbf93fbbe4a852ee4441ab643a2031a769d`. `hoobird-arm64-v8a-debug-testserver-2.apk` bleibt liegen, SHA-256 `af4e8c6e715da2efe4718b26319d073ad8cfd15c05d073fb8a6cd572226f16da`. `hoobird-arm64-v8a-debug-testserver.apk` bleibt ebenfalls liegen, SHA-256 `a08b39779b488157f9cdbb0468c9e11d673a56280f142e66f6139ef654fc9812`. Die älteren Loopback-APKs bleiben die Dateien ohne `testserver` im Namen. Die sprechen weiter `127.0.0.1` an und erreichen das Telefon im WLAN nicht.

Diese Testserver-APK ist zur Bauzeit festgelegt auf:

- Homeserver `https://hoobird.0xneoncode.de`
- Policy `https://hoobird.0xneoncode.de/policy`

Die Zuordnung der Pfade steht in `docs/test-server.md`. Klartext zu diesem Namen ist aus. Das Telefon braucht normales WLAN oder Mobilfunk und ein Zertifikat, dem Android vertraut. `adb reverse` ist für diese Fassung nicht nötig. Ein früherer Debug-Stand derselben App (`dev.hoobird.spike.hoobird`) kann eine gespeicherte Loopback-Sitzung haben. Diese Fassung verwirft eine gespeicherte Adresse, die nicht die Bauzeit-Adresse ist, und legt die lokale Datenbank dafür weg. Sie ruft den alten Server dabei nicht an. Trotzdem die alte App vorher deinstallieren, damit keine alte Sitzung im Weg steht.

Konten stehen nicht in dieser Datei und nicht in der APK. Sie werden getrennt ausgehändigt. Keine Passwörter hier eintragen.

## Installieren

1. Eine schon installierte HooBird-Debug-App deinstallieren.
2. Unbekannte Quellen für die gewählte Datei-App erlauben, `hoobird-arm64-v8a-debug-testserver-4.apk` öffnen und installieren.
3. Startbild, Anmeldung mit dem getrennt erhaltenen Konto. Unter „Server anzeigen“ müssen die beiden HTTPS-Adressen oben stehen. Sie nicht auf `http://` oder `127.0.0.1` ändern.

## Wenn die Anmeldung den Server erreicht

Synthetische Konten, keine echten Personen. Die Konten kommen von außen, nicht aus diesem Dokument.

- Zwei Erwachsenenkonten anlegen oder vorhandene Testkonten nutzen. Direktchat öffnen. Die Zeile muss „Verschlüsselt“ zeigen. „Identität nicht verifiziert“ ist erwartbar. Es gibt keinen QR- oder Bluetooth-Abgleich der Geräte.
- Text senden. Beim Gegenüber muss er ankommen. Bei dir steht neben der Uhrzeit ein grauer Haken, Beschriftung „Gesendet“. Die Zeile „Synchronisiert“ gibt es nicht mehr. Zwei Haken gibt es nicht: Matrix sagt nicht, dass das andere Gerät die Nachricht hat. Sind Lesebestätigungen an und alle anderen Mitglieder haben gelesen, stehen statt des Hakens zwei kleine lavendelfarbene Augen. Aus ist die Voreinstellung: dann siehst du den Lesestand nicht und sendest keine öffentliche Quittung. Ein Fehler ist rot und lässt sich mit „Erneut senden“ wiederholen. In einer Gruppe kommt die Eule nur, wenn alle beigetretenen anderen Mitglieder gelesen haben. Lang drücken, dann „Info“, zeigt wer gelesen hat.
- Bild aus der Galerie oder mit der neuen Kamerataste, mit kurzer Bildunterschrift. Das Bild soll in der Blase erscheinen. Tippen öffnet es groß. Ziehen, Zwei-Finger-Zoom und Doppeltipp sollen gehen. Speichern und Teilen bleiben aus, solange „Inhalt auf dem Sperrbildschirm verbergen“ an ist.
- Sprachnachricht und Lesebestätigungen stehen unten als eigene Schritte für morgen Abend.
- Antwort auf eine ältere Nachricht. Das Zitat soll den Text zeigen, nicht eine Matrix-Nutzerkennung. So viele Zeilen senden, dass die ursprüngliche Nachricht aus dem Bild läuft, dann das Zitat antippen. Die ursprüngliche Nachricht soll ins Bild rutschen.
- Reaktion, Bearbeiten, Löschen. Löschen sagt, dass eine schon gesehene Kopie bleibt.
- Chatliste: Namen suchen, anheften, archivieren, aus dem Archiv holen, stummschalten, Ton wieder an. Ein leeres Archiv darf nicht als deaktiviertes „Archiv ausblenden“ stehen bleiben.
- Nachricht lang antippen, „Auswählen“, eine zweite Textnachricht dazu, weiterleiten. Im Zielraum steht „Weitergeleitet:“ und der Text, ohne die Matrix-Antwortzeile. Bild und Ton werden nicht weitergeleitet.
- Gruppe aus zwei Kontakten anlegen, umbenennen, ein Mitglied einladen, Verwaltung geben und entziehen, Mitglied entfernen, erwähnen, selbst verlassen. Ein neu eingeladenes Mitglied sieht die Nachrichten von vor seinem Beitritt nicht.
- Kinderkonto nur, wenn ein Elternkonto es angelegt hat. Eine Gruppe mit dem Kind darf nur entstehen, wenn jeder andere Teilnehmer freigegeben ist. Ein nicht freigegebener Teilnehmer muss scheitern, auch wenn ein anderer Client die Einladung schickt.
- Eltern: Verknüpfungscode zeigen. Es erscheint ein QR und derselbe Text zum Abtippen. Die App scannt den QR in dieser Fassung noch nicht. Das zweite Elternkonto tippt den Text ein. Der Code beweist keine Sorgeberechtigung. Freigeben, Sperren, die Sperre vom anderen Elternteil nicht aufheben können, Gerätefreigabe mit der angezeigten ed25519-Zeile. In dieser Ansicht stehen keine Nachrichten und keine Schlüssel.
- Nachricht auswählen, „Melden“. Nichts ist angehakt. Nur angehakte Texte sollen mitgehen. Ein Elternkonto sieht diese Meldung nicht.
- Blockieren. Danach soll eine neue gemeinsame Unterhaltung vom Server abgelehnt werden.
- Einstellung „Inhalt auf dem Sperrbildschirm verbergen“ ist an. Eine Push-Zustellung gibt es in dieser Fassung nicht. Es erscheint deshalb keine Vorschau, weder mit noch ohne Text.

## Morgen Abend: Sprache

Die Aufnahme gilt als gesendet, wenn die Datei mindestens etwa eine Sekunde lang und mindestens 1 KB groß ist und der dekodierte Pegel nicht bei null liegt. Der Pegel in der Leiste entscheidet das nicht mehr. HyperOS hat `getMaxAmplitude` oft bei 0 gelassen, die Datei aber trotzdem geschrieben; die alte Fassung hat sie deshalb verworfen.

1. Direktchat öffnen. Mikrofon beim ersten Mal erlauben. Eine schon erteilte Berechtigung muss reichen, auch wenn AppOps `foreground` meldet.
2. Taste gedrückt halten, einen kurzen Satz sprechen, loslassen. Währenddessen: roter Punkt, die Zeit zählt, die Wellenform bewegt sich. Danach eine abspielbare Blase. Nichts davon darf mit „Mikrofon blockiert“ enden.
3. Nochmal halten, nach oben schieben, loslassen. Die Aufnahme bleibt, Schloss ist zu. „Senden“ schickt sie. Der Papierkorb verwirft sie, dann kommt keine Blase.
4. Nochmal halten, nach links wischen. Text „Wischen zum Abbrechen“. Es wird nichts gesendet.
5. Ganz kurz antippen, unter einer Sekunde. Hinweis „Zu kurz“. Nichts wird gesendet.
6. Optional am Rechner, während eine Aufnahme läuft: `adb logcat -s HooBirdVoice`. Erwartet: `onListen sink=true`, `start ok source=MIC sink=true` (oder `VOICE_RECOGNITION` / `VOICE_COMMUNICATION`, wenn MIC nicht startet), fünf Zeilen `tick` mit `sink=true`, `stop ok` mit `bytes` deutlich über 1024 und `rms` über 0.01, danach `ui take reason=accept`. Ein zweites `stop` in derselben Aufnahme darf nur `stop ignored` sein, nicht `invalid state`.

## Morgen Abend: Lesebestätigungen mit dem Bot

Der Gegenpart ist ein matrix-bot-sdk-Bot. Die Eule zählt nur eine öffentliche Quittung vom Typ `m.read`. Der Bot muss genau diese senden:

`POST /_matrix/client/v3/rooms/{roomId}/receipt/m.read/{eventId}` mit Körper `{}`.

`m.read.private` zählt nicht. Die sieht der andere Teilnehmer nicht, und die App wertet sie nicht als Gelesen. Die App selbst sendet bei ausgeschalteten Lesebestätigungen keine `m.read`, aber weiterhin `m.read.private` und die private Lesemarke für die eigenen Geräte. Bei eingeschalteten Lesebestätigungen sendet sie zusätzlich `m.read`.

1. Einstellung „Lesebestätigungen“ ist aus. Eine Nachricht senden. Der Bot soll sie mit `m.read` quittieren. Bei dir bleibt ein grauer Haken, Beschriftung „Gesendet“. Keine Eule. In den Sync-Anfragen des Bots darf von diesem Konto keine `m.read` stehen.
2. „Lesebestätigungen“ einschalten. Den Chat öffnen, damit die sichtbare Nachricht gelesen wird. Der Bot soll jetzt eine `m.read` von diesem Konto sehen, nicht nur `m.read.private`.
3. Eine neue Nachricht senden. Sobald der Bot `m.read` auf diese Nachricht oder eine neuere Nachricht im geladenen Verlauf setzt, wird aus dem Haken die Eule: zwei kleine lavendelfarbene Augen, einmal kurz beim Wechsel. Beschriftung „Gelesen“.
4. Gruppe mit dem Bot und einem weiteren Konto. Die Eule kommt erst, wenn beide anderen beigetretenen Mitglieder eine solche `m.read` haben. Hat nur der Bot gelesen, bleibt der Haken. Nachricht lang drücken, „Info“: der Bot steht bei „Gelesen“, das andere Konto bei „Noch nicht“. Sind Lesebestätigungen aus, steht dort nur, dass sie aus sind, und keine Namen.
5. Senden ohne Netz erzeugt den roten Punkt, Beschriftung „Senden fehlgeschlagen“. Antippen zeigt „Erneut senden“ und schickt die Nachricht noch einmal, sobald das Netz da ist.

## Bekannte Lücken

- Kein Emulator und kein lokales Synapse in diesem Lauf. Die Wellenform ist mit einem nachgebauten Rekorder geprüft, der Pegelereignisse schickt. Die Stille entscheidet ein RMS über PCM; ein eingespeister 440-Hz-Ton liegt im JVM-Test über der Schwelle. Ein gesprochenes Beispiel auf dem Telefon und ein verschlüsselter Upload an Synapse sind damit nicht belegt.
- Keine Kamera zum Scannen des Eltern-QR. Zeigen und Abtippen sind da. Ein Foto im Chat geht über die Kamerataste, das ist nicht der QR.
- Keine Push-Zustellung. Der Schalter merkt sich nur die Sperrbildschirm-Sichtbarkeit des Android-Kanals. Ohne Bezahldienst bleiben zwei Wege: UnifiedPush mit einem Verteiler wie ntfy (kein Google-Konto, der Nutzer wählt den Verteiler) oder FCM (kein Entgelt für das übliche Kontingent, aber ein Google-Projekt und `google-services`). Beides ist nicht eingebaut.
- Kein SAS, kein Identitäts-QR, kein Bluetooth.
- Keine Umfragen, keine allgemeinen Dateien, keine verschwindenden Nachrichten, keine Anrufe.
- Der Homeserver-Admin kann weiter ein Login-Token ausstellen. Öffentliche Geräteschlüssel bleiben über Matrix lesbar.
- Kein Audit, kein Store, keine Produktionssignatur.

## Ergebnis zurückmelden

Bitte pro Punkt kurz: gegangen, nicht gegangen, oder nicht geprüft, plus was auf dem Bildschirm stand. Keine Passwörter, keine Sicherungsschlüssel, keine Zugangsdaten und keine Serveradressen aus dem privaten Betrieb in den Bericht schreiben. Ein Screenshot ohne diese Werte reicht.
