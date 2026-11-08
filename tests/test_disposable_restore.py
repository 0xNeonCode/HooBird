# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026. Legal name of the copyright holder is not recorded in this repository.
"""Dump and restore the disposable databases without touching the live ones."""

from __future__ import annotations

import hashlib
import os
import subprocess
from pathlib import Path

import psycopg2
import pytest

from tools.local_env import load_local_env

ROOT = Path(__file__).resolve().parents[1]
PGHOST = "127.0.0.1"
PGPORT = "15432"
load_local_env()


def _db_password(user: str) -> str:
    # Values come from runtime/localhost.env. They authenticate only to
    # 127.0.0.1:15432 of the compose project that was created with the same file.
    key = {
        "postgres": "POSTGRES_PASSWORD",
        "synapse": "SYNAPSE_DB_PASSWORD",
        "hoobird_policy": "POLICY_DB_PASSWORD",
    }[user]
    value = os.environ.get(key, "")
    if not value or value.startswith("replace-with-"):
        pytest.fail(f"{key} fehlt in runtime/localhost.env")
    return value


def _psql(sql: str, database: str = "postgres", user: str = "postgres") -> str:
    env = os.environ.copy()
    env["PGPASSWORD"] = _db_password(user)
    result = subprocess.run(
        [
            "psql",
            "-h",
            PGHOST,
            "-p",
            PGPORT,
            "-U",
            user,
            "-d",
            database,
            "-v",
            "ON_ERROR_STOP=1",
            "-tA",
            "-c",
            sql,
        ],
        check=True,
        capture_output=True,
        text=True,
        env=env,
    )
    return result.stdout.strip()


def _count(database: str, user: str, table: str) -> int:
    return int(_psql(f"SELECT count(*) FROM {table}", database, user))


def test_policy_dump_restores_into_a_separate_database():
    live = _count("hoobird_policy", "hoobird_policy", "accounts")
    assert live >= 1
    dump = subprocess.run(
        [
            "pg_dump",
            "-h",
            PGHOST,
            "-p",
            PGPORT,
            "-U",
            "hoobird_policy",
            "--no-owner",
            "hoobird_policy",
        ],
        check=True,
        capture_output=True,
        env={**os.environ, "PGPASSWORD": _db_password("hoobird_policy")},
    )
    assert b"CREATE TABLE" in dump.stdout
    _psql("DROP DATABASE IF EXISTS hoobird_policy_restore")
    _psql("CREATE DATABASE hoobird_policy_restore")
    try:
        restore = subprocess.run(
            [
                "psql",
                "-h",
                PGHOST,
                "-p",
                PGPORT,
                "-U",
                "postgres",
                "-d",
                "hoobird_policy_restore",
                "-v",
                "ON_ERROR_STOP=1",
            ],
            input=dump.stdout,
            check=True,
            capture_output=True,
            env={**os.environ, "PGPASSWORD": _db_password("postgres")},
        )
        assert restore.returncode == 0
        restored = _count("hoobird_policy_restore", "postgres", "accounts")
        assert restored == live
        live_after = _count("hoobird_policy", "hoobird_policy", "accounts")
        assert live_after == live
    finally:
        _psql("DROP DATABASE IF EXISTS hoobird_policy_restore")


def test_signing_key_and_media_are_files_not_the_recovery_key():
    signing = ROOT / "runtime" / "synapse" / "hoobird.signing.key"
    assert signing.is_file()
    digest = hashlib.sha256(signing.read_bytes()).hexdigest()
    assert len(digest) == 64
    media = ROOT / "runtime" / "synapse" / "media_store"
    assert media.is_dir()
    # A server copy of these files does not restore Megolm sessions.
    assert b"recovery" not in signing.read_bytes().lower()


@pytest.mark.skipif(not os.path.exists("/usr/bin/pg_dump"), reason="pg_dump missing")
def test_synapse_event_dump_roundtrip_count():
    with psycopg2.connect(
        host=PGHOST,
        port=PGPORT,
        user="synapse",
        password=_db_password("synapse"),
        dbname="synapse",
    ) as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT count(*) FROM event_json")
            live = cur.fetchone()[0]
    assert live > 0
    dump = subprocess.run(
        [
            "pg_dump",
            "-h",
            PGHOST,
            "-p",
            PGPORT,
            "-U",
            "synapse",
            "--no-owner",
            "--table=event_json",
            "synapse",
        ],
        check=True,
        capture_output=True,
        env={**os.environ, "PGPASSWORD": _db_password("synapse")},
    )
    _psql("DROP DATABASE IF EXISTS synapse_event_restore")
    _psql(
        "CREATE DATABASE synapse_event_restore WITH TEMPLATE template0 LC_COLLATE 'C' LC_CTYPE 'C'"
    )
    try:
        subprocess.run(
            [
                "psql",
                "-h",
                PGHOST,
                "-p",
                PGPORT,
                "-U",
                "postgres",
                "-d",
                "synapse_event_restore",
                "-v",
                "ON_ERROR_STOP=1",
            ],
            input=dump.stdout,
            check=True,
            capture_output=True,
            env={**os.environ, "PGPASSWORD": _db_password("postgres")},
        )
        restored = int(_psql("SELECT count(*) FROM event_json", "synapse_event_restore", "postgres"))
        assert restored == live
    finally:
        _psql("DROP DATABASE IF EXISTS synapse_event_restore")
