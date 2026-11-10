# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

from device_key_check import child_key_upload_decision, signed_device_keys_match
from tests.device_keys import DeviceKey


def test_signed_device_keys_match_the_approved_key_only():
    key = DeviceKey("KINDGERAET01")
    user = "@kind:localhost"
    body = key.signed_device_keys(user)
    ok, reason = signed_device_keys_match(body, user, "KINDGERAET01", key.ed25519)
    assert ok, reason
    other = DeviceKey("KINDGERAET01")
    ok, reason = signed_device_keys_match(body, user, "KINDGERAET01", other.ed25519)
    assert ok is False
    assert reason == "ed25519_mismatch"
    unsigned = dict(body)
    unsigned.pop("signatures")
    ok, reason = signed_device_keys_match(unsigned, user, "KINDGERAET01", key.ed25519)
    assert ok is False
    assert reason == "bad_signature"
    decision = child_key_upload_decision(
        approved_ed25519=key.ed25519,
        device_keys=None,
        user_id=user,
        device_id="KINDGERAET01",
        published_ed25519=None,
        uploads_material=True,
    )
    assert decision == "device_keys_required"
    decision = child_key_upload_decision(
        approved_ed25519=key.ed25519,
        device_keys=body,
        user_id=user,
        device_id="KINDGERAET01",
        published_ed25519=None,
        uploads_material=True,
    )
    assert decision == "allow"


def test_cross_signing_stays_inert_until_an_approved_device_signs_the_master():
    from device_key_check import (
        child_cross_signing_upload_decision,
        child_signature_upload_decision,
    )
    from tests.device_keys import CrossSigningKey, DeviceKey

    user = "@kind:localhost"
    device = DeviceKey("KINDGERAET01")
    approved = {"KINDGERAET01": device.ed25519}
    published = dict(approved)
    master = CrossSigningKey("master")
    self_signing = CrossSigningKey("self_signing")
    user_signing = CrossSigningKey("user_signing")
    first = {
        "master_key": master.body(user),
        "self_signing_key": self_signing.signed_by(user, master),
        "user_signing_key": user_signing.signed_by(user, master),
    }
    assert (
        child_cross_signing_upload_decision(
            body=first,
            user_id=user,
            approved=approved,
            published=published,
            stored_master=None,
        )
        == "allow"
    )
    stored = master.body(user)
    early = {
        user: {
            "KINDGERAET01": device.signed_device_keys(user),
        }
    }
    assert (
        child_signature_upload_decision(
            user_id=user,
            signatures=early,
            approved=approved,
            published=published,
            stored_master=stored,
        )
        == "master_not_bound"
    )
    signed_master = device.sign(master.body(user), user)
    stranger = DeviceKey("ANDERESGERAET")
    assert (
        child_signature_upload_decision(
            user_id=user,
            signatures={user: {stranger.device_id: stranger.signed_device_keys(user)}},
            approved=approved,
            published=published,
            stored_master=stored,
        )
        == "signing_target_not_approved"
    )
    device_document = device.signed_device_keys(user)
    device_document["signatures"] = self_signing.signed_by(user, self_signing)["signatures"]
    combined = {user: {master.public: signed_master, "KINDGERAET01": device_document}}
    assert (
        child_signature_upload_decision(
            user_id=user,
            signatures=combined,
            approved=approved,
            published=published,
            stored_master=stored,
        )
        == "allow"
    )
    replacement = {
        "master_key": CrossSigningKey("master").body(user),
        "self_signing_key": self_signing.signed_by(user, master),
    }
    assert (
        child_cross_signing_upload_decision(
            body=replacement,
            user_id=user,
            approved=approved,
            published=published,
            stored_master=signed_master,
        )
        == "master_replacement_unbound"
    )
    rebound = device.sign(CrossSigningKey("master").body(user), user)
    # The subkey is signed by the old master, not the replacement. That is refused.
    assert (
        child_cross_signing_upload_decision(
            body={"master_key": rebound, "self_signing_key": self_signing.signed_by(user, master)},
            user_id=user,
            approved=approved,
            published=published,
            stored_master=signed_master,
        )
        == "cross_signing_key_not_signed"
    )
