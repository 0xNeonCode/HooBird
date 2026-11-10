# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026. Legal name of the copyright holder is not recorded in this repository.
"""Encrypted voice between two clients, and the receipts the owl depends on.

The Flutter owl is proven in the widget tests. This file proves the server
side those tests assume: an encrypted m.audio arrives as bytes, a public
m.read is visible to the other client, and m.read.private is not.
"""

from __future__ import annotations

import asyncio
import io
import os
import shutil
import tempfile
import uuid
import wave

from nio import (
    AsyncClient,
    MemoryDownloadResponse,
    RoomEncryptedAudio,
    RoomMessageAudio,
    RoomSendResponse,
    UploadResponse,
)
from nio.crypto.attachments import decrypt_attachment

from tests.test_e2ee import _create_encrypted_room, _login, _pump, _verify_known_devices


def _tone_wav() -> bytes:
    output = io.BytesIO()
    with wave.open(output, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(8000)
        handle.writeframes(b"\x10\x20" * 4000)
    return output.getvalue()


def test_encrypted_voice_and_public_versus_private_receipts(stack):
    asyncio.run(_scenario(stack))


async def _scenario(stack) -> None:
    left = stack.create(stack.admin["access_token"], role="adult")
    right = stack.create(stack.admin["access_token"], role="adult")
    third = stack.create(stack.admin["access_token"], role="adult")
    root = tempfile.mkdtemp(prefix="hoobird-receipts-")
    clients = []
    try:
        sender = await _login(left["user_id"], left["password"], "VOICELEFT01", f"{root}/left")
        reader = await _login(right["user_id"], right["password"], "VOICERIGHT1", f"{root}/right")
        group = await _login(third["user_id"], third["password"], "VOICEGROUP1", f"{root}/group")
        clients.extend([sender, reader, group])
        for client in clients:
            await _pump(client, _Sink(), 3)
            _verify_known_devices(client)

        room_id = await _create_encrypted_room(sender, [right["user_id"]], direct=True)
        assert (await reader.join(room_id)).transport_response.status == 200
        for client in (sender, reader):
            await _pump(client, _Sink(), 4)
            _verify_known_devices(client)

        tone = _tone_wav()
        upload, keys = await sender.upload(io.BytesIO(tone), filename="ton.wav", encrypt=True, filesize=len(tone))
        assert isinstance(upload, UploadResponse), upload
        assert keys
        encrypted_file = dict(keys)
        encrypted_file["url"] = upload.content_uri
        sent = await sender.room_send(
            room_id,
            "m.room.message",
            {
                "msgtype": "m.audio",
                "body": "Sprachnachricht",
                "info": {"mimetype": "audio/wav", "duration": 1000},
                "file": encrypted_file,
                "org.matrix.msc3245.voice": {},
            },
            ignore_unverified_devices=True,
        )
        assert isinstance(sent, RoomSendResponse), sent
        raw = stack.mx(
            "GET",
            f"/_matrix/client/v3/rooms/{_quote(room_id)}/event/{_quote(sent.event_id)}",
            sender.access_token,
        )
        assert raw.status_code == 200, raw.text
        wire = raw.json()
        assert wire["type"] == "m.room.encrypted"
        assert b"RIFF" not in raw.content

        event = await _audio_event(reader, room_id, "Sprachnachricht")
        assert isinstance(event, RoomEncryptedAudio), type(event)
        downloaded = await reader.download(event.url)
        assert isinstance(downloaded, MemoryDownloadResponse), downloaded
        clear = decrypt_attachment(downloaded.body, event.key["k"], event.hashes["sha256"], event.iv)
        assert clear == tone

        # Setting off: only the private receipt. The partner must not see m.read.
        _post_receipt(stack, reader.access_token, room_id, sent.event_id, "m.read.private")
        private_seen = await _receipts(sender, room_id, sent.event_id)
        assert (sent.event_id, "m.read", right["user_id"]) not in private_seen
        assert all(item[1] != "m.read.private" for item in private_seen)

        # Setting on: the public receipt is what the owl paints.
        _post_receipt(stack, reader.access_token, room_id, sent.event_id, "m.read")
        public_seen = await _receipts(sender, room_id, sent.event_id)
        assert (sent.event_id, "m.read", right["user_id"]) in public_seen

        # A group shows the owl only when every other joined member posted m.read.
        group_id = await _create_encrypted_room(sender, [right["user_id"], third["user_id"]])
        assert (await reader.join(group_id)).transport_response.status == 200
        assert (await group.join(group_id)).transport_response.status == 200
        for client in clients:
            await _pump(client, _Sink(), 4)
            _verify_known_devices(client)
        marker = f"Gruppe-{uuid.uuid4().hex}"
        group_sent = await sender.room_send(
            group_id,
            "m.room.message",
            {"msgtype": "m.text", "body": marker},
            ignore_unverified_devices=True,
        )
        assert isinstance(group_sent, RoomSendResponse), group_sent
        await _pump(reader, _Sink(), 4)
        await _pump(group, _Sink(), 4)
        # Ephemeral m.receipt events are deltas. Synapse does not repeat a
        # member who already appeared, so the client unions the windows.
        _post_receipt(stack, reader.access_token, group_id, group_sent.event_id, "m.read")
        one = await _receipts(sender, group_id, group_sent.event_id)
        readers = {user for event_id, kind, user in one if event_id == group_sent.event_id and kind == "m.read"}
        assert readers == {right["user_id"]}
        others = {right["user_id"], third["user_id"]}
        _post_receipt(stack, group.access_token, group_id, group_sent.event_id, "m.read")
        both = await _receipts(sender, group_id, group_sent.event_id)
        readers |= {user for event_id, kind, user in both if event_id == group_sent.event_id and kind == "m.read"}
        assert readers == others
    finally:
        for client in clients:
            await client.close()
        shutil.rmtree(root, ignore_errors=True)


class _Sink:
    def add(self, sync) -> None:
        return None


def _quote(value: str) -> str:
    from urllib.parse import quote

    return quote(value, safe="")


async def _audio_event(client: AsyncClient, room_id: str, body: str):
    for _ in range(8):
        sync = await client.sync(timeout=2000)
        assert getattr(sync, "next_batch", None), sync
        rooms = getattr(sync, "rooms", None)
        if rooms is None or room_id not in rooms.join:
            continue
        for event in rooms.join[room_id].timeline.events:
            if isinstance(event, (RoomEncryptedAudio, RoomMessageAudio)) and event.body == body:
                return event
        if client.olm:
            try:
                await client.keys_query()
            except Exception:
                pass
    raise AssertionError("Sprachnachricht nicht entschlüsselt")


def _post_receipt(stack, token: str, room_id: str, event_id: str, receipt_type: str) -> None:
    response = stack.mx(
        "POST",
        f"/_matrix/client/v3/rooms/{_quote(room_id)}/receipt/{receipt_type}/{_quote(event_id)}",
        token,
        {},
    )
    assert response.status_code == 200, response.text


async def _receipts(client: AsyncClient, room_id: str, event_id: str) -> set[tuple[str, str, str]]:
    """Receipts that arrive after this call. A full sync omits them on this Synapse."""
    import aiohttp

    since = client.next_batch
    found: set[tuple[str, str, str]] = set()
    headers = {"Authorization": f"Bearer {client.access_token}"}
    seen_public = False
    async with aiohttp.ClientSession() as session:
        for _ in range(8):
            url = f"{client.homeserver}/_matrix/client/v3/sync?timeout=2000"
            if since:
                url += f"&since={_quote(since)}"
            async with session.get(url, headers=headers) as response:
                body = await response.json()
                assert response.status == 200, body
            since = body.get("next_batch", since)
            room = body.get("rooms", {}).get("join", {}).get(room_id, {})
            for event in room.get("ephemeral", {}).get("events", []):
                if event.get("type") != "m.receipt":
                    continue
                for seen_id, kinds in event.get("content", {}).items():
                    if seen_id != event_id:
                        continue
                    for kind, users in kinds.items():
                        for user_id in users:
                            found.add((seen_id, kind, user_id))
            public = any(item[0] == event_id and item[1] == "m.read" for item in found)
            if public and seen_public:
                break
            seen_public = public
    client.next_batch = since
    return found
