#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026. Legal name of the copyright holder is not recorded in this repository.
"""Create runtime/localhost.env with disposable random values.

Does not overwrite an existing file. The example file stays full of
placeholders and does not authenticate anywhere. Generated values work
only for a compose stack started with this same file on 127.0.0.1.
"""

from __future__ import annotations

import secrets
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "runtime" / "localhost.env"


def main() -> None:
    if TARGET.exists():
        print(f"{TARGET} existiert und wird nicht ersetzt")
        return
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    policy_password = secrets.token_urlsafe(24)
    values = {
        "REGISTRATION_SHARED_SECRET": secrets.token_urlsafe(32),
        "MACAROON_SECRET_KEY": secrets.token_urlsafe(32),
        "FORM_SECRET": secrets.token_urlsafe(32),
        "ADMIN_LOCALPART": "hoobirdadmin",
        "ADMIN_USERNAME": "hoobird-admin",
        "ADMIN_PASSWORD": secrets.token_urlsafe(24),
        "POSTGRES_PASSWORD": secrets.token_urlsafe(24),
        "SYNAPSE_DB_PASSWORD": secrets.token_urlsafe(24),
        "POLICY_DB_PASSWORD": policy_password,
        "POLICY_DSN": f"postgresql://hoobird_policy:{policy_password}@127.0.0.1:15432/hoobird_policy",
        "HOOBIRD_DEV_RETURN_EMAIL_TOKENS": "1",
    }
    lines = [
        "# Generated for this machine only. Gitignored.",
        "# Authenticates only the compose stack started from this file.",
        "# Not a credential for any other host.",
    ]
    lines.extend(f"{key}={value}" for key, value in values.items())
    TARGET.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"geschrieben: {TARGET}")


if __name__ == "__main__":
    main()
