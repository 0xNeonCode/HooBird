# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026. Legal name of the copyright holder is not recorded in this repository.
"""Decide whether a child may publish Matrix device keys.

Signature checks use signedjson, which Synapse already ships. This file does
not define a signature algorithm.
"""

from __future__ import annotations


def child_key_upload_decision(
    *,
    approved_ed25519: str | None,
    device_keys,
    user_id: str,
    device_id: str,
    published_ed25519: str | None,
    uploads_material: bool,
) -> str:
    """Return 'allow' or a stable rejection reason.

    A child upload that includes device keys must be signed by the ed25519 key
    a parent already stored. One-time keys are accepted only after that same
    key is already published. Anything else is rejected.
    """

    if not approved_ed25519:
        return "device_not_authorized"
    if device_keys is not None:
        ok, reason = signed_device_keys_match(device_keys, user_id, device_id, approved_ed25519)
        return "allow" if ok else reason
    if published_ed25519 == approved_ed25519:
        return "allow"
    if uploads_material:
        return "device_keys_required"
    return "device_keys_required"


def signed_device_keys_match(device_keys, user_id: str, device_id: str, approved_ed25519: str) -> tuple[bool, str]:
    if not isinstance(device_keys, dict):
        return False, "malformed_device_keys"
    if device_keys.get("user_id") != user_id or device_keys.get("device_id") != device_id:
        return False, "device_key_identity"
    keys = device_keys.get("keys")
    if not isinstance(keys, dict):
        return False, "missing_keys"
    if keys.get(f"ed25519:{device_id}") != approved_ed25519:
        return False, "ed25519_mismatch"
    curve = keys.get(f"curve25519:{device_id}")
    if not isinstance(curve, str) or not curve:
        return False, "missing_curve25519"
    try:
        from signedjson.key import decode_verify_key_bytes
        from signedjson.sign import SignatureVerifyException, verify_signed_json
        import unpaddedbase64
    except Exception:
        return False, "verifier_unavailable"
    try:
        raw = unpaddedbase64.decode_base64(approved_ed25519)
    except Exception:
        return False, "bad_ed25519"
    if len(raw) != 32:
        return False, "bad_ed25519"
    try:
        verify_key = decode_verify_key_bytes(f"ed25519:{device_id}", raw)
        verify_signed_json(device_keys, user_id, verify_key)
    except SignatureVerifyException:
        return False, "bad_signature"
    except Exception:
        return False, "bad_signature"
    return True, "ok"
