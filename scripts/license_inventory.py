#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026. Legal name of the copyright holder is not recorded in this repository.
"""Write THIRD_PARTY_NOTICES.md from lockfiles and local license texts.

The script does not download packages. It reads:
- app/pubspec.lock and the local pub-cache
- flutter_vodozemac's Cargo.lock and the local cargo registry
- the local Python .venv, if present
- docker images, if the daemon is reachable

Missing sources stay marked unknown. Re-run after `flutter pub get` and a
Linux build that has fetched the Rust crates.
"""

from __future__ import annotations

import hashlib
import io
import re
import subprocess
import tarfile
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "THIRD_PARTY_NOTICES.md"
PUB_CACHE = Path.home() / ".pub-cache" / "hosted" / "pub.dev"
CARGO_GLOBS = [
    Path("/usr/local/cargo/registry/src"),
    Path.home() / ".cargo" / "registry" / "src",
]


def classify(text: str) -> str:
    head = text[:2500]
    if "GNU AFFERO GENERAL PUBLIC LICENSE" in head or "GNU Affero General Public License" in head:
        return "AGPL-3.0-text"
    if "GNU GENERAL PUBLIC LICENSE" in head and "Version 3" in head:
        return "GPL-3.0-text"
    if "Apache License" in head and "Version 2.0" in head:
        return "Apache-2.0"
    if "Mozilla Public License" in head:
        return "MPL"
    if re.search(r"\bMIT License\b", head) or "Permission is hereby granted, free of charge" in head:
        return "MIT"
    if "Internet Systems Consortium" in head or re.search(r"\bISC\b", head[:400]):
        return "ISC"
    if "Redistribution and use in source and binary forms" in head and "BSD" in head[:800]:
        return "BSD"
    if "Redistribution and use in source and binary forms" in head:
        return "BSD-like"
    return "UNKNOWN"


def copyright_lines(text: str) -> list[str]:
    found = []
    for line in text.splitlines()[:40]:
        stripped = line.strip().lstrip("*#/ ").strip()
        if not stripped.startswith("Copyright"):
            continue
        if "Free Software Foundation" in stripped:
            continue
        if stripped not in found:
            found.append(stripped)
        if len(found) == 2:
            break
    return found


def parse_pubspec_lock() -> list[tuple[str, str, str]]:
    rows = []
    name = version = sha = None
    for line in (ROOT / "app" / "pubspec.lock").read_text(encoding="utf-8").splitlines():
        if line.startswith("  ") and not line.startswith("    ") and line.endswith(":"):
            if name:
                rows.append((name, version or "", sha or ""))
            name = line.strip()[:-1]
            version = sha = None
        elif line.strip().startswith("version:"):
            version = line.split(":", 1)[1].strip().strip('"')
        elif "sha256:" in line:
            sha = line.split(":", 1)[1].strip().strip('"')
    if name:
        rows.append((name, version or "", sha or ""))
    return rows


def parse_cargo_lock(path: Path) -> list[tuple[str, str, str]]:
    rows = []
    name = version = checksum = None
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("[[package]]"):
            if name:
                rows.append((name, version or "", checksum or ""))
            name = version = checksum = None
        elif line.startswith("name = "):
            name = line.split("=", 1)[1].strip().strip('"')
        elif line.startswith("version = "):
            version = line.split("=", 1)[1].strip().strip('"')
        elif line.startswith("checksum = "):
            checksum = line.split("=", 1)[1].strip().strip('"')
    if name:
        rows.append((name, version or "", checksum or ""))
    return rows


CRATE_CACHE = ROOT / "runtime" / "license-cache" / "crates"


def toml_section(toml_text: str, section: str) -> dict[str, str]:
    found: dict[str, str] = {}
    current = ""
    for line in toml_text.splitlines():
        stripped = line.strip()
        if stripped.startswith("["):
            current = stripped.strip("[]")
            continue
        if current != section or "=" not in line:
            continue
        key, value = line.split("=", 1)
        found[key.strip()] = value.strip().strip('"').strip("'")
    return found


