#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026. Legal name of the copyright holder is not recorded in this repository.
"""Write synapse/homeserver.yaml from the example and runtime/localhost.env.

Refuses to overwrite an existing homeserver.yaml. That file is gitignored
because it holds the local stack's secrets. Resetting it is a separate,
explicit step: delete the file yourself, then run this script again.
This does not touch a remote server.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tools.local_env import load_local_env, require  # noqa: E402

EXAMPLE = ROOT / "synapse" / "homeserver.example.yaml"
TARGET = ROOT / "synapse" / "homeserver.yaml"


def main() -> None:
    if TARGET.exists():
        raise SystemExit(
            f"{TARGET} existiert schon und wird nicht überschrieben. "
            "Löschen nur, wenn dieser lokale Stack neu aufgesetzt werden soll."
        )
    load_local_env()
    text = EXAMPLE.read_text(encoding="utf-8")
    replacements = {
        "__REGISTRATION_SHARED_SECRET__": require("REGISTRATION_SHARED_SECRET"),
        "__MACAROON_SECRET_KEY__": require("MACAROON_SECRET_KEY"),
        "__FORM_SECRET__": require("FORM_SECRET"),
        "__SYNAPSE_DB_PASSWORD__": require("SYNAPSE_DB_PASSWORD"),
        "__POLICY_DB_PASSWORD__": require("POLICY_DB_PASSWORD"),
    }
    for token, value in replacements.items():
        if token not in text:
            raise SystemExit(f"Platzhalter {token} fehlt in {EXAMPLE}")
        text = text.replace(token, value)
    if "__" in text:
        raise SystemExit("homeserver.example.yaml enthält noch unbekannte Platzhalter")
    TARGET.write_text(text, encoding="utf-8")
    print(f"geschrieben: {TARGET} (gitignored, nur dieser Rechner)")


if __name__ == "__main__":
    main()
