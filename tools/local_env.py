# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026. Legal name of the copyright holder is not recorded in this repository.
"""Load disposable localhost settings without printing them.

The file runtime/localhost.env is gitignored. It is created on the machine
that runs the compose stack. Values in it authenticate only to that stack.
They are not credentials for any other host.
"""

from __future__ import annotations

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENV_PATH = ROOT / "runtime" / "localhost.env"


def load_local_env() -> None:
    if not ENV_PATH.is_file():
        return
    for raw in ENV_PATH.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


def require(name: str) -> str:
    load_local_env()
    value = os.environ.get(name, "")
    if not value or value.startswith("replace-with-"):
        raise SystemExit(
            f"{name} ist nicht gesetzt. Kopiere config/localhost.env.example nach "
            "runtime/localhost.env und setze einen Wert, der nur für den lokalen "
            "Stack gilt. Lege denselben Wert nicht auf einem erreichbaren Server ab."
        )
    return value
