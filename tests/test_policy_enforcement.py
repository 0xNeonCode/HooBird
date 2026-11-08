# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026. Legal name of the copyright holder is not recorded in this repository.
"""Server enforcement against raw HTTP, not the Flutter client.

These tests are integration tests. They fail if the compose stack is down.
A passing result is not a security audit.
"""

from __future__ import annotations

import secrets
import threading
import uuid
from urllib.parse import quote

from tests.conftest import POLICY, SERVER, localpart


def _detail(response) -> dict:
    body = response.json()
    return body.get("detail", body)


def test_public_registration_is_disabled(stack):
    response = stack.client.post(
        f"{SERVER}/_matrix/client/v3/register",
        json={
            "username": f"nope{uuid.uuid4().hex[:6]}",
            "password": secrets.token_urlsafe(18),
            "auth": {"type": "m.login.dummy"},
        },
    )
    assert response.status_code == 403
    assert response.json()["errcode"] == "M_FORBIDDEN"


def test_federation_is_closed(stack):
    version = stack.client.get(f"{SERVER}/_matrix/federation/v1/version")
    assert version.status_code != 200
    whitelist = stack.mx(
        "GET",
        "/_synapse/client/v1/config/federation_whitelist",
        stack.admin["access_token"],
    )
    assert whitelist.status_code == 200, whitelist.text
    body = whitelist.json()
    assert body["whitelist_enabled"] is True
    assert body["whitelist"] == []
    joined = stack.mx(
        "POST",
        f"/_matrix/client/v3/join/{quote('#matrix:matrix.org', safe='')}",
        stack.admin["access_token"],
        {},
    )
    assert joined.status_code >= 400


def test_child_cannot_create_an_adult_and_mxid_stays_opaque(stack):
    parent = stack.create(stack.admin["access_token"], role="parent")
    parent_session = stack.login(parent["username"], parent["password"], "PARENTDEV01")
    denied = stack.client.post(
        f"{POLICY}/_hoobird/v1/accounts",
        json={"username": f"x{uuid.uuid4().hex[:8]}", "password": secrets.token_urlsafe(18), "role": "adult"},
        headers=stack.h(parent_session["access_token"]),
    )
    assert denied.status_code == 403
    assert _detail(denied)["hoobird_code"] == "bootstrap_required"
    child = stack.create(
        parent_session["access_token"],
        role="child",
        device_id="KINDGERAET01",
        email="linus.example@invalid.test",
    )
    assert child["user_id"].startswith("@hb")
    assert child["user_id"].endswith(":hoobird.local")
    assert child["username"] not in child["user_id"]
    assert "dev_only_email_token" in child
    child_session = stack.login(child["username"], child["password"], "KINDGERAET01")
    also_denied = stack.client.post(
        f"{POLICY}/_hoobird/v1/accounts",
        json={"username": f"y{uuid.uuid4().hex[:8]}", "password": secrets.token_urlsafe(18), "role": "adult"},
        headers=stack.h(child_session["access_token"]),
    )
    assert also_denied.status_code == 403
    renamed = f"neu{uuid.uuid4().hex[:8]}"
    changed = stack.client.patch(
        f"{POLICY}/_hoobird/v1/accounts/{quote(child['user_id'], safe='')}/username",
        json={"username": renamed},
        headers=stack.h(parent_session["access_token"]),
    )
    assert changed.status_code == 200, changed.text
    assert changed.json()["user_id"] == child["user_id"]
    assert changed.json()["mxid_unchanged"] is True
    old_login = stack.client.post(
        f"{POLICY}/_hoobird/v1/login",
        json={"username": child["username"], "password": child["password"], "device_id": "KINDGERAET01"},
    )
    assert old_login.status_code == 401
    new_login = stack.login(renamed, child["password"], "KINDGERAET01")
    assert new_login["user_id"] == child["user_id"]
    confirmed = stack.client.post(
        f"{POLICY}/_hoobird/v1/accounts/{quote(child['user_id'], safe='')}/email/confirm",
        json={"token": child["dev_only_email_token"]},
    )
    assert confirmed.status_code == 200
    assert confirmed.json()["does_not_prove"] == ["legal_identity", "age", "guardianship"]
    friendly = stack.raw_login(renamed, child["password"], "KINDGERAET01")
    assert friendly.status_code != 200


