# Bericht zum ersten Meilenstein

HooBird bleibt ein Arbeitstitel. Dieser Meilenstein ist ein privater Prototyp. Er ist nicht auf dem VServer, nicht öffentlich und nicht eine erste Produktversion.

## Was wirklich gelaufen ist

Ein lokaler Stack aus Synapse 1.163.0, PostgreSQL 16 und einer kleinen Policy-API läuft nur auf `127.0.0.1`. Die Registrierung ist aus. Die Föderation ist aus und der Test dagegen ist bestanden. Konten bekommen eine undurchsichtige Matrix-ID. Der Nutzername liegt in einem eigenen Verzeichnis und kann sich ändern, ohne die Matrix-ID zu ändern. Ein generischer Client kann sich nicht mit dem freundlichen Namen als Matrix-Localpart anmelden.

Die Kinderrichtlinie sitzt im Synapse-Modul und in gemeinsamen Python-Regeln. Ein generischer Client, der Synapse direkt aufruft, kann kein Kinderkonto in eine Direktnachricht oder Gruppe mit einer nicht freigegebenen Person bringen. Eine Sperre überlebt eine erneute Freigabe durch das andere Elternteil. Ein nicht freigegebenes Kindergerät bekommt kein Login. Nach dem Widerruf antwortet `/keys/upload` mit 401, weil das Synapse-Gerät gelöscht wurde. Ein Wettlauf kann die Mitgliedschaft noch anlegen. Der Inhalt danach wird abgelehnt. JPEG-ähnliche Uploads werden abgelehnt, zufällige Bytes nicht. Das ist eine Heuristik.

Matrix-nio hat eine echte Megolm-Gruppe mit Text, verschlüsseltem Bild und verschlüsselter WAV-Datei gegen diesen Server geschickt. Die Marker standen nicht in `event_json`. Ein neues Mitglied hat das alte Ereignis nicht in der Historie bekommen. Nio kann die Schlüsselkopie nicht wiederherstellen. Das ist im Test festgehalten und nicht nachgebaut worden.

Das Dart-SDK 16.0.1 mit `flutter_vodozemac` 0.9.0 hat auf Linux gegen denselben Server eine Krypto-Identität angelegt. Ohne lebendes Absendergerät las ein neues Gerät den alten Text nicht. Ein falscher Sicherungsschlüssel scheiterte. Der richtige stellte den Text wieder her. Der Passwort-Reset über die Policy-API gab den Schlüssel nicht zurück. Ein Login danach las ohne Schlüssel nichts und mit Schlüssel wieder den Text. Ein neues `initCryptoIdentity` machte den alten Schlüssel ungültig. Der neue Schlüssel las die alte Nachricht noch, weil das Gerät, das die Identität gedreht hat, die schon vorhandene Sitzung in die neue Kopie hochgeladen hat. Das ist das gemessene Verhalten, keine versprochene Löschung der Historie.

Die Linux-App ist gegen den Seed-Raum gelaufen. Sie zeigte „Familie“, die Zeile „Verschlüsselt · Identität nicht verifiziert“ und für die alten Ereignisse „Schlüssel auf diesem Gerät nicht vorhanden“. Eine von diesem Gerät gesendete Zeile erschien lokal im Klartext und stand nicht in `event_json`. Die Einstellungen zeigten die echte Matrix-ID, die Rolle und die Gerätekennung. Screenshots: `docs/screenshots/`.

`pytest`, der Widget-Test und der Recovery-Test waren grün. Die Befehle stehen in `docs/feasibility.md` und `docs/local-handoff.md`.

## Was Mock, Stub oder nicht gelaufen ist

- Kein Android-APK, kein Emulator, kein physisches Gerät. `flutter doctor` fand kein Android-SDK. Vodozemac ist nur für Linux kompiliert worden. Dass cargokit auf Android dasselbe Crate baut, ist die Dokumentation des Pakets, kein Lauf hier.
- QR, SAS, Bluetooth, Push, Antworten, Reaktionen, Suche, Anheften, Archiv, Stumm, Lesebestätigungen, Sprachbedienung und der Meldungsdialog sind nicht gebaut.
- Die App sendet in der Oberfläche Text. Bild und Sprache sind als verschlüsselte Fixtures im Python-Test gelaufen, nicht als Aufnahme in der App.
- Die To-Device-Weitergabe bei zwei gleichzeitig lebenden Geräten wurde einmal beobachtet und nicht als stabiler automatischer Test festgeschrieben.
- Es gibt keine Aussage über Last, Speicher oder eine echte Nutzerzahl.
- Niemand außer diesem Prototyp hat die Kryptografie geprüft.

## Blocker vor einer geschlossenen Beta

1. Kein Lauf auf echten Android-Geräten, also auch keine Aussage, ob das NDK-Build und die klare HTTP-Ausnahme im Manifest auf einem Telefon tragbar sind.
2. Die Gerätefreigabe bindet eine Zeichenkette, nicht den Geräteschlüssel. `/keys/upload` hat keinen Modul-Hook.
3. Richtlinie und Ereignis sind keine Transaktion. Der Wettlauf ist bekannt und nicht geschlossen.
4. Spätere Änderungen an einer Kindergruppe werfen das Kind nicht automatisch hinaus. Das Verhalten ist ein Vorschlag.
5. Wiederherstellung eines Elternkontos ist offen und im Prototyp nicht möglich.
6. AGPL von `matrix` und `flutter_vodozemac` ist für eine Veröffentlichung ungeklärt.
7. Kein QR/SAS, kein Push ohne Klartext, kein echter Mailversand, keine Meldung mit ausdrücklich geteiltem Nachweis.
8. Kein unabhängiger Sicherheitsreview.

## Nächster Schritt

Einen privaten Android-Debug-Build auf einem physischen Gerät gegen genau diesen lokalen Stack laufen lassen und die Checks in `docs/local-handoff.md` abhaken. Dabei nicht die Roadmap nachbauen und nicht deployen.

Wenn das NDK-Build oder das Dart-SDK auf dem Gerät scheitert, ist das das Ergebnis. Es sollte nicht durch eine selbst geschriebene Rust-Brücke oder eigene Kryptografie ersetzt werden.
