# Vorbereitung zur Veröffentlichung

Stand: 8. November 2026. Der Zielort ist nicht gewählt. Es wurde nichts veröffentlicht, nichts gepusht, keine Forge-Einstellung geändert und kein Pull Request eröffnet. Die Historie wurde nicht umgeschrieben.

Nachtrag der Veröffentlichung: der öffentliche Ort ist https://github.com/0xNeonCode/HooBird. Veröffentlicht wurde nur dieser bereinigte Baum. Die private Historie blieb auf dem privaten Entwurf, wurde nicht umgeschrieben und ist in diesem Repository nicht enthalten. „Private vulnerability reporting“ ist nicht eingeschaltet; `SECURITY.md` nennt deshalb keine Melde-URL. Die Sätze darunter beschreiben den Stand der Vorbereitung davor.

**Prototyp. Nicht für echte Personen. Nicht Android-bereit. Nicht sicherheitsgeprüft.**

Die bekannten Lücken bleiben: ein generischer Client spricht Synapse direkt an; die Gerätefreigabe ist eine `device_id` und kein Schlüssel-Fingerabdruck; für die Key-Uploads gibt es keinen Modul-Callback; Sperre und Einladung sind keine gemeinsame Transaktion.

## Lizenzentscheidung

Eigener Code steht auf AGPL-3.0-or-later. Der Wortlaut ist der unveränderte GNU-Text in `LICENSE`, übernommen aus dem Lizenztext, der `matrix` 16.0.1 beiliegt. Die Begründung steht in `COPYRIGHT.md`. Ein Personen- oder Firmenname als Rechtsinhaber ist in den Commits nicht vorhanden und wurde nicht erfunden. Die Git-Autoren lauten `Cursor Agent <cursoragent@cursor.com>` und `Cursor <noreply@cursor.com>`. Das sind keine Meldestellen.

`matrix` 16.0.1 nennt in der Paketdatei `AGPL-3.0-or-later` und `SPDX-FileCopyrightText: 2019-Present Famedly GmbH`. `flutter_vodozemac` 0.9.0 enthält den AGPL-3.0-Text und keine gefundene „or-later“-Zeile. Die Rust-Crate `vodozemac` 0.10.0 hat in der lokal entpackten `Cargo.toml` `license = "Apache-2.0"`. Synapse 1.163.0 trägt im Image `AGPL-3.0-or-later OR LicenseRef-Element-Commercial`. Genutzt wird die AGPL-Seite. Eine Element-Commercial-Lizenz liegt nicht vor.

Element-X-Quelltext wurde nicht gefunden. `git log -S` nach `element-x` und `Element X` ist leer. Im Baum nennt nur `docs/feasibility.md` das nicht benutzte `matrix-rust-sdk`.

## Inventar

`python3 scripts/license_inventory.py` hat `THIRD_PARTY_NOTICES.md` geschrieben.

| Quelle | Gelesen | UNKNOWN |
| --- | --- | --- |
| Dart aus `app/pubspec.lock` plus pub-cache | 93 Einträge, davon die SDK-Zeilen | 0 |
| Rust aus der Cargo.lock von flutter_vodozemac 0.9.0 | 208 Crates | 68, meist weil die Crate auf dieser Linux-Maschine nicht entpackt war; `allo-isolate` hat nur `license-file` |
| Python `.venv` | 40 Distributionen | 0 nach Lesen der beigelegten LICENSE, wo das Metadatenfeld leer war |
| Policy-Image | 16 Distributionen | 0 |
| Synapse-Image v1.163.0 | 93 Distributionen | `signedjson` 1.1.4 ohne License-Feld |

`postgres:16-alpine` hatte im Image keine gefundene Lizenzdatei. Der Upstream-Text auf `REL_16_STABLE` wurde gelesen und ist im Inventar zitiert. Das Image wurde nicht Byte für Byte auf diesen Stand geprüft. Die PSF-Lizenz von `python:3.12-slim` wurde nicht aus dem Image gezogen.

## Geheimnisse

Regex über die erreichbare Historie und den aktuellen Baum, ohne Trefferwerte auszugeben. Kein gitleaks und kein trufflehog. Bilddateien wurden für Start und Einstellungen angesehen.

In Commit `f1d5e0d` stehen lokale Fixture-Werte in `docker-compose.yml`, `synapse/homeserver.yaml`, `tests/conftest.py`, `scripts/seed_demo.py`, `app/test/recovery_live_test.dart` und `docs/local-handoff.md`. Kein Private-Key-Block und kein AWS-Zugriffsschlüssel in der Historie. Der Signierschlüssel liegt unter `runtime/synapse/` und ist gitignored. `runtime/localhost.env` ist gitignored.

Im vorbereiteten Baum stehen die alten Admin- und Synapse-Werte nicht mehr in verfolgten Dateien. `synapse/homeserver.yaml` bleibt auf dieser Maschine, ist gitignored und wird nicht überschrieben. Datenbank- und Admin-Werte für einen neuen Stack erzeugt `scripts/init_local_env.py` zufällig in die gitignored Datei. Die Beispiel-Datei enthält nur Platzhalter. Seed- und Recovery-Passwörter werden zur Laufzeit erzeugt oder aus der gitignored Demo-Datei gelesen.

