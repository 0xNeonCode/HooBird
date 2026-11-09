# Xiaomi-Check heute Abend

Kurze Liste für ein physisches Xiaomi (arm64). Das ist ein Debug-Stand, kein Store-Build und keine Sicherheitsfreigabe.

## Welche App, welcher Server

Die arm64-Debug-APK liegt bei den Übertragungsdateien dieses Laufs. Der Dateiname und der SHA-256 stehen in `docs/android-v1-milestone.md` unter dem vierten Lauf. Die APK ist debug-signiert. Es ist kein Produktionsschlüssel.

Die App spricht fest `127.0.0.1` auf dem Telefon an: Policy-Port `18018`, Homeserver-Port `18008`. Klartext-HTTP, nur für diesen Prototyp.

Im Emulator klappt das, weil `adb reverse` diese beiden Ports auf den Rechner legt, auf dem der lokale Teststack läuft. Der Stack hört nur auf dem Loopback dieses Rechners.

Ein Xiaomi im WLAN erreicht mit `127.0.0.1` nur sich selbst. Es erreicht den Testrechner nicht und den VServer nicht. In der APK steht keine Adresse des VServers und kein Zugang dazu.

Ohne eine extra Freigabe kann das Telefon die App installieren und öffnen. Die Anmeldung findet den Testserver nicht. Sprache, Bild, Reaktion und Gruppen lassen sich dann nicht gegen den Server prüfen.

Sicherste Option, die eine Freigabe braucht und den VServer nicht anfasst: das Telefon per USB an einen Rechner hängen, auf dem der lokale Teststack schon läuft, und dort nur

`adb reverse tcp:18008 tcp:18008`

`adb reverse tcp:18018 tcp:18018`

ausführen. Danach meint `127.0.0.1` auf dem Telefon den Stack auf diesem Rechner. Nichts davon wird hier ohne Freigabe eingerichtet. Der VServer bleibt unberührt.

## Installieren

1. Unbekannte Quellen für die gewählte Datei-App erlauben, die arm64-Debug-APK öffnen und installieren.
2. Die alte Installation derselben Debug-Kennung darf ersetzt werden. Das ist nicht die spätere Store-App.
3. Nach dem Öffnen: Startbild, Anmeldung. Ohne den USB-Tunnel endet die Anmeldung damit, dass der lokale Testserver nicht erreichbar ist. Das ist dann der erwartete Stand, kein Fehler der Anmeldedaten.

## Wenn der Tunnel freigegeben und aktiv ist

Synthetische Konten, keine echten Personen.

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
