# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026. Legal name of the copyright holder is not recorded in this repository.
"""Shared client for tests that need the disposable local stack."""

from __future__ import annotations

import os
import uuid
from urllib.parse import quote

import httpx
import pytest

from tools.local_env import load_local_env

load_local_env()
SERVER = os.environ.get("HOOBIRD_SYNAPSE", "http://127.0.0.1:18008")
POLICY = os.environ.get("HOOBIRD_POLICY", "http://127.0.0.1:18018")
ADMIN_PASSWORD = os.environ.get("ADMIN_PASSWORD", "")
if not ADMIN_PASSWORD or ADMIN_PASSWORD.startswith("replace-with-"):
    ADMIN_PASSWORD = ""


class Stack:
    def __init__(self, client: httpx.Client):
        self.client = client
        self.admin = self.login("hoobird-admin", ADMIN_PASSWORD, "ADMINDEVICE01")

    def h(self, token: str) -> dict[str, str]:
        return {"Authorization": f"Bearer {token}"}

    def login(self, username: str, password: str, device_id: str | None = None) -> dict:
        body: dict = {"username": username, "password": password}
        if device_id:
            body["device_id"] = device_id
        response = self.client.post(f"{POLICY}/_hoobird/v1/login", json=body)
        assert response.status_code == 200, response.text
        return response.json()

    def create(
        self,
        token: str,
        *,
        role: str,
        device_id: str | None = None,
        email: str | None = None,
        password: str | None = None,
    ) -> dict:
        username = f"{role[:1]}{uuid.uuid4().hex[:10]}"
        body: dict = {
            "username": username,
            "password": password or f"Passwort-{uuid.uuid4().hex[:8]}",
            "role": role,
        }
        if device_id:
            body["device_id"] = device_id
        if email:
            body["email"] = email
        response = self.client.post(
            f"{POLICY}/_hoobird/v1/accounts",
            json=body,
            headers=self.h(token),
        )
        assert response.status_code == 200, response.text
        payload = response.json()
        payload["password"] = body["password"]
        return payload

    def mx(self, method: str, path: str, token: str | None = None, json_body: dict | None = None, content: bytes | None = None, content_type: str | None = None):
        headers = {}
        if token:
            headers["Authorization"] = f"Bearer {token}"
        if content_type:
            headers["Content-Type"] = content_type
        return self.client.request(
            method,
            f"{SERVER}{path}",
            headers=headers,
            json=json_body,
            content=content,
        )

    def raw_login(self, localpart: str, password: str, device_id: str | None = None):
        body: dict = {
            "type": "m.login.password",
            "identifier": {"type": "m.id.user", "user": localpart},
            "password": password,
        }
        if device_id is not None:
            body["device_id"] = device_id
        return self.client.post(f"{SERVER}/_matrix/client/v3/login", json=body)

    def create_room(self, token: str, invites: list[str], direct: bool = False):
        return self.mx(
            "POST",
            "/_matrix/client/v3/createRoom",
            token,
            {
                "preset": "private_chat",
                "invite": invites,
                "is_direct": direct,
                "creation_content": {"m.federate": False},
            },
        )

    def invite(self, token: str, room_id: str, user_id: str):
        return self.mx(
            "POST",
            f"/_matrix/client/v3/rooms/{quote(room_id, safe='')}/invite",
            token,
            {"user_id": user_id},
        )

    def join(self, token: str, room_id: str):
        return self.mx(
            "POST",
            f"/_matrix/client/v3/join/{quote(room_id, safe='')}",
            token,
            {},
        )

    def send_plain(self, token: str, room_id: str, body: str):
        txn = uuid.uuid4().hex
        return self.mx(
            "PUT",
            f"/_matrix/client/v3/rooms/{quote(room_id, safe='')}/send/m.room.message/{txn}",
            token,
            {"msgtype": "m.text", "body": body},
        )

    def send_fake_encrypted(self, token: str, room_id: str):
        txn = uuid.uuid4().hex
        return self.mx(
            "PUT",
            f"/_matrix/client/v3/rooms/{quote(room_id, safe='')}/send/m.room.encrypted/{txn}",
            token,
            {
                "algorithm": "m.megolm.v1.aes-sha2",
                "sender_key": "curve25519-device",
                "session_id": "session-1",
                "ciphertext": "QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVo=",
            },
        )


def localpart(user_id: str) -> str:
    return user_id.split(":", 1)[0][1:]


@pytest.fixture(scope="session")
def stack() -> Stack:
    with httpx.Client(timeout=30.0) as client:
        health = client.get(f"{POLICY}/_hoobird/health")
        if health.status_code != 200:
            pytest.fail(f"policy health {health.status_code}: {health.text}")
        if not ADMIN_PASSWORD:
            pytest.fail(
                "ADMIN_PASSWORD fehlt. runtime/localhost.env anlegen "
                "(Vorlage config/localhost.env.example). Der Wert gilt nur für diesen lokalen Stack."
            )
        yield Stack(client)
