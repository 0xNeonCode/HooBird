# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026. Legal name of the copyright holder is not recorded in this repository.
"""Test helpers for parent-approved device keys.

Signing uses signedjson. The curve25519 field in the upload fixture is only
a placeholder string so the server can see the Matrix object shape. Real Olm
sessions in the end-to-end test come from matrix-nio, not from this helper.
"""

from __future__ import annotations

import base64
import secrets

import nacl.signing
from signedjson.key import (
    decode_signing_key_base64,
    encode_signing_key_base64,
    encode_verify_key_base64,
    generate_signing_key,
    get_verify_key,
)
from signedjson.sign import sign_json
from unpaddedbase64 import encode_base64


def random_ed25519() -> str:
    return base64.b64encode(secrets.token_bytes(32)).decode("ascii").rstrip("=")


class DeviceKey:
    def __init__(self, device_id: str):
        self.device_id = device_id
        self._key = generate_signing_key(device_id)
        self.ed25519 = encode_verify_key_base64(get_verify_key(self._key))
        self.curve25519 = random_ed25519()

    def signed_device_keys(self, user_id: str, ed25519: str | None = None) -> dict:
        body = {
            "user_id": user_id,
            "device_id": self.device_id,
            "algorithms": ["m.olm.v1.curve25519-aes-sha2", "m.megolm.v1.aes-sha2"],
            "keys": {
                f"curve25519:{self.device_id}": self.curve25519,
                f"ed25519:{self.device_id}": ed25519 or self.ed25519,
            },
        }
        sign_json(body, user_id, self._key)
        return body

    def sign(self, body: dict, user_id: str) -> dict:
        signed = dict(body)
        sign_json(signed, user_id, self._key)
        return signed


class CrossSigningKey:
    """A Matrix cross-signing key whose id is the public key itself.

    signedjson's version has to be that public key. This is the object shape
    from the Matrix specification, not a new signature algorithm.
    """

    def __init__(self, usage: str):
        raw = nacl.signing.SigningKey.generate()
        self.public = encode_base64(bytes(raw.verify_key))
        self.usage = usage
        self._key = decode_signing_key_base64(
            "ed25519", self.public, encode_signing_key_base64(raw)
        )

    def body(self, user_id: str) -> dict:
        return {
            "user_id": user_id,
            "usage": [self.usage],
            "keys": {f"ed25519:{self.public}": self.public},
        }

    def signed_by(self, user_id: str, signer) -> dict:
        return signer.sign(self.body(user_id), user_id)

    def sign(self, body: dict, user_id: str) -> dict:
        signed = dict(body)
        sign_json(signed, user_id, self._key)
        return signed
