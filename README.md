# HooBird

**Experimenteller Prototyp. Nicht für echte Personen. Nicht Android-bereit. Nicht sicherheitsgeprüft.**

HooBird ist ein Arbeitstitel für einen Familien-Messenger auf Matrix. Der Name ist keine geprüfte und keine eingetragene Marke. Das Veröffentlichen dieses Quelltexts räumt keine Rechte an Namen, Eule oder Anwendungszeichen ein. Eine andere Person darf den Code unter der AGPL benutzen und muss dafür einen eigenen Namen wählen, wenn sie ihn anbietet.

Der Prototyp zeigt drei Dinge auf einem wegwerfbaren Stack, der nur an `127.0.0.1` bindet:

1. Verschlüsselte Matrix-Nachrichten, Medien und eine Schlüsselkopie mit dem Dart-SDK von Famedly.
2. Eine Kinderrichtlinie, die Synapse auch für einen generischen Client erzwingt, mit den unten genannten Lücken.
3. Einen lokalen Aufbau mit Tests.

Er ist kein Produkt, keine Beta und keine Einladung, Kinder oder andere Personen darauf zu setzen.

## Kinderrichtlinie, die nicht trägt

Diese Lücken sind Teil des Prototyps. Sie stehen auch in `SECURITY.md`.

- Ein generischer Matrix-Client spricht Synapse direkt an. Die App erzwingt die Richtlinie nicht.
- Die Gerätebindung eines Kinderkontos prüft eine `device_id`-Zeichenkette, keinen Schlüssel-Fingerabdruck.
- Für `/keys/upload` und die Cross-Signing-Uploads gibt es keinen Modul-Callback. Der Widerruf löscht das Gerät.
- Gruppen-Wettlauf: Sperre und Einladung sind keine gemeinsame Transaktion. Die Mitgliedschaft kann kurz falsch bleiben. Inhalt danach soll fehlschlagen. Ein automatischer Rauswurf ist nicht gebaut.
- Späteres Mitglied: ein danach freigegebenes Mitglied wird eingeladen und sieht frühere Ereignisse nicht. Ein unerlaubtes späteres Mitglied wird abgelehnt.
- Die Medienprüfung sieht den Dateianfang. Die Megolm-Form ist keine kryptografische Prüfung.

## Lizenz

Eigener Code: AGPL-3.0-or-later. Der Lizenztext ist `LICENSE`. Die weitergebbare Flutter-App, die diesen Code mit `flutter_vodozemac` 0.9.0 verbindet, bleibt an AGPL Version 3 gebunden, weil das Binding keine gelesene Erlaubnis für eine spätere Version enthält. Die „or-later“-Erlaubnis gilt für den eigenen Text und für `matrix` 16.0.1. Sie relicensed das Binding nicht. Der Server aus eigenem Modul und der AGPL-Seite von Synapse kann unter AGPL-3.0 oder einer späteren Version weitergegeben werden. Das ist die Lesart der gelesenen Hinweise, keine Anwaltsmeinung. Einzelheiten stehen in `COPYRIGHT.md` und `THIRD_PARTY_NOTICES.md`.

Synapse 1.163.0 ist im Image `AGPL-3.0-or-later OR LicenseRef-Element-Commercial`. Dieser Entwurf nutzt die AGPL-Seite. Eine kommerzielle Element-Lizenz liegt nicht vor. Element X ist nicht eingebaut. `matrix-rust-sdk` ist nicht eingebunden.

Wer den Policy-Dienst oder Synapse mit diesem Modul anderen Personen über ein Netz anbietet, hat zusätzlich die Quelltextpflicht aus Abschnitt 13 der AGPL. Dieser Prototyp bietet dafür keinen Link in der Oberfläche an, weil er nicht für einen solchen Betrieb gedacht ist.

## Lokal starten

Voraussetzungen der Prüfungsmaschine: Docker mit Compose, Python 3.12, Flutter 3.47.9. Ports bleiben auf dem Loopback. Das ist nicht der VServer.

```bash
python3 -m venv .venv
.venv/bin/pip install -r policy/requirements.txt pytest httpx 'matrix-nio[e2e]==0.26.0' Pillow piexif psycopg2-binary
python3 scripts/init_local_env.py
./scripts/up.sh
.venv/bin/pytest -q
.venv/bin/python scripts/seed_demo.py
```

Synapse antwortet auf `http://127.0.0.1:18008`, die Policy-API auf `http://127.0.0.1:18018`.

`synapse/homeserver.yaml` wird von `scripts/render_local_config.py` nur erzeugt, wenn sie fehlt. Eine vorhandene Datei bleibt unangetastet. `runtime/localhost.env` und die ausgefüllte Homeserver-Datei enthalten die lokalen Geheimnisse und gehören nicht ins Git.

`scripts/init_local_env.py` erzeugt zufällige Werte nur in `runtime/localhost.env`, wenn die Datei fehlt. `config/localhost.env.example` enthält Platzhalter und authentifiziert nirgends. `synapse/initdb/01-databases.sh` legt die Datenbankrollen nur an, wenn das Volumen leer ist, und liest die Passwörter aus dieser Umgebung. Sie gelten für `127.0.0.1:15432` dieses Stacks.

Die Linux-App:

```bash
cd app
flutter pub get
flutter test test/widget_test.dart
flutter build linux
set -a && source ../runtime/localhost.env && set +a
flutter test test/recovery_live_test.dart
./build/linux/x64/release/bundle/hoobird
```

Ein Android-APK wurde nicht erzeugt. Auf der Prüfungsmaschine ist kein Android-SDK installiert.

`scripts/seed_demo.py` legt erfundene Konten nur in der lokalen Datenbank an. Die Passwörter erzeugt das Skript oder liest sie aus der gitignored Datei `runtime/demo-accounts.json`. Sie stehen nicht im Quelltext.

## Lesen

- [SECURITY.md](SECURITY.md) — bekannte Lücken, kein eingeschalteter Meldeweg
- [CONTRIBUTING.md](CONTRIBUTING.md) — Tests und Lizenz der Beiträge
- [COPYRIGHT.md](COPYRIGHT.md) — eigener Code, kein erfundener Rechtsname
- [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) — Inventar
- [docs/confirmed-product-spec.md](docs/confirmed-product-spec.md) — entschieden, angenommen, offen
- [docs/feasibility.md](docs/feasibility.md) — SDKs, Tests, Grenzen
- [docs/local-handoff.md](docs/local-handoff.md) — Versionen und Befehle
- [docs/bericht.md](docs/bericht.md) — was beim Meilenstein wirklich lief
- [docs/veroeffentlichungsvorbereitung.md](docs/veroeffentlichungsvorbereitung.md) — Stand der Open-Source-Vorbereitung

## Veröffentlichung

Dieses öffentliche Repository ist der bereinigte Quellbaum auf https://github.com/0xNeonCode/HooBird. Die private Historie des Entwurfs ist nicht enthalten. Sie wurde nicht geholt, nicht gespiegelt, nicht zusammengeführt und nicht veröffentlicht. Die lokalen Fixture-Werte des ersten Meilensteins stehen in diesem Repository nicht. Die private Historie wurde nicht umgeschrieben.

Der Stand bleibt ein experimenteller Prototyp. Er ist nicht für echte Personen, nicht Android-bereit und nicht sicherheitsgeprüft. Frühere Prüfläufe stehen in `docs/veroeffentlichungsvorbereitung.md` und `docs/evidence/`. Dieser Commit wiederholt sie nicht.