Die fünf Screenshots bleiben im privaten Entwurf. Sie zeigen ein leeres Passwortfeld, einen lokalen Test-Nutzernamen, eine lokale Matrix-ID und eine Gerätekennung. Die konkreten Kennungen werden hier nicht wiederholt. Der öffentliche Export lässt die Bilddateien weg.

## Historie nicht umgeschrieben

Ein Entfernen der Fixture-Werte aus der Historie würde die Commits `445c4fc` („Initialize project“) und `f1d5e0d` („Add a bounded HooBird feasibility prototype.“) als Zweigspitze ersetzen. `f1d5e0d` ist der gesamte Prototyp einschliesslich der Nachweise. Beide Commits liegen bereits auf `origin/main` des privaten Entwurfs. Dafür wäre ein Force-Push nötig. Das ist nicht geschehen.

Wer die bisherige Historie auf eine öffentliche Forge schiebt, veröffentlicht die Fixture-Werte aus `f1d5e0d` mit. Sie öffnen keinen VServer und kein Produktionssystem. Sie öffnen einen Stack, der mit genau diesen Werten auf Loopback läuft. Trotzdem soll diese Historie nicht öffentlich werden, bevor dazu ausdrücklich ja gesagt wird.

## Tests in diesem Durchgang

- `pytest policy/tests tests/test_media_prep.py`: 13 bestanden
- `pytest`: 26 bestanden in 55,60 s, Stack auf `127.0.0.1` healthy
- `flutter test test/widget_test.dart`: 2 bestanden
- `flutter test test/recovery_live_test.dart`: bestanden, mit `ADMIN_PASSWORD` aus der gitignored Umgebung. Dieselben Sync-Warnungen wie im Meilenstein, kein Fehlschlag

`docs/evidence/` ist unverändert. Ein grüner Lauf ist keine Freigabe.

## Geänderte und neue Dateien

Neu: `LICENSE`, `COPYRIGHT.md`, `THIRD_PARTY_NOTICES.md`, `CONTRIBUTING.md`, `SECURITY.md`, `config/localhost.env.example`, `synapse/homeserver.example.yaml`, `scripts/license_inventory.py`, `scripts/render_local_config.py`, `tools/local_env.py`, diese Datei.

Angepasst: `README.md`, `app/README.md`, `.gitignore`, `docker-compose.yml`, `scripts/up.sh`, `scripts/seed_demo.py`, `synapse/initdb/01-databases.sql`, `tests/conftest.py`, `tests/test_disposable_restore.py`, `app/test/recovery_live_test.dart`, `docs/feasibility.md`, `docs/local-handoff.md`, SPDX-Zeilen in den eigenen Python- und Dart-Dateien.

Aus dem Index entfernt, auf der Platte belassen: `synapse/homeserver.yaml`.

## Blocker vor einer echten Veröffentlichung

- Zielort fehlt.
- Die vorhandene Historie enthält die Fixture-Werte. Veröffentlichung dieser Historie und ein destruktives Umschreiben sind zwei verschiedene Entscheide. Beides wartet.
- Kein benannter privater Meldeweg. `SECURITY.md` erfindet keine Adresse.
- Kein Rechtsname im Copyright. Vor einer Veröffentlichung ausserhalb dieses Entwurfs muss die veröffentlichende Person den Hinweis in `COPYRIGHT.md` durch ihren eigenen Namen ersetzen, wenn sie das will.
- Marke HooBird nicht geprüft. Quelltext gibt die Marke nicht mit.
- `flutter_vodozemac` ohne belegte „or-later“-Zeile. 68 Rust-Crates und `signedjson` bleiben UNKNOWN.
- AGPL Abschnitt 13 ist für einen Netzbetrieb nicht in der Oberfläche umgesetzt. Der Prototyp soll nicht so betrieben werden.
- Kein Android-SDK, kein APK, keine Sicherheitsprüfung.

## Export ohne alte Historie

Ein Archiv ohne `.git` und ohne die Screenshot-Dateien wird aus dem jeweiligen Stand gebaut und liegt neben dem Entwurf, nicht in der Git-Historie. Die Prüfsumme steht in der Begleitdatei des Archivs und im Bericht, nicht in diesem Text, damit der Quellstand nicht seine eigene Archivsumme enthalten muss. Die private Historie bleibt erhalten und wird nicht veröffentlicht.

## Nächste Schritte, nicht ausgeführt

1. Zielort wählen. GitHub kann AGPL-Projekte aufnehmen. Das ist keine Empfehlung, dort Konten echter Personen zu betreiben, und keine Entscheidung für GitHub.
2. Erst danach einen öffentlichen Ort anlegen. Die vorhandene Historie nicht dorthin schieben, solange die Fixture-Werte darin stehen und das Umschreiben nicht ausdrücklich freigegeben ist. Ein sauberer erster Commit des vorbereiteten Baums ist der sichere Weg. Den legt diese Vorbereitung nicht an.
3. Wenn der Ort steht: in den Forge-Einstellungen die private Sicherheitsmeldung einschalten und erst dann die konkrete Adresse oder URL in `SECURITY.md` eintragen.
4. Copyright-Zeile mit dem echten Namen ergänzen, wenn einer genannt werden soll.
5. Markenfrage getrennt vom Code entscheiden.
6. Android, Audit und die bekannten Richtlinienlücken bleiben offene Produktarbeit und sind hier nicht angefangen.
