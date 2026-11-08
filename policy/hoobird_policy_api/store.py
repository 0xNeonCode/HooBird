# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026. Legal name of the copyright holder is not recorded in this repository.
"""PostgreSQL access for HooBird policy. Uses psycopg2, which Synapse already ships."""

from __future__ import annotations

import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone

import psycopg2
from psycopg2 import errors

from hoobird_rules import LOCALPART_RE, PolicyView

SCHEMA = """
CREATE TABLE IF NOT EXISTS accounts (
    user_id TEXT PRIMARY KEY,
    localpart TEXT NOT NULL UNIQUE,
    username TEXT NOT NULL,
    username_folded TEXT NOT NULL UNIQUE,
    role TEXT NOT NULL CHECK (role IN ('parent', 'child', 'adult')),
    is_bootstrap BOOLEAN NOT NULL DEFAULT FALSE,
    email TEXT,
    email_confirmed BOOLEAN NOT NULL DEFAULT FALSE,
    email_token_hash TEXT,
    created_by TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS parent_links (
    child_user_id TEXT NOT NULL REFERENCES accounts(user_id),
    parent_user_id TEXT NOT NULL REFERENCES accounts(user_id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (child_user_id, parent_user_id)
);

CREATE TABLE IF NOT EXISTS approvals (
    child_user_id TEXT NOT NULL REFERENCES accounts(user_id),
    contact_user_id TEXT NOT NULL REFERENCES accounts(user_id),
    approved_by TEXT NOT NULL REFERENCES accounts(user_id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (child_user_id, contact_user_id)
);

CREATE TABLE IF NOT EXISTS blocks (
    child_user_id TEXT NOT NULL REFERENCES accounts(user_id),
    contact_user_id TEXT NOT NULL REFERENCES accounts(user_id),
    blocked_by TEXT NOT NULL REFERENCES accounts(user_id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (child_user_id, contact_user_id, blocked_by)
);

CREATE TABLE IF NOT EXISTS device_authorizations (
    child_user_id TEXT NOT NULL REFERENCES accounts(user_id),
    device_id TEXT NOT NULL,
    authorized_by TEXT NOT NULL REFERENCES accounts(user_id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (child_user_id, device_id)
);

CREATE TABLE IF NOT EXISTS link_codes (
    code_hash TEXT PRIMARY KEY,
    child_user_id TEXT NOT NULL REFERENCES accounts(user_id),
    created_by TEXT NOT NULL REFERENCES accounts(user_id),
    expires_at TIMESTAMPTZ NOT NULL,
    consumed_at TIMESTAMPTZ
);
"""


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def new_localpart() -> str:
    return "hb" + secrets.token_hex(16)


