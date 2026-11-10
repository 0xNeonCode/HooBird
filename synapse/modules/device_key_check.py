# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026. Legal name of the copyright holder is not recorded in this repository.
"""Decide whether a child may publish Matrix device keys.

Signature checks use signedjson, which Synapse already ships. This file does
not define a signature algorithm.
"""

from __future__ import annotations

from collections.abc import Mapping


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


def _plain(value):
    if isinstance(value, Mapping):
        return {str(key): _plain(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_plain(item) for item in value]
    return value


def _stripped(value) -> dict:
    body = _plain(value) if isinstance(value, Mapping) else {}
    return {key: item for key, item in body.items() if key not in ("signatures", "unsigned")}


def _signature_map(document, user_id: str):
    if not isinstance(document, Mapping):
        return None
    signatures = document.get("signatures")
    if not isinstance(signatures, Mapping):
        return None
    own = signatures.get(user_id)
    if not isinstance(own, Mapping):
        return None
    return _plain(own)


def _verify_ed25519(document, user_id: str, key_id: str, ed25519: str) -> bool:
    try:
        import unpaddedbase64
        from signedjson.key import decode_verify_key_bytes
        from signedjson.sign import SignatureVerifyException, verify_signed_json
    except Exception:
        return False
    try:
        raw = unpaddedbase64.decode_base64(ed25519)
    except Exception:
        return False
    if len(raw) != 32:
        return False
    try:
        verify_key = decode_verify_key_bytes(key_id, raw)
        verify_signed_json(_plain(document), user_id, verify_key)
    except SignatureVerifyException:
        return False
    except Exception:
        return False
    return True


def approved_device_signature(document, user_id: str, approved: dict[str, str], published: dict[str, str]) -> str:
    """Return 'ok' when every signature is an approved device key and one verifies.

    Unknown algorithms are rejected. Synapse 1.163 stores those on a master
    key without checking them, so a child request that contains one is refused
    before it reaches that code.
    """

    own = _signature_map(document, user_id)
    if own is None or not own:
        return "master_not_signed_by_device"
    verified = False
    for key_id, _signature in own.items():
        if not isinstance(key_id, str) or not key_id.startswith("ed25519:"):
            return "unsupported_signature_algorithm"
        device_id = key_id.split(":", 1)[1]
        approved_key = approved.get(device_id)
        if not approved_key or published.get(device_id) != approved_key:
            return "signing_device_not_approved"
        if not _verify_ed25519(document, user_id, key_id, approved_key):
            return "bad_signature"
        verified = True
    return "ok" if verified else "master_not_signed_by_device"


def _cross_signing_shape(key, user_id: str, usage: str) -> str | None:
    if not isinstance(key, Mapping):
        return "malformed_signing_keys"
    if key.get("user_id") != user_id:
        return "signing_key_identity"
    usages = key.get("usage")
    if not isinstance(usages, list) or usage not in usages:
        return "signing_key_usage"
    keys = key.get("keys")
    if not isinstance(keys, Mapping) or len(keys) != 1:
        return "signing_key_material"
    key_id, value = next(iter(keys.items()))
    if (
        not isinstance(key_id, str)
        or not key_id.startswith("ed25519:")
        or not isinstance(value, str)
        or value != key_id.split(":", 1)[1]
    ):
        return "signing_key_material"
    return None


def _signed_by_master(document, user_id: str, master) -> bool:
    if not isinstance(master, Mapping):
        return False
    keys = master.get("keys")
    if not isinstance(keys, Mapping) or len(keys) != 1:
        return False
    key_id, public = next(iter(keys.items()))
    if not isinstance(key_id, str) or not isinstance(public, str):
        return False
    return _verify_ed25519(document, user_id, key_id, public)


def master_is_bound(master, user_id: str, approved: dict[str, str], published: dict[str, str]) -> bool:
    if not isinstance(master, Mapping):
        return False
    return approved_device_signature(master, user_id, approved, published) == "ok"


def child_cross_signing_upload_decision(
    *,
    body,
    user_id: str,
    approved: dict[str, str],
    published: dict[str, str],
    stored_master,
) -> str:
    """Decide a child's /keys/device_signing/upload.

    The Matrix Dart SDK uploads the master key before the device signs it.
    That first upload is accepted and stays inert: signatures cannot bless a
    device until an approved device has signed this master key. Replacing a
    master key that is already bound requires a new signature from an approved
    device. A password reset is not that signature.
    """

    if not isinstance(body, Mapping):
        return "malformed_signing_keys"
    if not approved:
        return "device_not_authorized"
    master = body.get("master_key")
    bound = master_is_bound(stored_master, user_id, approved, published)
    if master is not None:
        reason = _cross_signing_shape(master, user_id, "master")
        if reason:
            return reason
        if bound:
            signed = approved_device_signature(master, user_id, approved, published)
            if signed != "ok":
                return "master_replacement_unbound"
        signing_master = master
    elif stored_master is None:
        if body.get("self_signing_key") is not None or body.get("user_signing_key") is not None:
            return "master_key_required"
        return "allow"
    else:
        if not bound:
            return "master_not_bound"
        signing_master = stored_master
    for usage, field in (("self_signing", "self_signing_key"), ("user_signing", "user_signing_key")):
        key = body.get(field)
        if key is None:
            continue
        reason = _cross_signing_shape(key, user_id, usage)
        if reason:
            return reason
        if not _signed_by_master(key, user_id, signing_master):
            return "cross_signing_key_not_signed"
    return "allow"


def _is_master_document(document, stored_master) -> bool:
    if not isinstance(document, Mapping):
        return False
    usage = document.get("usage")
    if isinstance(usage, list) and "master" in usage:
        return True
    if isinstance(stored_master, Mapping):
        return _stripped(document) == _stripped(stored_master)
    return False


def child_signature_upload_decision(
    *,
    user_id: str,
    signatures,
    approved: dict[str, str],
    published: dict[str, str],
    stored_master,
) -> str:
    """Decide a child's /keys/signatures/upload before Synapse stores it.

    A device may be cross-signed only when that device_id is a parent-approved
    ed25519 key and the master key is signed by one of those device keys.
    The whole request is refused when any part is not allowed.
    """

    if not isinstance(signatures, Mapping):
        return "malformed_signatures"
    if not approved:
        return "device_not_authorized"
    own = signatures.get(user_id, {})
    if own is None:
        own = {}
    if not isinstance(own, Mapping):
        return "malformed_signatures"
    request_binds = master_is_bound(stored_master, user_id, approved, published)
    master_seen = False
    device_targets: list[tuple[str, object]] = []
    for target_id, document in own.items():
        if not isinstance(target_id, str) or not isinstance(document, Mapping):
            return "malformed_signatures"
        if _is_master_document(document, stored_master):
            master_seen = True
            if isinstance(stored_master, Mapping) and _stripped(document) != _stripped(stored_master):
                return "master_key_mismatch"
            if stored_master is None:
                return "master_not_stored"
            signed = approved_device_signature(document, user_id, approved, published)
            if signed != "ok":
                return signed
            request_binds = True
        else:
            device_targets.append((target_id, document))
    if master_seen and not request_binds:
        return "master_not_bound"
    for target_id, document in device_targets:
        approved_key = approved.get(target_id)
        if not approved_key or published.get(target_id) != approved_key:
            return "signing_target_not_approved"
        keys = document.get("keys") if isinstance(document, Mapping) else None
        if isinstance(keys, Mapping):
            advertised = keys.get(f"ed25519:{target_id}")
            if advertised != approved_key:
                return "ed25519_mismatch"
        if not request_binds:
            return "master_not_bound"
    others = [key for key in signatures.keys() if key != user_id]
    if others and not request_binds:
        return "master_not_bound"
    for other_user, documents in signatures.items():
        if other_user == user_id:
            continue
        if not isinstance(documents, Mapping):
            return "malformed_signatures"
    return "allow"