def test_generic_client_dm_group_block_and_reapproval(stack):
    parent_a = stack.create(stack.admin["access_token"], role="parent")
    parent_b = stack.create(stack.admin["access_token"], role="parent")
    session_a = stack.login(parent_a["username"], parent_a["password"], "ELTERNDEV01")
    child = stack.create(session_a["access_token"], role="child", device_id="KINDGERAET01")
    code = stack.client.post(
        f"{POLICY}/_hoobird/v1/children/{quote(child['user_id'], safe='')}/link-codes",
        json={},
        headers=stack.h(session_a["access_token"]),
    )
    assert code.status_code == 200, code.text
    assert code.json()["qr_implemented"] is False
    session_b = stack.login(parent_b["username"], parent_b["password"], "ELTERNDEV02")
    linked = stack.client.post(
        f"{POLICY}/_hoobird/v1/children/{quote(child['user_id'], safe='')}/parents",
        json={"code": code.json()["code"]},
        headers=stack.h(session_b["access_token"]),
    )
    assert linked.status_code == 200, linked.text
    assert linked.json()["guardianship_proven"] is False
    third = stack.create(stack.admin["access_token"], role="parent")
    session_c = stack.login(third["username"], third["password"], "ELTERNDEV03")
    code_b = stack.client.post(
        f"{POLICY}/_hoobird/v1/children/{quote(child['user_id'], safe='')}/link-codes",
        json={},
        headers=stack.h(session_a["access_token"]),
    )
    overflow = stack.client.post(
        f"{POLICY}/_hoobird/v1/children/{quote(child['user_id'], safe='')}/parents",
        json={"code": code_b.json()["code"]},
        headers=stack.h(session_c["access_token"]),
    )
    assert overflow.status_code == 409
    adult = stack.create(stack.admin["access_token"], role="adult")
    stranger = stack.create(stack.admin["access_token"], role="adult")
    child_session = stack.login(child["username"], child["password"], "KINDGERAET01")
    adult_session = stack.login(adult["username"], adult["password"], "ERWACHSEN01")
    stranger_session = stack.login(stranger["username"], stranger["password"], "FREMDER01")

    denied = stack.create_room(child_session["access_token"], [stranger["user_id"]], direct=True)
    assert denied.status_code == 403, denied.text
    allowed = stack.create_room(child_session["access_token"], [parent_a["user_id"]], direct=True)
    assert allowed.status_code == 200, allowed.text
    parent_room = allowed.json()["room_id"]
    assert stack.join(session_a["access_token"], parent_room).status_code == 200
    plain = stack.send_plain(child_session["access_token"], parent_room, "Klartext darf nicht ankommen")
    assert plain.status_code == 403, plain.text
    encrypted = stack.send_fake_encrypted(child_session["access_token"], parent_room)
    assert encrypted.status_code == 200, encrypted.text

    approved = stack.client.post(
        f"{POLICY}/_hoobird/v1/children/{quote(child['user_id'], safe='')}/approvals",
        json={"contact_user_id": adult["user_id"]},
        headers=stack.h(session_a["access_token"]),
    )
    assert approved.json()["effective"] is True
    group = stack.create_room(
        adult_session["access_token"],
        [child["user_id"], parent_a["user_id"]],
    )
    assert group.status_code == 200, group.text
    group_id = group.json()["room_id"]
    assert stack.join(session_a["access_token"], group_id).status_code == 200
    assert stack.join(child_session["access_token"], group_id).status_code == 200
    bad_invite = stack.invite(adult_session["access_token"], group_id, stranger["user_id"])
    assert bad_invite.status_code == 403, bad_invite.text
    stranger_room = stack.create_room(stranger_session["access_token"], [adult["user_id"]])
    assert stranger_room.status_code == 200, stranger_room.text
    child_into_bad = stack.invite(
        stranger_session["access_token"], stranger_room.json()["room_id"], child["user_id"]
    )
    assert child_into_bad.status_code == 403, child_into_bad.text

    blocked = stack.client.post(
        f"{POLICY}/_hoobird/v1/children/{quote(child['user_id'], safe='')}/blocks",
        json={"contact_user_id": adult["user_id"]},
        headers=stack.h(session_b["access_token"]),
    )
    assert blocked.status_code == 200, blocked.text
    reapproved = stack.client.post(
        f"{POLICY}/_hoobird/v1/children/{quote(child['user_id'], safe='')}/approvals",
        json={"contact_user_id": adult["user_id"]},
        headers=stack.h(session_a["access_token"]),
    )
    assert reapproved.json()["effective"] is False
    assert reapproved.json()["block_overrides_approval"] is True
    lift_by_other = stack.client.delete(
        f"{POLICY}/_hoobird/v1/children/{quote(child['user_id'], safe='')}/blocks/{quote(adult['user_id'], safe='')}",
        headers=stack.h(session_a["access_token"]),
    )
    assert lift_by_other.status_code == 403
    assert _detail(lift_by_other)["hoobird_code"] == "block_not_owner"
    after_block = stack.invite(child_session["access_token"], parent_room, adult["user_id"])
    assert after_block.status_code == 403, after_block.text
    late_send = stack.send_fake_encrypted(child_session["access_token"], group_id)
    assert late_send.status_code == 403, late_send.text
    lifted = stack.client.delete(
        f"{POLICY}/_hoobird/v1/children/{quote(child['user_id'], safe='')}/blocks/{quote(adult['user_id'], safe='')}",
        headers=stack.h(session_b["access_token"]),
    )
    assert lifted.json()["effective"] is True
    revoked = stack.client.delete(
        f"{POLICY}/_hoobird/v1/children/{quote(child['user_id'], safe='')}/approvals/{quote(adult['user_id'], safe='')}",
        headers=stack.h(session_a["access_token"]),
    )
    assert revoked.json()["effective"] is False
    after_revoke = stack.create_room(child_session["access_token"], [adult["user_id"]], direct=True)
    assert after_revoke.status_code == 403

    sibling = stack.create(session_a["access_token"], role="child", device_id="KINDGERAET02")
    one_sided = stack.client.post(
        f"{POLICY}/_hoobird/v1/children/{quote(child['user_id'], safe='')}/approvals",
        json={"contact_user_id": sibling["user_id"]},
        headers=stack.h(session_a["access_token"]),
    )
    assert one_sided.status_code == 200
    only_one = stack.create_room(child_session["access_token"], [sibling["user_id"], parent_a["user_id"]])
    assert only_one.status_code == 403, only_one.text
    stack.client.post(
        f"{POLICY}/_hoobird/v1/children/{quote(sibling['user_id'], safe='')}/approvals",
        json={"contact_user_id": child["user_id"]},
        headers=stack.h(session_a["access_token"]),
    )
    both = stack.create_room(child_session["access_token"], [sibling["user_id"], parent_a["user_id"]])
    assert both.status_code == 200, both.text

    # A parent is not a member of a room just because they are linked.
    private = stack.create_room(adult_session["access_token"], [])
    assert private.status_code == 200, private.text
    uninvited = stack.join(session_a["access_token"], private.json()["room_id"])
    assert uninvited.status_code == 403