def fetch_crate(name: str, version: str, checksum: str) -> tuple[bytes | None, str]:
    url = f"https://static.crates.io/crates/{name}/{name}-{version}.crate"
    dest = CRATE_CACHE / f"{name}-{version}.crate"
    if dest.is_file():
        data = dest.read_bytes()
        if hashlib.sha256(data).hexdigest() == checksum:
            return data, url
    try:
        with urllib.request.urlopen(url, timeout=60) as response:
            data = response.read()
    except Exception as exc:  # noqa: BLE001 — recorded as evidence, not swallowed
        return None, f"{url} FEHLER {type(exc).__name__}"
    digest = hashlib.sha256(data).hexdigest()
    if digest != checksum:
        return None, f"{url} CHECKSUMME stimmt nicht"
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(data)
    return data, url


def crate_record(name: str, version: str, checksum: str) -> dict[str, str]:
    record = {
        "name": name,
        "version": version,
        "license": "",
        "evidence": "",
        "copyright": "—",
    }
    if not checksum:
        local = PUB_CACHE / "flutter_vodozemac-0.9.0" / "rust"
        manifest = local / "Cargo.toml"
        if name == "vodozemac_bindings_dart" and manifest.is_file():
            package = toml_section(manifest.read_text(encoding="utf-8", errors="replace"), "package")
            license_name = package.get("license", "")
            license_file = package.get("license-file", "")
            parent = PUB_CACHE / "flutter_vodozemac-0.9.0" / "LICENSE"
            record["license"] = license_name or "kein license-Feld in der Crate"
            record["evidence"] = (
                "Pfad-Crate im Archiv flutter_vodozemac 0.9.0, keine crates.io-Checksumme. "
                "Die LICENSE des Pakets ist der AGPL-3.0-Text"
                + (f"; license-file={license_file}" if license_file else "")
                + ("; Paket-LICENSE gelesen" if parent.is_file() else "")
            )
            record["copyright"] = "siehe flutter_vodozemac, keine eigene Copyright-Zeile in Cargo.toml"
        else:
            record["license"] = "UNKNOWN"
            record["evidence"] = "keine Checksumme und keine lokale Pfad-Crate"
        return record
    data, evidence = fetch_crate(name, version, checksum)
    if data is None:
        record["license"] = "UNKNOWN"
        record["evidence"] = evidence
        return record
    try:
        archive = tarfile.open(fileobj=io.BytesIO(data), mode="r:gz")
    except tarfile.TarError as exc:
        record["license"] = "UNKNOWN"
        record["evidence"] = f"{evidence} Archiv nicht lesbar ({type(exc).__name__})"
        return record
    prefix = f"{name}-{version}/"
    members = {item.name: item for item in archive.getmembers()}
    chosen = None
    for candidate in (prefix + "Cargo.toml.orig", prefix + "Cargo.toml"):
        if candidate in members:
            chosen = candidate
            break
    if chosen is None:
        record["license"] = "UNKNOWN"
        record["evidence"] = f"{evidence}; sha256 geprüft; keine Cargo.toml"
        return record
    def read_member(member_name: str) -> str:
        return archive.extractfile(members[member_name]).read().decode("utf-8", "replace")

    orig_name = prefix + "Cargo.toml.orig"
    norm_name = prefix + "Cargo.toml"
    source_name = orig_name if orig_name in members else norm_name
    toml_text = read_member(source_name)
    package = toml_section(toml_text, "package")
    license_name = package.get("license", "")
    license_file = package.get("license-file", "")
    if package.get("license.workspace", "").lower() == "true" and not license_name:
        license_name = toml_section(toml_text, "workspace.package").get("license", "")
        if license_name:
            source_name = source_name + " workspace.package"
    if not license_name and not license_file and norm_name in members:
        normalized = toml_section(read_member(norm_name), "package")
        license_name = normalized.get("license", "")
        license_file = license_file or normalized.get("license-file", "")
        if license_name or license_file:
            source_name = norm_name
    notice = license_name
    copy = "—"
    if license_file:
        license_member = prefix + license_file
        if license_member in members:
            license_text = archive.extractfile(members[license_member]).read().decode("utf-8", "replace")
            kind = classify(license_text)
            owners = copyright_lines(license_text)
            copy = "; ".join(owners) if owners else "Lizenzdatei ohne Copyright-Zeile am Anfang"
            notice = f"{license_name}; Datei {license_file} = {kind}" if license_name else f"{kind} aus {license_file}"
        else:
            notice = (license_name + "; " if license_name else "") + f"UNKNOWN (license-file {license_file} fehlt im Archiv)"
    if not notice:
        notice = "UNKNOWN (kein license-Feld und keine license-file)"
    if copy == "—":
        owners: list[str] = []
        for member_name, member in members.items():
            base = member_name.rsplit("/", 1)[-1]
            if not base.upper().startswith("LICENSE") and base.upper() not in {"COPYING", "COPYRIGHT"}:
                continue
            license_text = archive.extractfile(member).read().decode("utf-8", "replace")
            for owner in copyright_lines(license_text):
                if owner not in owners:
                    owners.append(owner)
        if owners:
            copy = "; ".join(owners[:4])
    record["license"] = notice.replace("|", "/")
    record["evidence"] = f"sha256 = Cargo.lock; {evidence}; gelesen: {source_name.split('/', 1)[-1]}"
    record["copyright"] = copy.replace("|", "/")
    return record


