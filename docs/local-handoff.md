# Lokale Übergabe

Dies ist weiter der lokale Wegwerfstapel. Nichts davon wird auf den VServer kopiert, und es wird kein Konto für echte Personen angelegt. Der öffentliche Quellstand liegt unter https://github.com/0xNeonCode/HooBird und enthält die private Historie nicht. Die Open-Source-Vorbereitung beschreibt `docs/veroeffentlichungsvorbereitung.md`.

## Versionen in der Prüfungsmaschine

- Ubuntu 24.04.5, Kernel 6.12.113+
- Python 3.12.3
- Docker 29.1.3, Docker Compose 2.40.3
- PostgreSQL 16 (Image `postgres:16-alpine`)
- Synapse `matrixdotorg/synapse:v1.163.0`
- Flutter 3.47.9 stable, Dart 3.13.7, Engine-Revision 89c39edfdf
- Rustc 1.83.0, nur weil cargokit Vodozemac baut
- Clang 18.1.3, CMake 3.28.3, Ninja 1.11.1
- `matrix` 16.0.1, `flutter_vodozemac` 0.9.0, `matrix-nio` 0.26.0

Auf dieser Maschine suchte Clang die C++-Header von GCC 14. Installiert wurde `g++-14`. Zusätzlich zeigte der Linker erst nach einem `libstdc++.so`-Symlink auf die GCC-13-Bibliothek. Eine normale Flutter-Linux-Installation mit den Desktop-Paketen aus der Flutter-Dokumentation kann das anders vorfinden. Wenn `flutter build linux` an `type_traits` oder `-lstdc++` scheitert, ist das die Stelle.

## Stack

```bash
cd /pfad/zu/diesem/entwurf
python3 -m venv .venv
.venv/bin/pip install -r policy/requirements.txt pytest httpx 'matrix-nio[e2e]==0.26.0' Pillow piexif psycopg2-binary
./scripts/up.sh
curl -fsS http://127.0.0.1:18018/_hoobird/health
curl -fsS http://127.0.0.1:18008/health
```

`scripts/up.sh` startet bei Bedarf den Docker-Daemon und wartet auf die Policy-Gesundheit. Postgres lauscht auf `127.0.0.1:15432`, Synapse auf `127.0.0.1:18008`, die Policy-API auf `127.0.0.1:18018`. Auf der Prüfungsmaschine hat das Docker-Bridge-Netz TCP zwischen Containern verworfen. Compose nutzt deshalb das Host-Netz und bindet nur an Loopback. Das ist eine Eigenschaft dieser Maschine, kein gewünschtes Produktionsnetz.

Betreiberzugang, nur lokal und nur zum Anlegen der Testkonten:

- `python3 scripts/init_local_env.py` erzeugt `runtime/localhost.env`, wenn sie fehlt. `config/localhost.env.example` authentifiziert nicht.
- Nutzername `hoobird-admin`. Das Passwort steht nur in der gitignored Datei.
- `synapse/homeserver.yaml` entsteht daraus, wenn sie fehlt, und ist gitignored.
- Die alten Fixture-Werte des ersten Meilensteins stehen weiter in der privaten Git-Historie. Der öffentliche Quellstand übernimmt sie nicht.

`bcrypt_rounds` ist 4, damit Tests schnell sind. Das ist nicht für einen echten Server.

## Tests

```bash
.venv/bin/pytest -q
cd app
flutter test test/widget_test.dart
flutter build linux
flutter test test/recovery_live_test.dart
```

Der Recovery-Test legt eigene Kinderkonten an und setzt ein Passwort zurück. Er braucht den laufenden Stack. Er ist kein Widget-Test und schaltet die HTTP-Sperre von `flutter test` aus, sonst antwortet das Test-Binding auf jeden Request mit 400.