def test_block_versus_invite_race_then_fail_closed(stack):
    parent_a = stack.create(stack.admin["access_token"], role="parent")
    parent_b = stack.create(stack.admin["access_token"], role="parent")
    session_a = stack.login(parent_a["username"], parent_a["password"], "ELTERNDEV01")
    child = stack.create(session_a["access_token"], role="child", device_id="KINDGERAET01")
    code = stack.client.post(
        f"{POLICY}/_hoobird/v1/children/{quote(child['user_id'], safe='')}/link-codes",
        json={},
        headers=stack.h(session_a["access_token"]),
    ).json()["code"]
    session_b = stack.login(parent_b["username"], parent_b["password"], "ELTERNDEV02")
    assert stack.client.post(
        f"{POLICY}/_hoobird/v1/children/{quote(child['user_id'], safe='')}/parents",
        json={"code": code},
        headers=stack.h(session_b["access_token"]),
    ).status_code == 200
    adult = stack.create(stack.admin["access_token"], role="adult")
    stack.client.post(
        f"{POLICY}/_hoobird/v1/children/{quote(child['user_id'], safe='')}/approvals",
        json={"contact_user_id": adult["user_id"]},
        headers=stack.h(session_a["access_token"]),
    )
    child_session = stack.login(child["username"], child["password"], "KINDGERAET01")
    room = stack.create_room(child_session["access_token"], [parent_a["user_id"]])
    assert room.status_code == 200, room.text
    room_id = room.json()["room_id"]
    assert stack.join(session_a["access_token"], room_id).status_code == 200
    barrier = threading.Barrier(2)
    results = {}

    def invite():
        barrier.wait(timeout=5)
        results["invite"] = stack.invite(child_session["access_token"], room_id, adult["user_id"])

    def block():
        barrier.wait(timeout=5)
        results["block"] = stack.client.post(
            f"{POLICY}/_hoobird/v1/children/{quote(child['user_id'], safe='')}/blocks",
            json={"contact_user_id": adult["user_id"]},
            headers=stack.h(session_b["access_token"]),
        )

    threads = [threading.Thread(target=invite), threading.Thread(target=block)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join(timeout=20)
    assert results["block"].status_code == 200, results["block"].text
    repair = stack.client.post(
        f"{POLICY}/_hoobird/v1/children/{quote(child['user_id'], safe='')}/blocks/{quote(adult['user_id'], safe='')}/reconcile",
        headers=stack.h(session_b["access_token"]),
    )
    assert repair.status_code == 200, repair.text
    joined = stack.mx(
        "GET",
        f"/_synapse/admin/v1/users/{quote(adult['user_id'], safe='')}/joined_rooms",
        stack.admin["access_token"],
    )
    assert joined.status_code == 200, joined.text
    assert room_id not in joined.json().get("joined_rooms", [])
    members = stack.mx(
        "GET",
        f"/_matrix/client/v3/rooms/{quote(room_id, safe='')}/members",
        child_session["access_token"],
    )
    assert members.status_code == 200, members.text
    for chunk in members.json().get("chunk", []):
        if chunk.get("state_key") == adult["user_id"]:
            assert chunk.get("content", {}).get("membership") not in ("join", "invite")
    # The blocked contact is no longer invite or join in this child-created
    # room. A message there is not a pair with that contact. A room where
    # the child cannot kick still rejects content; that is the other test.
    later = stack.send_fake_encrypted(child_session["access_token"], room_id)
    assert later.status_code == 200, later.text
    again = stack.invite(child_session["access_token"], room_id, adult["user_id"])
    assert again.status_code == 403
    reapproval = stack.client.post(
        f"{POLICY}/_hoobird/v1/children/{quote(child['user_id'], safe='')}/approvals",
        json={"contact_user_id": adult["user_id"]},
        headers=stack.h(session_a["access_token"]),
    )
    assert reapproval.json()["effective"] is False


def test_child_devices_are_rejected_for_generic_clients(stack):
    parent = stack.create(stack.admin["access_token"], role="parent")
    session = stack.login(parent["username"], parent["password"], "ELTERNDEV01")
    child = stack.create(session["access_token"], role="child", device_id="KINDGERAET01")
    part = localpart(child["user_id"])
    missing = stack.raw_login(part, child["password"], None)
    assert missing.status_code == 403, missing.text
    unknown = stack.raw_login(part, child["password"], "NEUESGERAET9")
    assert unknown.status_code == 403, unknown.text
    devices = stack.mx(
        "GET",
        f"/_synapse/admin/v2/users/{quote(child['user_id'], safe='')}/devices",
        stack.admin["access_token"],
    )
    assert devices.status_code == 200, devices.text
    assert all(item["device_id"] != "NEUESGERAET9" for item in devices.json().get("devices", []))
    ok = stack.raw_login(part, child["password"], "KINDGERAET01")
    assert ok.status_code == 200, ok.text
    token = ok.json()["access_token"]
    from tests.device_keys import DeviceKey

    mismatched = DeviceKey("KINDGERAET01")
    rejected = stack.mx(
        "POST",
        "/_matrix/client/v3/keys/upload",
        token,
        {"device_keys": mismatched.signed_device_keys(child["user_id"])},
    )
    assert rejected.status_code == 403, rejected.text
    one_time = stack.mx(
        "POST",
        "/_matrix/client/v3/keys/upload",
        token,
        {"one_time_keys": {"signed_curve25519:AAAA": {"key": "abc", "signatures": {}}}},
    )
    assert one_time.status_code == 403, one_time.text
    approved_key = DeviceKey("KINDGERAET01")
    # The account was created with a random approved key that has no private
    # half in this test. Replace that row by revoking and storing this key.
    assert stack.client.delete(
        f"{POLICY}/_hoobird/v1/children/{quote(child['user_id'], safe='')}/devices/KINDGERAET01",
        headers=stack.h(session["access_token"]),
    ).status_code == 200
    stored = stack.client.post(
        f"{POLICY}/_hoobird/v1/children/{quote(child['user_id'], safe='')}/devices",
        json={"device_id": "KINDGERAET01", "ed25519": approved_key.ed25519},
        headers=stack.h(session["access_token"]),
    )
    assert stored.status_code == 200, stored.text
    assert stored.json()["binds_key_fingerprint"] is True
    again_login = stack.raw_login(part, child["password"], "KINDGERAET01")
    assert again_login.status_code == 200, again_login.text
    token = again_login.json()["access_token"]
    upload = stack.mx(
        "POST",
        "/_matrix/client/v3/keys/upload",
        token,
        {"device_keys": approved_key.signed_device_keys(child["user_id"])},
    )
    assert upload.status_code == 200, upload.text
    swapped = DeviceKey("KINDGERAET01")
    replay = stack.mx(
        "POST",
        "/_matrix/client/v3/keys/upload",
        token,
        {"device_keys": swapped.signed_device_keys(child["user_id"])},
    )
    assert replay.status_code == 403, replay.text
    revoked = stack.client.delete(
        f"{POLICY}/_hoobird/v1/children/{quote(child['user_id'], safe='')}/devices/KINDGERAET01",
        headers=stack.h(session["access_token"]),
    )
    assert revoked.status_code == 200, revoked.text
    stale = stack.mx("POST", "/_matrix/client/v3/keys/upload", token, {"device_keys": {}})
    assert stale.status_code == 401, stale.text
    again = stack.raw_login(part, child["password"], "KINDGERAET01")
    assert again.status_code == 403
    other_parent = stack.create(stack.admin["access_token"], role="parent")
    other_session = stack.login(other_parent["username"], other_parent["password"], "ELTERNDEV09")
    code = stack.client.post(
        f"{POLICY}/_hoobird/v1/children/{quote(child['user_id'], safe='')}/link-codes",
        json={},
        headers=stack.h(session["access_token"]),
    ).json()["code"]
    assert stack.client.post(
        f"{POLICY}/_hoobird/v1/children/{quote(child['user_id'], safe='')}/parents",
        json={"code": code},
        headers=stack.h(other_session["access_token"]),
    ).status_code == 200
    from tests.device_keys import random_ed25519

    second_key = random_ed25519()
    missing_key = stack.client.post(
        f"{POLICY}/_hoobird/v1/children/{quote(child['user_id'], safe='')}/devices",
        json={"device_id": "KINDGERAET02"},
        headers=stack.h(other_session["access_token"]),
    )
    assert missing_key.status_code == 422 or missing_key.status_code == 400
    second = stack.client.post(
        f"{POLICY}/_hoobird/v1/children/{quote(child['user_id'], safe='')}/devices",
        json={"device_id": "KINDGERAET02", "ed25519": second_key},
        headers=stack.h(other_session["access_token"]),
    )
    assert second.status_code == 200, second.text
    assert second.json()["binds_key_fingerprint"] is True
    conflict = stack.client.post(
        f"{POLICY}/_hoobird/v1/children/{quote(child['user_id'], safe='')}/devices",
        json={"device_id": "KINDGERAET02", "ed25519": random_ed25519()},
        headers=stack.h(session["access_token"]),
    )
    assert conflict.status_code == 409, conflict.text
    assert stack.raw_login(part, child["password"], "KINDGERAET02").status_code == 200


def test_password_reset_keeps_mxid_and_account_data_without_returning_keys(stack):
    parent = stack.create(stack.admin["access_token"], role="parent")
    session = stack.login(parent["username"], parent["password"], "ELTERNDEV01")
    child = stack.create(session["access_token"], role="child", device_id="KINDGERAET01")
    child_session = stack.login(child["username"], child["password"], "KINDGERAET01")
    marker = {"probe": "konto-daten-bleiben", "keys": False}
    stored = stack.mx(
        "PUT",
        f"/_matrix/client/v3/user/{quote(child['user_id'], safe='')}/account_data/im.hoobird.probe",
        child_session["access_token"],
        marker,
    )
    assert stored.status_code == 200, stored.text
    reset_password = secrets.token_urlsafe(18)
    reset = stack.client.post(
        f"{POLICY}/_hoobird/v1/accounts/{quote(child['user_id'], safe='')}/reset-password",
        json={"new_password": reset_password},
        headers=stack.h(session["access_token"]),
    )
    assert reset.status_code == 200, reset.text
    body = reset.json()
    assert body["user_id"] == child["user_id"]
    assert body["recovery_key_returned"] is False
    assert body["cross_signing_reset"] is False
    assert body["message_keys_returned"] is False
    stale = stack.mx("GET", "/_matrix/client/v3/sync", child_session["access_token"])
    assert stale.status_code == 401
    fresh = stack.login(child["username"], reset_password, "KINDGERAET01")
    assert fresh["user_id"] == child["user_id"]
    probe = stack.mx(
        "GET",
        f"/_matrix/client/v3/user/{quote(child['user_id'], safe='')}/account_data/im.hoobird.probe",
        fresh["access_token"],
    )
    assert probe.status_code == 200, probe.text
    assert probe.json()["probe"] == "konto-daten-bleiben"
    parent_reset = stack.client.post(
        f"{POLICY}/_hoobird/v1/accounts/{quote(parent['user_id'], safe='')}/reset-password",
        json={"new_password": reset_password},
        headers=stack.h(session["access_token"]),
    )
    assert parent_reset.status_code == 404


def test_plaintext_media_is_rejected_and_room_policy_sticks(stack):
    parent = stack.create(stack.admin["access_token"], role="parent")
    session = stack.login(parent["username"], parent["password"], "ELTERNDEV01")
    jpeg = b"\xff\xd8\xff\xe0" + b"\x00" * 32
    rejected = stack.client.post(
        f"{SERVER}/_matrix/media/v3/upload?filename=bild.jpg",
        headers={**stack.h(session["access_token"]), "Content-Type": "image/jpeg"},
        content=jpeg,
    )
    # Synapse turns a media spam-checker rejection into HTTP 400 "Bad content".
    assert rejected.status_code in (400, 403), rejected.text
    assert rejected.status_code != 200
    accepted = stack.client.post(
        f"{SERVER}/_matrix/media/v3/upload?filename=blob.bin",
        headers={**stack.h(session["access_token"]), "Content-Type": "application/octet-stream"},
        content=b"\x9f" * 64,
    )
    assert accepted.status_code == 200, accepted.text
    room = stack.create_room(session["access_token"], [])
    assert room.status_code == 200, room.text
    room_id = room.json()["room_id"]
    state = stack.mx(
        "PUT",
        f"/_matrix/client/v3/rooms/{quote(room_id, safe='')}/state/m.room.history_visibility/",
        session["access_token"],
        {"history_visibility": "shared"},
    )
    assert state.status_code == 403, state.text
    public = stack.mx(
        "PUT",
        f"/_matrix/client/v3/rooms/{quote(room_id, safe='')}/state/m.room.join_rules/",
        session["access_token"],
        {"join_rule": "public"},
    )
    assert public.status_code == 403, public.text
    threepid = stack.mx(
        "POST",
        f"/_matrix/client/v3/rooms/{quote(room_id, safe='')}/invite",
        session["access_token"],
        {
            "id_server": "example.invalid",
            "id_access_token": "not-a-real-token",
            "medium": "email",
            "address": "a@example.invalid",
        },
    )
    assert threepid.status_code == 403, threepid.text
