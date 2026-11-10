#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026. Legal name of the copyright holder is not recorded in this repository.
"""Create fictitious local accounts and one encrypted room.

The passwords below are chosen by this script when it creates accounts in the
local database. They do not exist anywhere until the script runs, and they
authenticate only against that database. They are not accounts on another
host. The admin password is read from runtime/localhost.env and is not stored
in this file. Re-running skips names that already exist.
"""

from __future__ import annotations

import asyncio
import json
import os
import secrets
import sys
import tempfile
from pathlib import Path

import httpx
from nio import AsyncClient, LocalProtocolError, RoomSendResponse, UploadResponse

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
from tools.local_env import require

POLICY = os.environ.get("HOOBIRD_POLICY", "http://127.0.0.1:18018")
SERVER = os.environ.get("HOOBIRD_SYNAPSE", "http://127.0.0.1:18008")
OUT = ROOT / "runtime" / "demo-accounts.json"

SPECS = {
    "oma": {"role": "parent", "device": "OMADEMO01"},
    "linus": {"role": "parent", "device": "LINUSDEMO1"},
    "mara": {"role": "adult", "device": "MARADEMO01"},
    "fremder": {"role": "adult", "device": "FREMDDEMO1"},
    "jonas": {"role": "child", "device": "JONASDEMO01"},
}
# Not a phone Olm key. The seed script does not upload device keys for Jonas.
JONAS_PLACEHOLDER_ED25519 = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
ACCOUNTS: dict[str, dict[str, str]] = {}


def load_accounts() -> dict[str, dict[str, str]]:
    """Reuse passwords already written to the gitignored demo file, or mint new ones.

    The passwords are not in this source file. They authenticate only to the
    local database after this script creates or finds the accounts.
    """
    stored: dict = {}
    if OUT.is_file():
        stored = json.loads(OUT.read_text(encoding="utf-8")).get("accounts", {})
    accounts: dict[str, dict[str, str]] = {}
    for name, spec in SPECS.items():
        previous = stored.get(name, {})
        password = previous.get("password") or secrets.token_urlsafe(18)
        accounts[name] = {"password": password, "role": spec["role"], "device": spec["device"]}
    return accounts


def _headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def login(client: httpx.Client, username: str, password: str, device: str) -> dict:
    response = client.post(
        f"{POLICY}/_hoobird/v1/login",
        json={"username": username, "password": password, "device_id": device, "device_name": "HooBird"},
    )
    response.raise_for_status()
    return response.json()


def ensure_adult(client: httpx.Client, admin_token: str, username: str) -> dict:
    spec = ACCOUNTS[username]
    try:
        found = login(client, username, spec["password"], spec["device"])
        return found
    except httpx.HTTPStatusError:
        pass
    created = client.post(
        f"{POLICY}/_hoobird/v1/accounts",
        headers=_headers(admin_token),
        json={"username": username, "password": spec["password"], "role": spec["role"]},
    )
    created.raise_for_status()
    return login(client, username, spec["password"], spec["device"])


async def _pump(client: AsyncClient) -> None:
    await client.sync(timeout=2000)
    if client.olm:
        for action in (client.keys_upload, client.keys_query):
            try:
                await action()
            except LocalProtocolError:
                pass


