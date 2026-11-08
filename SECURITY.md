# Sicherheit

Dies ist ein experimenteller Prototyp. Er ist nicht für echte Personen freigegeben, nicht auditiert und nicht Android-bereit. Ein bestandener Test ist keine Sicherheitsfreigabe.

## Bekannte Schwächen

Diese Punkte sind am Prototyp gemessen oder im Code sichtbar. Sie bleiben absichtlich sichtbar.

- Die Kinderrichtlinie muss der Server erzwingen. Ein generischer Matrix-Client umgeht die App und spricht Synapse direkt an. Die Tests prüfen diesen Weg. Die App ist nicht die Grenze.
- Die Gerätefreigabe vergleicht eine `device_id`-Zeichenkette. Sie bindet keinen Schlüssel-Fingerabdruck. Wer das Passwort eines Kinderkontos und eine schon freigegebene Kennung kennt, kann diese Sitzung benutzen. `binds_key_fingerprint` ist falsch.
- Synapse 1.163.0 bietet in diesem Modul keinen Callback für `/keys/upload`, `/keys/device_signing/upload` und `/keys/signatures/upload`. Der Widerruf löscht das Synapse-Gerät, dadurch stirbt das alte Token. Eine neue Anmeldung mit derselben freigegebenen Kennung ist wieder möglich.
- Mitgliedschaft und Ereignis sind keine gemeinsame Transaktion. Ein Gruppen-Wettlauf aus Sperre und Einladung kann die Mitgliedschaft kurz falsch setzen. Inhalt danach soll fehlschlagen. Der Prototyp wirft das Kind nicht automatisch aus dem Raum.
- Ein später freigegebenes Mitglied sieht die ältere Historie nicht. Ein späteres Mitglied ohne Freigabe wird abgelehnt. Die Gerätebindung bleibt die `device_id`, nicht ein Schlüssel.
- Die Medienprüfung liest den Anfang der Datei. Zufällige Bytes können durchgehen. Ein verschlüsselter Upload versteckt Metadaten vor dem Server. EXIF wird nur vor der Verschlüsselung auf der Client-Seite entfernt.
- `m.room.encrypted` wird auf die Megolm-Form geprüft, nicht darauf, dass eine Implementierung den Ciphertext korrekt erzeugt hat.
- `check_event_allowed` ist in Synapse experimentell und wird trotzdem benutzt. Fehlt der Raumzustand, lässt das Modul Mitgliedschaftsereignisse zu und schreibt ein Protokoll.
- `user_may_join_room` gilt nicht für den Admin-Join und nicht für das Anlegen des Raums. `check_login_for_spam` läuft beim Login, nicht bei der Registrierung.
- Das Android-Manifest erlaubt für den lokalen Prototyp Klartext-HTTP. `bcrypt_rounds` ist 4.
- Es gibt kein physisches Android, kein APK und kein externes Audit.

## Meldung

Ein privater Meldeweg ist nicht eingeschaltet. Diese Datei enthält absichtlich keine E-Mail-Adresse und keine Melde-URL. Die Git-Autorenadressen sind keine Meldestelle.

Das Repository ist öffentlich. Die private Meldung über GitHub bleibt aus: die Veröffentlichung konnte „Private vulnerability reporting“ nicht einschalten, weil die verbundene Integration keine Administrationsberechtigung hat. Solange eine Person mit Administrationsrecht das nicht einschaltet, gibt es hier keinen Kanal.

Schwachstellen bitte nicht in ein öffentliches Issue, einen öffentlichen Pull Request oder eine öffentliche Diskussion schreiben. Dazu gehören Schritte zur Ausnutzung, Zugangsdaten und Daten echter Personen.

Es gibt keine Zusage, dass eine Meldung ankommt, dass jemand antwortet, in welcher Zeit das geschieht, oder dass ein Fehler behoben wird. Dieser Text verspricht keine Sicherheit des Prototyps.

Bis ein Kanal eingeschaltet ist, bleibt eine Meldung liegen. Das ist der aktuelle Stand, kein Verfahren.
