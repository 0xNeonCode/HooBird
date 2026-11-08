# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026. Legal name of the copyright holder is not recorded in this repository.
"""Real Megolm sessions through matrix-nio 0.26, which uses vodozemac.

This is a generic client, not the Flutter SDK. It does not exercise
cross-signing or server-side key backup; matrix-nio 0.26 has neither.
"""

from __future__ import annotations

import asyncio
import io
import os
import shutil
import tempfile
import uuid
import wave
from urllib.parse import quote

import psycopg2
import pytest
from nio import (
    AsyncClient,
    AsyncClientConfig,
    LocalProtocolError,
    LoginResponse,
    RoomCreateResponse,
    RoomMessageText,
    RoomSendResponse,
    UploadResponse,
)
from piexif import GPSIFD, ImageIFD, dump, load

from media_prep import strip_jpeg
from tests.conftest import SERVER, localpart

from PIL import Image


def _db_has(snippet: str) -> bool:
    conn = psycopg2.connect("postgresql://synapse:synapse@127.0.0.1:15432/synapse")
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT 1 FROM event_json WHERE json LIKE %s LIMIT 1",
                (f"%{snippet}%",),
            )
            return cur.fetchone() is not None
    finally:
        conn.close()


async def _login(user_id: str, password: str, device_id: str, store: str) -> AsyncClient:
    os.makedirs(store, exist_ok=True)
    client = AsyncClient(
        SERVER,
        user_id,
        device_id=device_id,
        store_path=store,
        config=AsyncClientConfig(encryption_enabled=True, store_sync_tokens=True),
    )
    response = await client.login(password, device_name=device_id)
    assert isinstance(response, LoginResponse), response
    return client


class SeenTexts:
    def __init__(self) -> None:
        self.bodies: dict[str, list[str]] = {}

    def add(self, sync) -> None:
        rooms = getattr(sync, "rooms", None)
        if rooms is None:
            return
        for room_id, info in rooms.join.items():
            found = self.bodies.setdefault(room_id, [])
            for event in info.timeline.events:
                if isinstance(event, RoomMessageText) and event.body not in found:
                    found.append(event.body)


async def _pump(client: AsyncClient, seen: SeenTexts, rounds: int = 4) -> None:
    for _ in range(rounds):
        sync = await client.sync(timeout=1000)
        assert getattr(sync, "next_batch", None), sync
        seen.add(sync)
        if client.olm:
            for action in (client.keys_upload, client.keys_query):
                try:
                    await action()
                except LocalProtocolError:
                    pass


def _verify_known_devices(client: AsyncClient) -> None:
    assert client.olm
    for user_id in list(client.device_store.users):
        for device in client.device_store.active_user_devices(user_id):
            client.verify_device(device)


async def _create_encrypted_room(client: AsyncClient, invites: list[str], direct: bool = False) -> str:
    response = await client.room_create(
        name="HooBird",
        federate=False,
        is_direct=direct,
        invite=invites,
        initial_state=[
            {
                "type": "m.room.encryption",
                "state_key": "",
                "content": {"algorithm": "m.megolm.v1.aes-sha2"},
            }
        ],
    )
    assert isinstance(response, RoomCreateResponse), response
    return response.room_id


def _jpeg_with_gps() -> bytes:
    image = Image.new("RGB", (12, 12), (30, 90, 40))
    output = io.BytesIO()
    exif = {
        "0th": {ImageIFD.ImageDescription: b"GPSLAT-48.12345"},
        "GPS": {GPSIFD.GPSLatitudeRef: b"N", GPSIFD.GPSLatitude: ((48, 1), (7, 1), (0, 1))},
    }
    image.save(output, format="JPEG", exif=dump(exif))
    return output.getvalue()


