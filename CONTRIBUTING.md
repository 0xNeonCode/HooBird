# Beitragen

HooBird ist ein experimenteller Prototyp und ein Arbeitstitel. Er ist nicht für echte Personen freigegeben. Beiträge verbessern diesen Entwurf. Sie machen ihn nicht zu einem geprüften Produkt.

## Lizenz der Beiträge

Eigener neuer Text wird unter AGPL-3.0-or-later angenommen, wie in `COPYRIGHT.md`. Eine Contributor-License-Vereinbarung mit einer Firma gibt es hier nicht, und es gibt keine Stelle, die eine solche Vereinbarung entgegennimmt. Wer etwas beisteuert, bestätigt damit, dass er oder sie das Recht hat, diesen Beitrag unter AGPL-3.0-or-later zu lizenzieren.

Drittcode bleibt unter seiner eigenen Lizenz. Hinweise Dritter nicht löschen. Keine eigene Kryptografie einbauen. Megolm, Olm und die Schlüsselkopie kommen aus `matrix` und Vodozemac.

## Was der Prototyp nicht ist

Kein Android-Release, keine Sicherheitsfreigabe, keine Marke. Die bekannten Lücken stehen in `SECURITY.md` und `docs/feasibility.md`. Ein Beitrag soll diese Lücken nicht in der Oberfläche verstecken.

## Lokal

```bash
python3 -m venv .venv
.venv/bin/pip install -r policy/requirements.txt pytest httpx 'matrix-nio[e2e]==0.26.0' Pillow piexif psycopg2-binary
python3 scripts/init_local_env.py
./scripts/up.sh
.venv/bin/pytest -q
```

`runtime/`, `synapse/homeserver.yaml` und der Signierschlüssel unter `runtime/synapse/` gehören nicht ins Git. `scripts/render_local_config.py` schreibt `synapse/homeserver.yaml` nur, wenn die Datei fehlt. Eine vorhandene Datei wird nicht überschrieben.

Die Flutter-Prüfung:

```bash
cd app
flutter pub get
flutter test test/widget_test.dart
flutter build linux
set -a && source ../runtime/localhost.env && set +a
flutter test test/recovery_live_test.dart
```

Der Recovery-Test spricht den lokalen Stack an. Die Passwörter, die er für frisch angelegte Kinderkonten vergibt, existieren erst durch den Testlauf auf diesem Stack.

`scripts/seed_demo.py` legt erfundene Konten nur in der lokalen Datenbank an. Die Ausgabe `runtime/demo-accounts.json` ist gitignored.

`python3 scripts/license_inventory.py` schreibt `THIRD_PARTY_NOTICES.md` aus dem lokalen pub-cache, dem Cargo-Register, `.venv` und, wenn der Daemon erreichbar ist, aus den Docker-Images. Fehlende Quellen bleiben UNKNOWN.

## Geheimnisse

Keine Produktionszugangsdaten, keine Daten echter Personen, keine Datenbankdumps und keine Signierschlüssel committen. Fixture-Konten des Seed-Skripts sind nur für den lokalen Stack gültig, nachdem das Skript sie dort angelegt hat.

Es gibt keinen Verhaltenskodex mit einer erfundenen Durchsetzungsstelle. Belästigung und das Einstellen fremder privater Daten haben in diesem Entwurf trotzdem nichts zu suchen. Ein öffentlicher Ort, an dem das durchgesetzt wird, ist noch nicht benannt.