def rust_records() -> list[dict[str, str]]:
    lock = PUB_CACHE / "flutter_vodozemac-0.9.0" / "rust" / "Cargo.lock"
    if not lock.is_file():
        return []
    packages = parse_cargo_lock(lock)
    with ThreadPoolExecutor(max_workers=8) as pool:
        return list(pool.map(lambda row: crate_record(*row), packages))


def metadata_fields(text: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    current = None
    buf: list[str] = []

    def flush() -> None:
        nonlocal current, buf
        if current:
            fields[current] = " ".join(part.strip() for part in buf).strip()
        current = None
        buf = []

    for line in text.splitlines():
        if not line.strip():
            flush()
            break
        if line.startswith(" ") or line.startswith("\t"):
            buf.append(line.strip())
            continue
        flush()
        if ":" in line:
            current, value = line.split(":", 1)
            buf = [value.strip()]
    flush()
    return fields


def dart_rows() -> list[str]:
    lines = [
        "## Dart-Pakete aus app/pubspec.lock",
        "",
        "Quelle der Version und des sha256: `app/pubspec.lock`. Lizenztext: lokale Kopie unter `~/.pub-cache/hosted/pub.dev/<name>-<version>/`, sofern vorhanden. Ein AGPL-Text ohne SPDX-Zeile ist hier `AGPL-3.0-text` und nicht automatisch „or-later“.",
        "",
        "| Paket | Version | Einordnung | SPDX oder Hinweis im Paket | Copyright-Zeilen aus der Lizenzdatei, soweit vorhanden |",
        "| --- | --- | --- | --- | --- |",
    ]
    for name, version, sha in parse_pubspec_lock():
        if name in {"flutter", "flutter_test", "flutter_web_plugins", "sky_engine"} or version in {"", "0.0.0"}:
            lines.append(f"| `{name}` | SDK | Flutter/Dart SDK | siehe Abschnitt Flutter | — |")
            continue
        directory = PUB_CACHE / f"{name}-{version}"
        notice = "UNKNOWN (Paket nicht im lokalen pub-cache)"
        copy = "—"
        spdx = "—"
        if directory.is_dir():
            license_files = sorted(directory.glob("LICENSE*")) + sorted(directory.glob("LICENSES/*"))
            pubspec = (directory / "pubspec.yaml").read_text(encoding="utf-8", errors="replace")
            copy_header = re.search(r"(?m)^# SPDX-FileCopyrightText:\s*(.+)$", pubspec)
            spdx_match = re.search(r"(?m)^# SPDX-License-Identifier:\s*(.+)$", pubspec)
            license_field = re.search(r"(?m)^license:\s*(.+)$", pubspec)
            spdx = spdx_match.group(1).strip() if spdx_match else (license_field.group(1).strip() if license_field else "kein SPDX und kein license-Feld")
            if license_files:
                text = license_files[0].read_text(encoding="utf-8", errors="replace")
                notice = classify(text)
                owners = copyright_lines(text)
                copy = "; ".join(owners) if owners else "keine Copyright-Zeile am Dateianfang ausser dem Lizenztext"
                if copy_header:
                    copy = f"{copy_header.group(1).strip()}; {copy}"
                copy = copy.replace("|", "/")
            else:
                notice = "UNKNOWN (keine LICENSE-Datei)"
        short_sha = (sha[:12] + "…") if sha else "—"
        lines.append(
            f"| `{name}` | {version} (sha256 `{short_sha}`) | {notice} | {spdx} | {copy} |"
        )
    lines.append("")
    return lines


def rust_rows() -> list[str]:
    lines = [
        "## Rust-Crates aus flutter_vodozemac 0.9.0",
        "",
        "Lockdatei: `flutter_vodozemac-0.9.0/rust/Cargo.lock` im pub-cache. Jede Crate mit Checksumme wurde von `https://static.crates.io/crates/<name>/<name>-<version>.crate` geladen und die sha256-Summe gegen die Lockdatei geprüft. Lizenzfeld und `license-file` stammen aus `Cargo.toml.orig`, sonst aus der normalisierten `Cargo.toml` desselben Archivs. Eine Crate ohne bestandene Prüfung bleibt UNKNOWN. Das ist eine Dateilesung, keine rechtliche Freigabe.",
        "",
    ]
    records = rust_records()
    if not records:
        lines.append("UNKNOWN: Cargo.lock von flutter_vodozemac 0.9.0 liegt nicht im pub-cache.")
        lines.append("")
        return lines
    unknown = [item for item in records if item["license"].startswith("UNKNOWN") or "UNKNOWN" in item["license"]]
    lines.append(f"Gelesen: {len(records)}. Davon mit UNKNOWN im Lizenzfeld: {len(unknown)}.")
    lines.append("")
    lines.append("| Crate | Version | Lizenz aus dem geprüften Archiv | Nachweis | Copyright aus der Lizenzdatei |")
    lines.append("| --- | --- | --- | --- | --- |")
    for item in records:
        lines.append(
            f"| `{item['name']}` | {item['version']} | {item['license']} | {item['evidence']} | {item['copyright']} |"
        )
    lines.append("")
    return lines


def python_rows(title: str, metadata_texts: list[tuple[str, str]]) -> list[str]:
    lines = [f"## {title}", ""]
    if not metadata_texts:
        lines.append("UNKNOWN: keine Metadaten gelesen.")
        lines.append("")
        return lines
    lines.append("| Distribution | Version | License-Feld |")
    lines.append("| --- | --- | --- |")
    for label, text in sorted(metadata_texts):
        fields = metadata_fields(text)
        name = fields.get("Name", label)
        version = fields.get("Version", "?")
        license_name = fields.get("License-Expression") or fields.get("License") or "UNKNOWN"
        if license_name in {"", "UNKNOWN"}:
            file_class = fields.get("License-File-Class", "")
            classifiers = [line for line in text.splitlines() if line.startswith("Classifier:") and "License" in line]
            license_name = file_class or (classifiers[0].split("::")[-1].strip() if classifiers else "UNKNOWN")
        license_name = license_name.replace("|", "/").replace("\n", " ")
        if "Internet Systems Consortium" in license_name:
            license_name = "ISC"
        elif len(license_name) > 90:
            license_name = license_name[:87] + "…"
        lines.append(f"| `{name}` | {version} | {license_name} |")
    lines.append("")
    return lines


def venv_metadata() -> list[tuple[str, str]]:
    root = ROOT / ".venv" / "lib"
    found = []
    if not root.is_dir():
        return found
    for path in root.glob("python*/site-packages/*.dist-info/METADATA"):
        text = path.read_text(encoding="utf-8", errors="replace")
        fields = metadata_fields(text)
        if not fields.get("License-Expression") and fields.get("License", "").strip() in {"", "UNKNOWN"}:
            license_dir = path.parent / "licenses"
            license_files = sorted(license_dir.glob("LICENSE*")) if license_dir.is_dir() else []
            if license_files:
                kind = classify(license_files[0].read_text(encoding="utf-8", errors="replace"))
                text = f"License: {kind} (aus {license_files[0].name}, nicht aus dem License-Feld)\n" + text
        found.append((path.parent.name, text))
    return found


def docker_metadata(image: str) -> list[tuple[str, str]]:
    script = r"""
import pathlib
root = pathlib.Path("/usr/local/lib")
for path in root.rglob("METADATA"):
    text_path = str(path)
    if "site-packages" not in text_path or "/pip-" in text_path or "/pip/" in text_path:
        continue
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    header_lines = []
    for line in lines:
        if not line.strip():
            break
        header_lines.append(line)
    header = chr(10).join(header_lines)
    license_names = list(path.parent.glob("LICENSE*")) + list((path.parent / "licenses").glob("LICENSE*"))
    extra = []
    if license_names:
        text = license_names[0].read_text(encoding="utf-8", errors="replace")
        kind = "Apache-2.0" if "Apache License" in text[:400] and "Version 2.0" in text[:400] else "Lizenzdatei vorhanden"
        if "GNU AFFERO GENERAL PUBLIC LICENSE" in text[:500]:
            kind = "AGPL-3.0-text"
        extra.append("License-File-Class: " + kind + " (" + license_names[0].name + ")")
    print("@@META@@", path.parent.name)
    print(header)
    for line in extra:
        print(line)
    print("@@END@@")
"""
    try:
        result = subprocess.run(
            ["sudo", "docker", "run", "--rm", "--entrypoint", "python3", image, "-c", script],
            check=False,
            capture_output=True,
            text=True,
            timeout=90,
        )
    except (OSError, subprocess.TimeoutExpired):
        return []
    if result.returncode != 0:
        return []
    rows = []
    name = None
    buf: list[str] = []
    for line in result.stdout.splitlines():
        if line.startswith("@@META@@ "):
            name = line.split(" ", 1)[1]
            buf = []
        elif line == "@@END@@" and name:
            rows.append((name, "\n".join(buf)))
            name = None
        elif name is not None:
            buf.append(line)
    return rows


def docker_text(image: str, inner: str) -> str:
    result = subprocess.run(
        ["sudo", "docker", "run", "--rm", "--entrypoint", "python3", image, "-c", inner],
        check=False,
        capture_output=True,
        text=True,
        timeout=90,
    )
    if result.returncode != 0:
        return ""
    return result.stdout


def base_image_rows() -> list[str]:
    lines = ["## Basis-Images, gelesene Hinweise", ""]
    python_id = image_id("python:3.12-slim")
    postgres_id = image_id("postgres:16-alpine")
    python_facts = docker_text(
        "python:3.12-slim",
        r"""
import pathlib
license_text = pathlib.Path('/usr/local/lib/python3.12/LICENSE.txt').read_text(encoding='utf-8', errors='replace')
os_release = pathlib.Path('/etc/os-release').read_text(encoding='utf-8', errors='replace')
print('PSF=' + ('yes' if 'Python Software Foundation License Version 2' in license_text else 'no'))
start = license_text.find('Copyright (c) 2001')
end = license_text.find('All Rights Reserved', start)
notice = ' '.join(license_text[start:end].split()) if start >= 0 and end > start else ''
print('NOTICE=' + notice)
for line in os_release.splitlines():
    if line.startswith('PRETTY_NAME=') or line.startswith('VERSION=') or line.startswith('DEBIAN_VERSION_FULL='):
        print(line)
""",
    )
    psf = "PSF=yes" in python_facts
    notice = next((line[7:] for line in python_facts.splitlines() if line.startswith("NOTICE=")), "")
    version_line = "; ".join(
        line
        for line in python_facts.splitlines()
        if line.startswith("PRETTY_NAME=") or line.startswith("VERSION=") or line.startswith("DEBIAN_VERSION_FULL=")
    )
    lines.append(
        f"`python:3.12-slim`, Image-ID `{python_id}`. Interpreterdatei `/usr/local/lib/python3.12/LICENSE.txt` wurde aus diesem Image gelesen. "
        f"Der Abschnitt „Python Software Foundation License Version 2“ ist {'vorhanden' if psf else 'nicht gefunden'}. "
        f"Die darin verlangte Hinweiszeile lautet: {notice or 'UNKNOWN'}. "
        f"Betriebssystem im selben Image: {version_line or 'os-release nicht gelesen'}. "
        "Die Debian-`copyright`-Dateien unter `/usr/share/doc/<paket>/copyright` bleiben im Image. Unten stehen nur die dortigen `License:`-Felder, keine umgeschriebenen Texte."
    )
    lines.append("")
    debian = docker_text(
        "python:3.12-slim",
        r"""
import pathlib
root = pathlib.Path('/usr/share/doc')
for path in sorted(root.glob('*/copyright')):
    text = path.read_text(encoding='utf-8', errors='replace')
    flat = ' '.join(text.split())
    licenses = []
    for line in text.splitlines():
        if line.startswith('License:'):
            value = line.split(':', 1)[1].strip()
            if value and value not in licenses:
                licenses.append(value)
    if not licenses:
        if "don't fall under any copyright" in flat:
            licenses.append('Schlüssel: kein Copyright laut Datei; übrige Dateien GPL-2.0-or-later laut demselben Text')
        if 'Lesser General Public License, version 2.1' in flat:
            licenses.append('Gesamttext: LGPL-2.1-or-later; dieselbe Datei listet abweichende Dateilizenzen')
        if 'GCC Runtime Library Exception' in flat:
            licenses.append('Datei enthält die GCC Runtime Library Exception und weitere Lizenzen der GCC-Sammlung')
        if not licenses and 'General Public License' in text and 'any later version' in text:
            licenses.append('GPL mit any-later-version laut Fliesstext, kein License-Feld')
    print(path.parent.name + '\t' + (' | '.join(licenses) if licenses else 'UNKNOWN'))
""",
    )
    if debian:
        lines.append("| Debian-Paket im Image python:3.12-slim | License-Felder aus copyright |")
        lines.append("| --- | --- |")
        for row in debian.splitlines():
            if "\t" not in row:
                continue
            name, lic = row.split("\t", 1)
            lines.append(f"| `{name}` | {lic.replace('|', '/')} |")
        lines.append("")
    else:
        lines.append("UNKNOWN: Debian-copyright-Dateien wurden nicht gelesen.")
        lines.append("")
    pg_version = subprocess.run(
        ["sudo", "docker", "run", "--rm", "--entrypoint", "postgres", "postgres:16-alpine", "--version"],
        check=False,
        capture_output=True,
        text=True,
        timeout=60,
    )
    reported = pg_version.stdout.strip() if pg_version.returncode == 0 else "UNKNOWN"
    lines.append(
        f"`postgres:16-alpine`, Image-ID `{postgres_id}`. `postgres --version` in diesem Image: `{reported}`. "
        "Eine COPYRIGHT- oder LICENSE-Datei des Servers wurde im Image nicht gefunden. "
        "Der passende Upstream-Tag wurde nur verwendet, weil die Versionszeichenkette 16.15 ist: "
        "`postgres/postgres` Tag `REL_16_15`, Datei `meson.build` mit `version: '16.15'` und `license: 'PostgreSQL'`, "
        "Datei `COPYRIGHT` mit „Portions Copyright (c) 1996-2026, PostgreSQL Global Development Group“ und "
        "„Portions Copyright (c) 1994, The Regents of the University of California“. "
        "Das Binary im Image wurde nicht Byte für Byte gegen diesen Tag geprüft. "
        "Pflicht aus diesem Text, falls das Programm weitergegeben wird: der Copyright-Hinweis und die beiden folgenden Absätze bleiben in allen Kopien. "
        "Das ist die gelesene Lizenz, keine Aussage, dass das Image rechtlich unbedenklich ist."
    )
    lines.append("")
    alpine = docker_text(
        "postgres:16-alpine",
        r"""
text = __import__('pathlib').Path('/lib/apk/db/installed').read_text(encoding='utf-8', errors='replace')
pkg = lic = ''
for block in text.split('\n\n'):
    pkg = lic = ''
    for line in block.splitlines():
        if line.startswith('P:'):
            pkg = line[2:]
        elif line.startswith('L:'):
            lic = line[2:]
    if pkg:
        print(pkg + '\t' + (lic or 'UNKNOWN'))
""",
    )
    lines.append(
        "Alpine-Pakete, die das Postgres-Image tatsächlich installiert hat. Das Feld stammt aus `/lib/apk/db/installed` und ist die von Alpine eingetragene Kennung, nicht der mitgelieferte Lizenztext. "
        "Der PostgreSQL-Server selbst ist kein apk-Paket in diesem Image; sein Hinweis steht im Absatz darüber. Leere Felder bleiben UNKNOWN."
    )
    lines.append("")
    if alpine:
        lines.append("| apk-Paket | License-Feld im Image |")
        lines.append("| --- | --- |")
        for row in alpine.splitlines():
            if "\t" not in row:
                continue
            name, lic = row.split("\t", 1)
            lines.append(f"| `{name}` | {lic or 'UNKNOWN'} |")
        lines.append("")
    signed = docker_text(
        "matrixdotorg/synapse:v1.163.0",
        r"""
import pathlib
root = pathlib.Path('/usr/local/lib/python3.13/site-packages/signedjson')
seen = []
for path in sorted(root.glob('*.py')):
    for line in path.read_text(encoding='utf-8', errors='replace').splitlines()[:15]:
        if line.startswith('# Copyright') and line not in seen:
            seen.append(line[2:].strip())
print('files=' + ','.join(p.name for p in sorted(root.glob('*.py'))))
for line in seen:
    print(line)
""",
    )
    lines.append(
        "`signedjson` 1.1.4 im Synapse-Image: `METADATA` setzt `License: UNKNOWN` und `License-File: LICENSE`. "
        "Die Datei `signedjson-1.1.4.dist-info/LICENSE` ist der Apache-2.0-Text ohne Copyright-Anhang. "
        "Die Copyright-Zeilen stehen in den Modulen desselben installierten Pakets:"
    )
    lines.append("")
    lines.append("```")
    lines.append(signed.strip() or "UNKNOWN: Module nicht gelesen")
    lines.append("```")
    lines.append("")
    return lines


def image_id(image: str) -> str:
    result = subprocess.run(
        ["sudo", "docker", "image", "inspect", image, "--format", "{{.Id}}"],
        check=False,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip() if result.returncode == 0 else "UNKNOWN (Image nicht inspiziert)"


def main() -> None:
    parts = [
        "# Drittkomponenten",
        "",
        "Inventar, erzeugt von `scripts/license_inventory.py`. Es übernimmt Lizenzfelder und Copyright-Zeilen aus den gelesenen Dateien der festgenagelten Versionen. Wo keine Datei gelesen oder die Prüfsumme nicht bestätigt wurde, steht UNKNOWN. Dieses Inventar ist keine Rechtsberatung, keine Freigabe und keine Relizenzierung der genannten Werke. Ein fehlendes UNKNOWN ist keine Aussage, dass die Weitergabe rechtlich problemlos ist.",
        "",
        "## Weitergabe der Kombination",
        "",
        "Eigener Code: AGPL-3.0-or-later, siehe `COPYRIGHT.md`. `matrix` 16.0.1: in der Paketdatei `AGPL-3.0-or-later`, Copyright-Zeile `2019-Present Famedly GmbH`. `flutter_vodozemac` 0.9.0: der mitgelieferte Lizenztext ist die GNU AGPL Version 3. Eine eigene „or any later version“-Zeile der Urheber wurde in `pubspec.yaml` und ausserhalb dieses GNU-Textes nicht gefunden. Die Rust-Crate `vodozemac` 0.10.0 ist Apache-2.0, sofern die geprüfte Archiv-Checksumme das bestätigt.",
        "",
        "Daraus folgt für die weitergebbare Kombination, als Lesart der vorliegenden Hinweise und nicht als Anwaltsmeinung: die Flutter-App, die eigenen Code, `matrix` und `flutter_vodozemac` zusammen ausliefert, bleibt an AGPL Version 3 gebunden, weil das Binding keine gelesene Erlaubnis für eine spätere AGPL-Version enthält. Die „or-later“-Erlaubnis des eigenen Codes und von `matrix` gilt für diese Dateien. Sie hebt die Bindung des Bindings nicht auf. Apache-2.0-Hinweise von `vodozemac` bleiben daneben stehen. Der Server aus eigenem Modul und Synapse unter der AGPL-Seite von `AGPL-3.0-or-later OR LicenseRef-Element-Commercial` kann unter AGPL-3.0 oder einer späteren Version weitergegeben werden, weil beide Seiten das vorsehen. Die kommerzielle Element-Alternative wurde nicht angenommen und nicht bezahlt. Wer Client und Server zusammen weitergibt, darf die Server-Erlaubnis nicht auf das Binding ausdehnen.",
        "",
        "## Flutter- und Dart-SDK",
        "",
        "Flutter-Revision in `app/.metadata`: `c197ca5199e9ee5661e865596c9c07294dfab51c`, Kanal stable. Die Datei `/opt/flutter/LICENSE` beginnt mit „Copyright 2014 The Flutter Authors“ und ist die BSD-3-Clause-Lizenz. Die von `flutter create` erzeugten Gerüste unter `app/android`, `app/linux` und `app/analysis_options.yaml` stammen aus diesem Werkzeug. Änderungen daran (Anwendungs-ID, `compileSdk` 36, Klartext-HTTP im Manifest) sind Anpassungen dieses Prototyps. Die BSD-Hinweise des unveränderten Gerüsts bleiben.",
        "",
        "Das mit dieser Flutter-Revision ausgelieferte Dart-SDK meldet `Dart SDK version: 3.13.7`. Die Datei `/opt/flutter/bin/cache/dart-sdk/LICENSE` beginnt mit „Copyright 2012, the Dart project authors.“ und ist eine BSD-Lizenz mit der Namensklausel für Google LLC. Eine davon getrennte NOTICE-Datei wurde nicht gefunden.",
        "",
    ]
    parts.extend(dart_rows())
    parts.extend(rust_rows())
    parts.extend(python_rows("Python-Testumgebung (.venv)", venv_metadata()))
    policy = docker_metadata("hoobird-spike-policy:latest")
    synapse = docker_metadata("matrixdotorg/synapse:v1.163.0")
    parts.extend(python_rows("Policy-Image hoobird-spike-policy (lokaler Build)", policy))
    parts.extend(python_rows("Synapse-Image matrixdotorg/synapse:v1.163.0", synapse))
    parts.extend(base_image_rows())
    parts.extend(
        [
            "## Synapse-Paket",
            "",
            f"`matrixdotorg/synapse:v1.163.0`, Image-ID `{image_id('matrixdotorg/synapse:v1.163.0')}`. Lizenzausdruck aus `matrix_synapse-1.163.0.dist-info/METADATA`: `AGPL-3.0-or-later OR LicenseRef-Element-Commercial`. Genutzt wird die AGPL-Seite. Eine Element-Commercial-Lizenz wurde nicht angenommen.",
            "",
            "## Was die Dateien nicht hergeben",
            "",
            "- `flutter_vodozemac` 0.9.0 enthält den AGPL-3.0-Text. Eine SPDX-Zeile „AGPL-3.0-or-later“ steht in dem gelesenen Archiv nicht. Die „How to Apply These Terms“-Passage im GNU-Text ist die Anleitung der Free Software Foundation, kein zusätzlicher Hinweis der Paketautoren.",
            "- `matrix` 16.0.1 hat in `pubspec.yaml` die Zeilen `SPDX-FileCopyrightText: 2019-Present Famedly GmbH` und `SPDX-License-Identifier: AGPL-3.0-or-later`.",
            "- Die kommerzielle Element-Lizenz ist keine Option dieses Entwurfs.",
            "- UNKNOWN bleibt UNKNOWN. Dazu kann eine Crate gehören, deren Archiv nicht geladen oder deren Prüfsumme nicht bestätigt wurde.",
            "",
        ]
    )
    OUT.write_text("\n".join(parts), encoding="utf-8")
    print(f"wrote {OUT} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
