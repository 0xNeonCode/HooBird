# Xiaomi-Check heute Abend

Kurze Liste für ein physisches Xiaomi (arm64). Das ist ein Debug-Stand, kein Store-Build und keine Sicherheitsfreigabe.

## Welche App, welcher Server

Die Datei für das Xiaomi heißt `hoobird-arm64-v8a-debug-testserver.apk`. Sie ist debug-signiert. Es ist kein Produktionsschlüssel und keine Store-Fassung. SHA-256 `a08b39779b488157f9cdbb0468c9e11d673a56280f142e66f6139ef654fc9812`, 56152760 Bytes. Dieselbe Zeile steht in `docs/android-v1-milestone.md` unter dem fünften Lauf. Die älteren Loopback-APKs bleiben die Dateien ohne `testserver` im Namen. Die sprechen weiter `127.0.0.1` an und erreichen das Telefon im WLAN nicht.

Diese Testserver-APK ist zur Bauzeit festgelegt auf:

- Homeserver `https://hoobird.0xneoncode.de`
- Policy `https://hoobird.0xneoncode.de/policy`

Die Zuordnung der Pfade steht in `docs/test-server.md`. Klartext zu diesem Namen ist aus. Das Telefon braucht normales WLAN oder Mobilfunk und ein Zertifikat, dem Android vertraut. `adb reverse` ist für diese Fassung nicht nötig. Ein früherer Debug-Stand derselben App (`dev.hoobird.spike.hoobird`) kann eine gespeicherte Loopback-Sitzung haben. Diese Fassung verwirft eine gespeicherte Adresse, die nicht die Bauzeit-Adresse ist, und legt die lokale Datenbank dafür weg. Sie ruft den alten Server dabei nicht an. Trotzdem die alte App vorher deinstallieren, damit keine alte Sitzung im Weg steht.

Konten stehen nicht in dieser Datei und nicht in der APK. Sie werden getrennt ausgehändigt. Keine Passwörter hier eintragen.

## Installieren

1. Eine schon installierte HooBird-Debug-App deinstallieren.
2. Unbekannte Quellen für die gewählte Datei-App erlauben, `hoobird-arm64-v8a-debug-testserver.apk` öffnen und installieren.
3. Startbild, Anmeldung mit dem getrennt erhaltenen Konto. Unter „Server anzeigen“ müssen die beiden HTTPS-Adressen oben stehen. Sie nicht auf `http://` oder `127.0.0.1` ändern.

## Wenn die Anmeldung den Server erreicht

Synthetische Konten, keine echten Personen. Die Konten kommen von außen, nicht aus diesem Dokument.

- Zwei Erwachsenenkonten anlegen oder vorhandene Testkonten nutzen. Direktchat öffnen. Die Zeile muss „Verschlüsselt“ zeigen. „Identität nicht verifiziert“ ist erwartbar. Es gibt keinen QR- oder Bluetooth-Abgleich der Geräte.
- Text senden. Beim Gegenüber muss er ankommen und bei dir „Synchronisiert“ werden.
- Bild aus der Galerie, mit kurzer Bildunterschrift. Das Bild soll in der Blase erscheinen.
- Sprachnachricht: beim ersten Mal die Mikrofonfrage. Erlauben, aufnehmen, nach oben schieben oder „Sperren“, anhören, Tempo, senden. Die Blase soll abspielbar sein. Anders als im Emulator hat das Xiaomi ein echtes Mikrofon. Ein kurzes gesprochenes Wort ist der sinnvolle Test. Wird die Berechtigung verweigert, muss die Aufnahme stehen bleiben und nicht still ein leeres Medium senden.
- Antwort auf eine ältere Nachricht. Das Zitat soll den Text zeigen, nicht eine Matrix-Nutzerkennung. So viele Zeilen senden, dass die ursprüngliche Nachricht aus dem Bild läuft, dann das Zitat antippen. Die ursprüngliche Nachricht soll ins Bild rutschen.
- Reaktion, Bearbeiten, Löschen. Löschen sagt, dass eine schon gesehene Kopie bleibt.
- Chatliste: Namen suchen, anheften, archivieren, aus dem Archiv holen, stummschalten, Ton wieder an. Ein leeres Archiv darf nicht als deaktiviertes „Archiv ausblenden“ stehen bleiben.
- Nachricht lang antippen, „Auswählen“, eine zweite Textnachricht dazu, weiterleiten. Im Zielraum steht „Weitergeleitet:“ und der Text, ohne die Matrix-Antwortzeile. Bild und Ton werden nicht weitergeleitet.
- Gruppe aus zwei Kontakten anlegen, umbenennen, ein Mitglied einladen, Verwaltung geben und entziehen, Mitglied entfernen, erwähnen, selbst verlassen. Ein neu eingeladenes Mitglied sieht die Nachrichten von vor seinem Beitritt nicht.
- Kinderkonto nur, wenn ein Elternkonto es angelegt hat. Eine Gruppe mit dem Kind darf nur entstehen, wenn jeder andere Teilnehmer freigegeben ist. Ein nicht freigegebener Teilnehmer muss scheitern, auch wenn ein anderer Client die Einladung schickt.
- Eltern: Verknüpfungscode zeigen. Es erscheint ein QR und derselbe Text zum Abtippen. Die App öffnet dafür keine Kamera. Das zweite Elternkonto tippt den Text ein. Der Code beweist keine Sorgeberechtigung. Freigeben, Sperren, die Sperre vom anderen Elternteil nicht aufheben können, Gerätefreigabe mit der angezeigten ed25519-Zeile. In dieser Ansicht stehen keine Nachrichten und keine Schlüssel.
- Nachricht auswählen, „Melden“. Nichts ist angehakt. Nur angehakte Texte sollen mitgehen. Ein Elternkonto sieht diese Meldung nicht.
- Blockieren. Danach soll eine neue gemeinsame Unterhaltung vom Server abgelehnt werden.
- Einstellung „Inhalt auf dem Sperrbildschirm verbergen“ ist an. Eine Push-Zustellung gibt es in dieser Fassung nicht. Es erscheint deshalb keine Vorschau, weder mit noch ohne Text.

## Bekannte Lücken

- Kein gesprochenes Beispiel aus dem Emulator. Dort fehlte das Mikrofon, die Aufnahme war Stille.
- Keine Kamera zum Scannen des Eltern-QR. Zeigen und Abtippen sind da.
- Keine Push-Zustellung. Der Schalter merkt sich nur die Sperrbildschirm-Sichtbarkeit des Android-Kanals.
- Kein SAS, kein Identitäts-QR, kein Bluetooth.
- Keine Umfragen, keine allgemeinen Dateien, keine verschwindenden Nachrichten, keine Anrufe.
- Der Homeserver-Admin kann weiter ein Login-Token ausstellen. Öffentliche Geräteschlüssel bleiben über Matrix lesbar.
- Kein Audit, kein Store, keine Produktionssignatur.

## Ergebnis zurückmelden

Bitte pro Punkt kurz: gegangen, nicht gegangen, oder nicht geprüft, plus was auf dem Bildschirm stand. Keine Passwörter, keine Sicherungsschlüssel, keine Zugangsdaten und keine Serveradressen aus dem privaten Betrieb in den Bericht schreiben. Ein Screenshot ohne diese Werte reicht.