async def encrypted_hello(oma: dict, mara: dict) -> str:
    root = tempfile.mkdtemp(prefix="hoobird-seed-")
    os.makedirs(f"{root}/oma", exist_ok=True)
    os.makedirs(f"{root}/mara", exist_ok=True)
    clients = []
    try:
        left = AsyncClient(SERVER, oma["user_id"], store_path=f"{root}/oma", device_id="OMADEMO01")
        right = AsyncClient(SERVER, mara["user_id"], store_path=f"{root}/mara", device_id="MARADEMO01")
        clients.extend([left, right])
        await left.login(ACCOUNTS["oma"]["password"], device_name="HooBird")
        await right.login(ACCOUNTS["mara"]["password"], device_name="HooBird")
        await _pump(left)
        await _pump(right)
        room = await left.room_create(
            name="Familie",
            invite=[mara["user_id"]],
            federate=False,
            initial_state=[
                {
                    "type": "m.room.encryption",
                    "state_key": "",
                    "content": {"algorithm": "m.megolm.v1.aes-sha2"},
                }
            ],
        )
        if not hasattr(room, "room_id"):
            raise RuntimeError(str(room))
        joined = await right.join(room.room_id)
        if getattr(joined, "transport_response", None) and joined.transport_response.status != 200:
            raise RuntimeError(joined.transport_response.status)
        await _pump(left)
        await _pump(right)
        sent = await left.room_send(
            room.room_id,
            "m.room.message",
            {"msgtype": "m.text", "body": "Fiktive Saatnachricht, nur lokal."},
            ignore_unverified_devices=True,
        )
        if not isinstance(sent, RoomSendResponse):
            raise RuntimeError(str(sent))
        upload, keys = await left.upload(
            __import__("io").BytesIO(os.urandom(32)),
            filename="ton.wav",
            encrypt=True,
            filesize=32,
        )
        if not isinstance(upload, UploadResponse):
            raise RuntimeError(str(upload))
        voice = await left.room_send(
            room.room_id,
            "m.room.message",
            {"msgtype": "m.audio", "body": "ton.wav", "file": keys},
            ignore_unverified_devices=True,
        )
        if not isinstance(voice, RoomSendResponse):
            raise RuntimeError(str(voice))
        return room.room_id
    finally:
        for client in clients:
            await client.close()


def main() -> None:
    global ACCOUNTS
    require("ADMIN_PASSWORD")
    ACCOUNTS = load_accounts()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with httpx.Client(timeout=30) as client:
        admin = login(client, "hoobird-admin", os.environ["ADMIN_PASSWORD"], "ADMINSEED01")
        oma = ensure_adult(client, admin["access_token"], "oma")
        linus = ensure_adult(client, admin["access_token"], "linus")
        mara = ensure_adult(client, admin["access_token"], "mara")
        fremder = ensure_adult(client, admin["access_token"], "fremder")
        jonas_spec = ACCOUNTS["jonas"]
        try:
            jonas = login(client, "jonas", jonas_spec["password"], jonas_spec["device"])
        except httpx.HTTPStatusError:
            created = client.post(
                f"{POLICY}/_hoobird/v1/accounts",
                headers=_headers(oma["access_token"]),
                json={
                    "username": "jonas",
                    "password": jonas_spec["password"],
                    "role": "child",
                    "device_id": jonas_spec["device"],
                    "ed25519": JONAS_PLACEHOLDER_ED25519,
                },
            )
            created.raise_for_status()
            jonas = login(client, "jonas", jonas_spec["password"], jonas_spec["device"])
        code = client.post(
            f"{POLICY}/_hoobird/v1/children/{jonas['user_id']}/link-codes",
            headers=_headers(oma["access_token"]),
            json={},
        )
        if code.status_code == 200:
            redeemed = client.post(
                f"{POLICY}/_hoobird/v1/children/{jonas['user_id']}/parents",
                headers=_headers(linus["access_token"]),
                json={"code": code.json()["code"]},
            )
            if redeemed.status_code not in (200, 409):
                redeemed.raise_for_status()
        approved = client.post(
            f"{POLICY}/_hoobird/v1/children/{jonas['user_id']}/approvals",
            headers=_headers(oma["access_token"]),
            json={"contact_user_id": mara["user_id"]},
        )
        if approved.status_code not in (200, 409):
            approved.raise_for_status()
        room_id = asyncio.run(encrypted_hello(oma, mara))
        public = {
            "note": "Wegwerf-Konten nur für den lokalen Prototyp. Keine echten Personen.",
            "accounts": {
                name: {
                    "password": spec["password"],
                    "role": spec["role"],
                    "device_id": spec["device"],
                    "user_id": {
                        "oma": oma,
                        "linus": linus,
                        "mara": mara,
                        "fremder": fremder,
                        "jonas": jonas,
                    }[name]["user_id"],
                }
                for name, spec in ACCOUNTS.items()
            },
            "encrypted_room_id": room_id,
            "jonas_may_dm": ["oma", "linus", "mara"],
            "jonas_blocked_from": ["fremder"],
        }
        OUT.write_text(json.dumps(public, indent=2) + "\n", encoding="utf-8")
        print(f"wrote {OUT}")
        print(f"encrypted room {room_id}")


if __name__ == "__main__":
    main()
