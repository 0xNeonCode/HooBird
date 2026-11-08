# Sicherheit

Dies ist ein experimenteller Prototyp. Er ist nicht für echte Personen freigegeben und nicht auditiert. Ein Debug-APK ist kein freigegebenes Android-Produkt. Ein bestandener Test ist keine Sicherheitsfreigabe.

## Bekannte Schwächen

Diese Punkte sind am Prototyp gemessen oder im Code sichtbar. Sie bleiben absichtlich sichtbar.

- Die Kinderrichtlinie muss der Server erzwingen. Ein generischer Matrix-Client umgeht die App und spricht Synapse direkt an. Die Tests prüfen diesen Weg. Die App ist nicht die Grenze.
- Eine Kinder-Gerätefreigabe speichert die ed25519-Kennung, die das Gerät vor der Anmeldung anzeigt. Die Anmeldung verlangt eine Zeile mit dieser Kennung. Der Synapse-Prozess umwickelt `upload_keys_for_user` und weist Geräteschlüssel zurück, deren Signatur nicht zu dieser Kennung passt. Fehlt die Umwicklung, werden Kinderanmeldungen abgelehnt. Das ist keine Prüfung, dass das Gerät physisch das der Eltern ist. Wer das Passwort und die private Hälfte genau dieses Schlüssels hat, kann die Sitzung benutzen. `binds_key_fingerprint` ist für gespeicherte Zeilen wahr. Cross-Signing und `/keys/signatures/upload` haben weiter keinen eigenen HooBird-Callback.
- Mitgliedschaft und Sperre sind keine gemeinsame Transaktion mit Synapse. Nach einer Sperre versucht der Dienst, den gesperrten Kontakt aus den Räumen zu entfernen, denen das Kind schon beigetreten ist, und wiederholt das. Einladung und Sperre können sich trotzdem kurz überholen. Inhalt wird abgelehnt, sobald die Sperre sichtbar ist. Der Dienst entfernt das Kind nicht aus dem Raum.
- Ein später freigegebenes Mitglied sieht die ältere Historie nicht. Ein späteres Mitglied ohne Freigabe wird abgelehnt.
- Die Medienprüfung liest den Anfang der Datei. Zufällige Bytes können durchgehen. Ein verschlüsselter Upload versteckt Metadaten vor dem Server. EXIF wird nur vor der Verschlüsselung auf der Client-Seite entfernt.
- `m.room.encrypted` wird auf die Megolm-Form geprüft, nicht darauf, dass eine Implementierung den Ciphertext korrekt erzeugt hat.
- `check_event_allowed` ist in Synapse experimentell und wird trotzdem benutzt. Fehlt der Raumzustand, lässt das Modul Mitgliedschaftsereignisse zu und schreibt ein Protokoll.
- `user_may_join_room` gilt nicht für den Admin-Join und nicht für das Anlegen des Raums. `check_login_for_spam` läuft beim Login, nicht bei der Registrierung.
- Das Android-Manifest erlaubt für den lokalen Prototyp Klartext-HTTP. `bcrypt_rounds` ist 4.
- Das Debug-APK dieses Meilensteins ist testsigniert und nicht für eine Veröffentlichung. In dieser Umgebung lief kein Emulator und kein physisches Gerät. Es gibt kein externes Audit.

## Meldung

Ein privater Meldeweg ist nicht eingeschaltet. Diese Datei enthält absichtlich keine E-Mail-Adresse und keine Melde-URL. Die Git-Autorenadressen sind keine Meldestelle.

Das Repository ist öffentlich. Die private Meldung über GitHub bleibt aus: die Veröffentlichung konnte „Private vulnerability reporting“ nicht einschalten, weil die verbundene Integration keine Administrationsberechtigung hat. Solange eine Person mit Administrationsrecht das nicht einschaltet, gibt es hier keinen Kanal.

Schwachstellen bitte nicht in ein öffentliches Issue, einen öffentlichen Pull Request oder eine öffentliche Diskussion schreiben. Dazu gehören Schritte zur Ausnutzung, Zugangsdaten und Daten echter Personen.

Es gibt keine Zusage, dass eine Meldung ankommt, dass jemand antwortet, in welcher Zeit das geschieht, oder dass ein Fehler behoben wird. Dieser Text verspricht keine Sicherheit des Prototyps.

Bis ein Kanal eingeschaltet ist, bleibt eine Meldung liegen. Das ist der aktuelle Stand, kein Verfahren.
