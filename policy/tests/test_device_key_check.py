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