class PolicyStore:
    def __init__(self, dsn: str):
        self.dsn = dsn

    def _connect(self):
        return psycopg2.connect(
            self.dsn,
            connect_timeout=3,
            options="-c statement_timeout=3000",
        )

    def ensure_schema(self) -> None:
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(SCHEMA)

    def get_account(self, user_id: str) -> dict | None:
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT user_id, localpart, username, role, is_bootstrap,
                           email, email_confirmed
                    FROM accounts WHERE user_id = %s
                    """,
                    (user_id,),
                )
                row = cur.fetchone()
        return _account_row(row) if row else None

    def get_by_username(self, username_folded: str) -> dict | None:
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT user_id, localpart, username, role, is_bootstrap,
                           email, email_confirmed
                    FROM accounts WHERE username_folded = %s
                    """,
                    (username_folded,),
                )
                row = cur.fetchone()
        return _account_row(row) if row else None

    def search_usernames(self, prefix: str, limit: int = 20) -> list[dict]:
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT user_id, localpart, username, role, is_bootstrap,
                           NULL::text, email_confirmed
                    FROM accounts
                    WHERE username_folded LIKE %s AND is_bootstrap = FALSE
                    ORDER BY username_folded
                    LIMIT %s
                    """,
                    (prefix + "%", limit),
                )
                return [_account_row(row) for row in cur.fetchall()]

    def insert_account(
        self,
        *,
        user_id: str,
        localpart: str,
        username: str,
        username_folded: str,
        role: str,
        created_by: str | None,
        is_bootstrap: bool = False,
    ) -> None:
        if not LOCALPART_RE.fullmatch(localpart) and not is_bootstrap:
            raise ValueError("localpart must be an opaque hb id")
        try:
            with self._connect() as conn:
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        INSERT INTO accounts (
                            user_id, localpart, username, username_folded, role,
                            is_bootstrap, created_by
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s)
                        """,
                        (
                            user_id,
                            localpart,
                            username,
                            username_folded,
                            role,
                            is_bootstrap,
                            created_by,
                        ),
                    )
        except errors.UniqueViolation as exc:
            raise Conflict(str(exc.diag.constraint_name or "unique")) from exc

    def delete_account(self, user_id: str) -> None:
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute("DELETE FROM accounts WHERE user_id = %s", (user_id,))

    def update_username(self, user_id: str, username: str, username_folded: str) -> None:
        try:
            with self._connect() as conn:
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        UPDATE accounts
                        SET username = %s, username_folded = %s
                        WHERE user_id = %s
                        """,
                        (username, username_folded, user_id),
                    )
                    if cur.rowcount != 1:
                        raise NotFound("account")
        except errors.UniqueViolation as exc:
            raise Conflict("username") from exc

    def set_email(self, user_id: str, email: str, token: str) -> None:
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE accounts
                    SET email = %s, email_confirmed = FALSE, email_token_hash = %s
                    WHERE user_id = %s
                    """,
                    (email, hash_token(token), user_id),
                )
                if cur.rowcount != 1:
                    raise NotFound("account")

    def confirm_email(self, user_id: str, token: str) -> bool:
        digest = hash_token(token)
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT email_token_hash FROM accounts WHERE user_id = %s",
                    (user_id,),
                )
                row = cur.fetchone()
                if row is None or not row[0]:
                    return False
                if not hmac.compare_digest(row[0], digest):
                    return False
                cur.execute(
                    """
                    UPDATE accounts
                    SET email_confirmed = TRUE, email_token_hash = NULL
                    WHERE user_id = %s
                    """,
                    (user_id,),
                )
        return True

    def link_parent(self, child_user_id: str, parent_user_id: str) -> None:
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO parent_links (child_user_id, parent_user_id)
                    VALUES (%s, %s)
                    ON CONFLICT DO NOTHING
                    """,
                    (child_user_id, parent_user_id),
                )

    def parent_count(self, child_user_id: str) -> int:
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT COUNT(*) FROM parent_links WHERE child_user_id = %s",
                    (child_user_id,),
                )
                return int(cur.fetchone()[0])

    def is_linked_parent(self, child_user_id: str, parent_user_id: str) -> bool:
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT 1 FROM parent_links
                    WHERE child_user_id = %s AND parent_user_id = %s
                    """,
                    (child_user_id, parent_user_id),
                )
                return cur.fetchone() is not None

    def parents_of(self, child_user_id: str) -> list[str]:
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT parent_user_id FROM parent_links
                    WHERE child_user_id = %s ORDER BY created_at
                    """,
                    (child_user_id,),
                )
                return [row[0] for row in cur.fetchall()]

    def children_of(self, parent_user_id: str) -> list[str]:
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT child_user_id FROM parent_links
                    WHERE parent_user_id = %s ORDER BY created_at
                    """,
                    (parent_user_id,),
                )
                return [row[0] for row in cur.fetchall()]

    def create_link_code(self, child_user_id: str, created_by: str, ttl_seconds: int) -> str:
        code = secrets.token_urlsafe(18)
        expires = datetime.now(timezone.utc) + timedelta(seconds=ttl_seconds)
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO link_codes (code_hash, child_user_id, created_by, expires_at)
                    VALUES (%s, %s, %s, %s)
                    """,
                    (hash_token(code), child_user_id, created_by, expires),
                )
        return code

    def redeem_link_code(self, child_user_id: str, parent_user_id: str, code: str) -> str:
        """Returns 'ok' or an error code. Single-use, expiry checked in SQL."""

        digest = hash_token(code)
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT expires_at, consumed_at
                    FROM link_codes
                    WHERE code_hash = %s AND child_user_id = %s
                    FOR UPDATE
                    """,
                    (digest, child_user_id),
                )
                row = cur.fetchone()
                if row is None:
                    return "bad_code"
                expires_at, consumed_at = row
                if consumed_at is not None:
                    return "consumed"
                if expires_at < datetime.now(timezone.utc):
                    return "expired"
                cur.execute(
                    "SELECT COUNT(*) FROM parent_links WHERE child_user_id = %s",
                    (child_user_id,),
                )
                if int(cur.fetchone()[0]) >= 2:
                    return "parent_limit"
                cur.execute(
                    """
                    SELECT 1 FROM parent_links
                    WHERE child_user_id = %s AND parent_user_id = %s
                    """,
                    (child_user_id, parent_user_id),
                )
                if cur.fetchone():
                    return "already_linked"
                cur.execute(
                    """
                    INSERT INTO parent_links (child_user_id, parent_user_id)
                    VALUES (%s, %s)
                    """,
                    (child_user_id, parent_user_id),
                )
                cur.execute(
                    """
                    UPDATE link_codes SET consumed_at = now()
                    WHERE code_hash = %s
                    """,
                    (digest,),
                )
        return "ok"

    def add_approval(self, child_user_id: str, contact_user_id: str, approved_by: str) -> None:
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO approvals (child_user_id, contact_user_id, approved_by)
                    VALUES (%s, %s, %s)
                    ON CONFLICT (child_user_id, contact_user_id) DO NOTHING
                    """,
                    (child_user_id, contact_user_id, approved_by),
                )

    def delete_approval(self, child_user_id: str, contact_user_id: str) -> bool:
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    DELETE FROM approvals
                    WHERE child_user_id = %s AND contact_user_id = %s
                    """,
                    (child_user_id, contact_user_id),
                )
                return cur.rowcount > 0

    def list_approvals(self, child_user_id: str) -> list[dict]:
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT contact_user_id, approved_by FROM approvals
                    WHERE child_user_id = %s ORDER BY contact_user_id
                    """,
                    (child_user_id,),
                )
                return [
                    {"contact_user_id": row[0], "approved_by": row[1]}
                    for row in cur.fetchall()
                ]

    def add_block(self, child_user_id: str, contact_user_id: str, blocked_by: str) -> None:
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO blocks (child_user_id, contact_user_id, blocked_by)
                    VALUES (%s, %s, %s)
                    ON CONFLICT DO NOTHING
                    """,
                    (child_user_id, contact_user_id, blocked_by),
                )

    def delete_block(self, child_user_id: str, contact_user_id: str, blocked_by: str) -> bool:
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    DELETE FROM blocks
                    WHERE child_user_id = %s AND contact_user_id = %s AND blocked_by = %s
                    """,
                    (child_user_id, contact_user_id, blocked_by),
                )
                return cur.rowcount > 0

    def blocks_for(self, child_user_id: str, contact_user_id: str) -> set[str]:
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT blocked_by FROM blocks
                    WHERE child_user_id = %s AND contact_user_id = %s
                    """,
                    (child_user_id, contact_user_id),
                )
                return {row[0] for row in cur.fetchall()}

    def list_blocks(self, child_user_id: str) -> list[dict]:
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT contact_user_id, blocked_by FROM blocks
                    WHERE child_user_id = %s ORDER BY contact_user_id, blocked_by
                    """,
                    (child_user_id,),
                )
                return [
                    {"contact_user_id": row[0], "blocked_by": row[1]}
                    for row in cur.fetchall()
                ]

    def authorize_device(self, child_user_id: str, device_id: str, authorized_by: str) -> None:
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO device_authorizations (child_user_id, device_id, authorized_by)
                    VALUES (%s, %s, %s)
                    ON CONFLICT DO NOTHING
                    """,
                    (child_user_id, device_id, authorized_by),
                )

    def revoke_device(self, child_user_id: str, device_id: str) -> bool:
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    DELETE FROM device_authorizations
                    WHERE child_user_id = %s AND device_id = %s
                    """,
                    (child_user_id, device_id),
                )
                return cur.rowcount > 0

    def device_authorized(self, child_user_id: str, device_id: str) -> bool:
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT 1 FROM device_authorizations
                    WHERE child_user_id = %s AND device_id = %s
                    """,
                    (child_user_id, device_id),
                )
                return cur.fetchone() is not None

    def list_devices(self, child_user_id: str) -> list[dict]:
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT device_id, authorized_by FROM device_authorizations
                    WHERE child_user_id = %s ORDER BY device_id
                    """,
                    (child_user_id,),
                )
                return [
                    {"device_id": row[0], "authorized_by": row[1]}
                    for row in cur.fetchall()
                ]

    def view_for(self, user_ids: list[str]) -> PolicyView:
        unique = sorted({user_id for user_id in user_ids if user_id})
        view = PolicyView()
        if not unique:
            return view
        with self._connect() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT user_id, role FROM accounts WHERE user_id = ANY(%s)",
                    (unique,),
                )
                view.roles = {row[0]: row[1] for row in cur.fetchall()}
                children = [user_id for user_id, role in view.roles.items() if role == "child"]
                if not children:
                    return view
                cur.execute(
                    """
                    SELECT child_user_id, parent_user_id
                    FROM parent_links WHERE child_user_id = ANY(%s)
                    """,
                    (children,),
                )
                for child_id, parent_id in cur.fetchall():
                    view.parents.setdefault(child_id, set()).add(parent_id)
                cur.execute(
                    """
                    SELECT child_user_id, contact_user_id, approved_by
                    FROM approvals
                    WHERE child_user_id = ANY(%s) AND contact_user_id = ANY(%s)
                    """,
                    (children, unique),
                )
                for child_id, contact_id, approved_by in cur.fetchall():
                    view.approvals[(child_id, contact_id)] = approved_by
                cur.execute(
                    """
                    SELECT child_user_id, contact_user_id, blocked_by
                    FROM blocks
                    WHERE child_user_id = ANY(%s) AND contact_user_id = ANY(%s)
                    """,
                    (children, unique),
                )
                for child_id, contact_id, blocked_by in cur.fetchall():
                    view.blocks.setdefault((child_id, contact_id), set()).add(blocked_by)
        return view

    def role_of(self, user_id: str) -> str | None:
        account = self.get_account(user_id)
        return account["role"] if account else None


class Conflict(Exception):
    pass


class NotFound(Exception):
    pass


def _account_row(row) -> dict:
    return {
        "user_id": row[0],
        "localpart": row[1],
        "username": row[2],
        "role": row[3],
        "is_bootstrap": bool(row[4]),
        "email": row[5],
        "email_confirmed": bool(row[6]),
    }