def _wav_with_marker() -> bytes:
    output = io.BytesIO()
    with wave.open(output, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(8000)
        handle.writeframes(b"VOICE-MARKER-1847" + b"\x00\x10" * 200)
    return output.getvalue()


async def _download(token: str, content_uri: str) -> bytes:
    assert content_uri.startswith("mxc://")
    server_name, media_id = content_uri[6:].split("/", 1)
    import httpx

    async with httpx.AsyncClient(timeout=30) as http:
        for path in (
            f"/_matrix/client/v1/media/download/{server_name}/{media_id}",
            f"/_matrix/media/v3/download/{server_name}/{media_id}",
        ):
            response = await http.get(
                f"{SERVER}{path}",
                headers={"Authorization": f"Bearer {token}"},
            )
            if response.status_code == 200:
                return response.content
        raise AssertionError(response.status_code)


def test_encrypted_text_group_media_and_second_device(stack):
    asyncio.run(_scenario(stack))


async def _scenario(stack) -> None:
    parent = stack.create(stack.admin["access_token"], role="parent")
    child = stack.create(
        stack.login(parent["username"], parent["password"], "ELTERNDEV01")["access_token"],
        role="child",
        device_id="KINDGERAET01",
    )
    # The create call above consumed a login only for its token. Authorize the
    # parent's second device explicitly; parents are not device-limited.
    adult = stack.create(stack.admin["access_token"], role="adult")
    parent_token = stack.login(parent["username"], parent["password"], "ELTERNHTTP")["access_token"]
    approved = stack.client.post(
        f"http://127.0.0.1:18018/_hoobird/v1/children/{quote(child['user_id'], safe='')}/approvals",
        json={"contact_user_id": adult["user_id"]},
        headers=stack.h(parent_token),
    )
    assert approved.status_code == 200, approved.text
    root = tempfile.mkdtemp(prefix="hoobird-e2ee-")
    clients = []
    seen_by: dict[int, SeenTexts] = {}

    def seen_for(client: AsyncClient) -> SeenTexts:
        return seen_by.setdefault(id(client), SeenTexts())

    try:
        parent_a = await _login(parent["user_id"], parent["password"], "ELTERNDEV01", f"{root}/pa")
        parent_b = await _login(parent["user_id"], parent["password"], "ELTERNDEV02", f"{root}/pb")
        child_c = await _login(child["user_id"], child["password"], "KINDGERAET01", f"{root}/ch")
        adult_c = await _login(adult["user_id"], adult["password"], "ERWACHSEN01", f"{root}/ad")
        clients.extend([parent_a, parent_b, child_c, adult_c])
        for client in clients:
            await _pump(client, seen_for(client))
            _verify_known_devices(client)

        room_id = await _create_encrypted_room(
            parent_a, [child["user_id"], adult["user_id"]]
        )
        assert (await child_c.join(room_id)).transport_response.status == 200
        assert (await adult_c.join(room_id)).transport_response.status == 200
        for client in (parent_a, child_c, adult_c):
            await _pump(client, seen_for(client), 5)
            _verify_known_devices(client)

        marker = f"Spaziergang-Marker-{uuid.uuid4().hex}"
        sent = await parent_a.room_send(
            room_id,
            "m.room.message",
            {"msgtype": "m.text", "body": marker},
            ignore_unverified_devices=True,
        )
        assert isinstance(sent, RoomSendResponse), sent
        raw = stack.mx(
            "GET",
            f"/_matrix/client/v3/rooms/{quote(room_id, safe='')}/event/{quote(sent.event_id, safe='')}",
            parent_token,
        )
        assert raw.status_code == 200, raw.text
        event = raw.json()
        assert event["type"] == "m.room.encrypted"
        assert event["content"]["algorithm"] == "m.megolm.v1.aes-sha2"
        assert marker not in str(event["content"])
        assert _db_has(marker) is False

        for client in (parent_a, child_c, adult_c):
            await _pump(client, seen_for(client), 6)
        assert marker in seen_for(parent_a).bodies.get(room_id, [])
        assert marker in seen_for(child_c).bodies.get(room_id, [])
        assert marker in seen_for(adult_c).bodies.get(room_id, [])

        # Same account, second device: manual device trust in this test client,
        # not cross-signing. A store without the Megolm session must not show
        # the plaintext from its own sync.
        fresh = await _login(parent["user_id"], parent["password"], "ELTERNDEV03", f"{root}/fresh")
        clients.append(fresh)
        await _pump(fresh, seen_for(fresh), 4)
        assert marker not in seen_for(fresh).bodies.get(room_id, [])
        _verify_known_devices(parent_a)
        _verify_known_devices(fresh)
        await _pump(parent_a, seen_for(parent_a), 2)
        follow = f"Folge-Marker-{uuid.uuid4().hex}"
        follow_sent = await parent_a.room_send(
            room_id,
            "m.room.message",
            {"msgtype": "m.text", "body": follow},
            ignore_unverified_devices=True,
        )
        assert isinstance(follow_sent, RoomSendResponse), follow_sent
        await _pump(fresh, seen_for(fresh), 6)
        await _pump(parent_b, seen_for(parent_b), 6)
        assert follow in seen_for(fresh).bodies.get(room_id, []) or follow in seen_for(parent_b).bodies.get(room_id, [])

        jpeg = strip_jpeg(_jpeg_with_gps())
        assert b"GPSLAT-48.12345" not in jpeg
        assert not load(jpeg).get("GPS")
        upload, keys = await parent_a.upload(
            io.BytesIO(jpeg),
            filename="wald.jpg",
            encrypt=True,
            filesize=len(jpeg),
        )
        assert isinstance(upload, UploadResponse), upload
        assert keys
        image_sent = await parent_a.room_send(
            room_id,
            "m.room.message",
            {"msgtype": "m.image", "body": "wald.jpg", "file": keys},
            ignore_unverified_devices=True,
        )
        assert isinstance(image_sent, RoomSendResponse), image_sent
        stored = await _download(parent_a.access_token, upload.content_uri)
        assert not stored.startswith(b"\xff\xd8\xff")
        assert b"GPSLAT-48.12345" not in stored

        voice = _wav_with_marker()
        voice_upload, voice_keys = await parent_a.upload(
            io.BytesIO(voice),
            filename="ton.wav",
            encrypt=True,
            filesize=len(voice),
        )
        assert isinstance(voice_upload, UploadResponse), voice_upload
        voice_sent = await parent_a.room_send(
            room_id,
            "m.room.message",
            {"msgtype": "m.audio", "body": "ton.wav", "file": voice_keys},
            ignore_unverified_devices=True,
        )
        assert isinstance(voice_sent, RoomSendResponse), voice_sent
        stored_voice = await _download(parent_a.access_token, voice_upload.content_uri)
        assert not stored_voice.startswith(b"RIFF")
        assert b"VOICE-MARKER-1847" not in stored_voice
        assert _db_has("VOICE-MARKER-1847") is False
        assert _db_has("GPSLAT-48.12345") is False

        # A newly approved member does not receive the previous event from the server.
        extra = stack.create(stack.admin["access_token"], role="adult")
        assert stack.client.post(
            f"http://127.0.0.1:18018/_hoobird/v1/children/{quote(child['user_id'], safe='')}/approvals",
            json={"contact_user_id": extra["user_id"]},
            headers=stack.h(parent_token),
        ).status_code == 200
        extra_client = await _login(extra["user_id"], extra["password"], "NEU01", f"{root}/extra")
        clients.append(extra_client)
        # Controlled invite: join_rule is invite, so a bare join is refused.
        # Approval makes the invite legal; history_visibility=joined still hides
        # events from before this membership.
        invited = stack.mx(
            "POST",
            f"/_matrix/client/v3/rooms/{quote(room_id, safe='')}/invite",
            parent_a.access_token,
            {"user_id": extra["user_id"]},
        )
        assert invited.status_code == 200, invited.text
        assert (await extra_client.join(room_id)).transport_response.status == 200
        await _pump(extra_client, seen_for(extra_client), 3)
        history = stack.mx(
            "GET",
            f"/_matrix/client/v3/rooms/{quote(room_id, safe='')}/messages?dir=b&limit=50",
            extra_client.access_token,
        )
        assert history.status_code == 200, history.text
        assert sent.event_id not in history.text
    finally:
        for client in clients:
            await client.close()
        shutil.rmtree(root, ignore_errors=True)


def test_nio_has_no_key_backup_api():
    """Do not pretend recovery was tested through matrix-nio."""

    import nio

    assert not hasattr(nio.AsyncClient, "restore_key_backup")
    assert not hasattr(nio.AsyncClient, "load_all_keys")
