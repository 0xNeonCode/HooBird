# Sicherheit

Dies ist ein experimenteller Prototyp. Er ist nicht für echte Personen freigegeben und nicht auditiert. Ein Debug-APK ist kein freigegebenes Android-Produkt. Ein bestandener Test ist keine Sicherheitsfreigabe.

## Bekannte Schwächen

Diese Punkte sind am Prototyp gemessen oder im Code sichtbar. Sie bleiben absichtlich sichtbar.

- Die Kinderrichtlinie muss der Server erzwingen. Ein generischer Matrix-Client umgeht die App und spricht Synapse direkt an. Die Tests prüfen diesen Weg. Die App ist nicht die Grenze.
- Eine Kinder-Gerätefreigabe speichert die ed25519-Kennung, die das Gerät vor der Anmeldung anzeigt. Die Anmeldung verlangt eine Zeile mit dieser Kennung. Der Synapse-Prozess umwickelt `upload_keys_for_user`, `upload_signing_keys_for_user` und `upload_signatures_for_device_keys`, weil Synapse 1.163 dafür keinen Modul-Callback hat. Die Servlets dieser Version rufen die Methoden auf demselben Handler-Objekt auf. Fehlt eine Umwicklung oder nennt der Servlet-Quelltext den Aufruf nicht mehr, werden Kinderanmeldungen abgelehnt. Ein Geräteschlüssel muss von der gespeicherten ed25519-Kennung signiert sein. Einmal-Schlüssel davor werden abgelehnt. Cross-Signing darf zuerst ohne Gerätesignatur hochgeladen werden, weil das Matrix-Dart-SDK so vorgeht. Eine Signatur darf ein Gerät erst bestätigen, wenn der Master-Schlüssel von einem freigegebenen Gerät signiert ist. Ein bereits gebundener Master-Schlüssel lässt sich nur mit einer neuen Signatur eines freigegebenen Geräts ersetzen. Ein Passwort-Reset ist diese Signatur nicht. MSC3814-Trockengeräte sind in diesem Homeserver aus. Steht das Flag an und die zusätzliche Umwicklung fehlt, werden Kinderanmeldungen abgelehnt. Das ist keine Prüfung, dass das Gerät physisch das der Eltern ist. Wer das Passwort und die private Hälfte genau dieses Schlüssels hat, kann die Sitzung benutzen. Öffentliche Geräteschlüssel bleiben über die Matrix-Abfrage lesbar. Private Schlüssel und das Schlüsselbackup eines Kindes gibt die Policy-API nicht an ein Elternkonto. Der Homeserver-Admin kann weiterhin ein Login-Token minten. Das ist Synapse, und die Policy-API reicht es nicht durch.
- Mitgliedschaft und Sperre sind keine gemeinsame Transaktion mit Synapse. Nach einer Sperre versucht der Dienst, den gesperrten Kontakt aus den Räumen zu entfernen, denen das Kind schon beigetreten ist, und wiederholt das. Einladung und Sperre können sich trotzdem kurz überholen. Inhalt wird abgelehnt, sobald die Sperre sichtbar ist. Der Dienst entfernt das Kind nicht aus dem Raum.
- Ein später freigegebenes Mitglied sieht die ältere Historie nicht. Ein späteres Mitglied ohne Freigabe wird abgelehnt.
- Die Medienprüfung liest den Anfang der Datei. Zufällige Bytes können durchgehen. Ein verschlüsselter Upload versteckt Metadaten vor dem Server. EXIF wird nur vor der Verschlüsselung auf der Client-Seite entfernt.
- `m.room.encrypted` wird auf die Megolm-Form geprüft, nicht darauf, dass eine Implementierung den Ciphertext korrekt erzeugt hat. Klartext-`m.reaction` wird abgelehnt. Die App verschlüsselt die Reaktion mit der bestehenden Megolm-Sitzung und legt das Emoji nicht in `m.relates_to` auf dem Draht ab. Der Server sieht, dass ein verschlüsseltes Ereignis kam, nicht welches Emoji es war.
- `check_event_allowed` ist in Synapse experimentell und wird trotzdem benutzt. Fehlt der Raumzustand, lässt das Modul Mitgliedschaftsereignisse zu und schreibt ein Protokoll.
- `user_may_join_room` gilt nicht für den Admin-Join und nicht für das Anlegen des Raums. `check_login_for_spam` läuft beim Login, nicht bei der Registrierung.
- Das Android-Manifest erlaubt für den lokalen Prototyp Klartext-HTTP. `bcrypt_rounds` ist 4.
- Das Debug-APK dieses Meilensteins ist testsigniert und nicht für eine Veröffentlichung. Ein Android-Emulator mit KVM ist in dieser Cloud-Umgebung gestartet. Ein physisches Gerät und ein externes Audit gibt es nicht.

## Meldung

Ein privater Meldeweg ist nicht eingeschaltet. Diese Datei enthält absichtlich keine E-Mail-Adresse und keine Melde-URL. Die Git-Autorenadressen sind keine Meldestelle.

Das Repository ist öffentlich. Die private Meldung über GitHub bleibt aus: die Veröffentlichung konnte „Private vulnerability reporting“ nicht einschalten, weil die verbundene Integration keine Administrationsberechtigung hat. Solange eine Person mit Administrationsrecht das nicht einschaltet, gibt es hier keinen Kanal.

Schwachstellen bitte nicht in ein öffentliches Issue, einen öffentlichen Pull Request oder eine öffentliche Diskussion schreiben. Dazu gehören Schritte zur Ausnutzung, Zugangsdaten und Daten echter Personen.

Es gibt keine Zusage, dass eine Meldung ankommt, dass jemand antwortet, in welcher Zeit das geschieht, oder dass ein Fehler behoben wird. Dieser Text verspricht keine Sicherheit des Prototyps.

Bis ein Kanal eingeschaltet ist, bleibt eine Meldung liegen. Das ist der aktuelle Stand, kein Verfahren.