Beispielkonten, nachdem `python scripts/seed_demo.py` durchgelaufen ist. Die Passwörter stehen im Skript, weil das Skript sie in der lokalen Datenbank setzt. Sie sind erfunden und gelten nur dort. Die Liste der Konten ohne Wiederholung der Passwörter: oma und linus als Eltern, mara und fremder als Erwachsene, jonas als Kind. Gerätekennungen: OMADEMO01, LINUSDEMO1, MARADEMO01, FREMDDEMO1, JONASDEMO01. Die ausführliche Ausgabe schreibt das Skript nach `runtime/demo-accounts.json`.

Oma und Linus sind mit Jonas verknüpft. Mara ist für Jonas freigegeben. Fremder ist es nicht. Es gibt einen verschlüsselten Raum „Familie“ zwischen Oma und Mara. Die Linux-Sitzung von Mara auf einem neuen Gerät sieht die alten Ereignisse nicht im Klartext. Das ist das erwartete Bild, kein Fehler der Oberfläche.

Ohne `--dart-define` merkt sich die App Homeserver `http://127.0.0.1:18008` und Policy `http://127.0.0.1:18018`. Klartext-HTTP gilt nur für `127.0.0.1`, `localhost` und `::1`. Eine andere Adresse muss HTTPS sein. Die Pfade für `https://hoobird.0xneoncode.de` stehen in `docs/test-server.md`.

## Wiederherstellung der Wegwerfdaten

```bash
.venv/bin/pytest tests/test_disposable_restore.py -q
```

Der Test schreibt die Policy-Datenbank und `event_json` in eigene Restore-Datenbanken und löscht diese danach. Die laufende Datenbank bleibt. Der Synapse-Signierschlüssel liegt unter `runtime/synapse/hoobird.signing.key`. Wer den Stack mit Root-Docker startet, muss die Datei für den Test lesbar machen. Der Schlüssel ist kein persönlicher Sicherungsschlüssel.

## Physisches Android, noch nicht gelaufen

Nicht gelaufen, weil kein SDK, kein Emulator und kein Gerät vorhanden waren. Wenn ein Gerät da ist:

1. Android-SDK mit `compileSdk` 36 und ein NDK, das Flutter 3.47 verlangt. `flutter doctor -v` nennt die Version.
2. `cd app && flutter build apk --debug`. Der erste Build kompiliert Vodozemac. Dafür braucht die Maschine Rust. cargokit kann rustup nachziehen. Das dauert und ist hier nicht gemessen.
3. APK installieren. Ein Build ohne `--dart-define` spricht `127.0.0.1` an. Ein Build für den Testserver trägt die HTTPS-Adressen aus `docs/test-server.md`. Klartext zu einer anderen Adresse lehnt die App ab.
4. Als Mara anmelden. Der Raum Familie muss erscheinen. Alte Nachrichten dürfen auf diesem neuen Gerät nicht lesbar sein, solange kein Sicherungsschlüssel eingegeben wird. Die Zeile muss „Identität nicht verifiziert“ sagen, bis wirklich eine Matrix-Verifikation gelaufen ist.
5. Eine neue Textzeile senden. In `event_json` darf der Satz nicht stehen.
6. Als Jonas nur mit der Gerätekennung `JONASDEMO01` anmelden. Eine zweite, nicht freigegebene Kennung muss von der Policy mit 403 abgewiesen werden.
7. Als Elternteil Oma in den Einstellungen Mara für Jonas sperren. Ein generischer Client, nicht die App, darf danach keinen Raum mit Jonas und Mara mehr anlegen. Das deckt `tests/test_policy_enforcement.py` schon serverseitig ab. Auf dem Gerät nur nachsehen, ob die App die Ablehnung zeigt und nicht so tut, als wäre der Chat offen.
8. Kein QR scannen und kein Bluetooth erwarten. Beides ist nicht in diesem Build.

Ein grüner Instrumentierungslauf auf einem Gerät wäre immer noch kein Audit.
