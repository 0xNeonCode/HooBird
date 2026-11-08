# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026. Legal name of the copyright holder is not recorded in this repository.
"""Checks the publication tree and the generated licence inventory.

These checks read files. They are not a legal opinion and not a secret scan
of the old git history.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

LEGACY = (
    "Oma-Passwort-",
    "Linus-Passwort-",
    "Mara-Passwort-",
    "Kind-Passwort-",
    "Eltern-Passwort-",
    "dev-only-admin-password",
    "dev-only-hoobird-",
    "Neues-Passwort-1847",
)


def test_tracked_tree_has_no_legacy_fixture_secrets() -> None:
    tracked = subprocess.check_output(["git", "ls-files"], cwd=ROOT, text=True).splitlines()
    hits: list[str] = []
    for relative in tracked:
        if relative == "tests/test_publication_tree.py":
            continue
        path = ROOT / relative
        if not path.is_file():
            continue
        if path.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"}:
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for needle in LEGACY:
            if needle in text:
                hits.append(f"{relative}: {needle}")
    assert hits == []


def test_example_env_is_not_usable() -> None:
    text = (ROOT / "config" / "localhost.env.example").read_text(encoding="utf-8")
    assert "replace-with-a-localhost-only-value" in text
    for needle in LEGACY:
        assert needle not in text


def test_license_inventory_records_pinned_evidence() -> None:
    text = (ROOT / "THIRD_PARTY_NOTICES.md").read_text(encoding="utf-8")
    assert "Davon mit UNKNOWN im Lizenzfeld: 0." in text
    assert "allo-isolate" in text and "Apache-2.0 aus LICENSE" in text
    assert "sha256 = Cargo.lock" in text
    assert "signedjson" in text and "Copyright 2014 OpenMarket Ltd" in text
    assert "postgres (PostgreSQL) 16.15" in text
    assert "REL_16_15" in text
    assert "REL_16_STABLE" not in text
    assert "Python Software Foundation License Version 2" in text
    assert "AGPL-3.0-or-later OR LicenseRef-Element-Commercial" in text
    assert "keine Anwaltsmeinung" in text or "nicht als Anwaltsmeinung" in text
