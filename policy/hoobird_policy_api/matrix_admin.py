# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026. Legal name of the copyright holder is not recorded in this repository.
"""Small Synapse admin client used only by the policy service.

Passwords are sent to Synapse and are not logged. This client never reads
room events and never calls the cross-signing reset endpoint.
"""

from __future__ import annotations

import hashlib
import hmac
import logging
import time
from urllib.parse import quote

import httpx

logger = logging.getLogger("hoobird.matrix_admin")


class MatrixCallError(RuntimeError):
    def __init__(self, status_code: int, body: str):
        super().__init__(f"synapse {status_code}")
        self.status_code = status_code
        self.body = body[:500]


class SynapseAdmin:
    def __init__(
        self,
        *,
        base_url: str,
        server_name: str,
        shared_secret: str,
        admin_localpart: str,
        admin_password: str,
    ):
        self.base_url = base_url.rstrip("/")
        self.server_name = server_name
        self.shared_secret = shared_secret
        self.admin_localpart = admin_localpart
        self.admin_password = admin_password
        self.admin_user_id = f"@{admin_localpart}:{server_name}"
        self._token: str | None = None
        self.http = httpx.Client(timeout=30.0)

    def close(self) -> None:
        self.http.close()

    def wait_until_healthy(self, attempts: int = 60) -> None:
        last_error = "not started"
        for _ in range(attempts):
            try:
                response = self.http.get(f"{self.base_url}/health")
                if response.status_code == 200:
                    return
                last_error = f"{response.status_code}"
            except httpx.HTTPError as exc:
                last_error = str(exc)
            time.sleep(1)
        raise RuntimeError(f"synapse health failed: {last_error}")

    def ensure_admin_token(self) -> str:
        token = self._password_login(self.admin_localpart, self.admin_password, "HOOBIRDADMIN")
        if token is None:
            token = self._register_bootstrap_admin()
        self._token = token
        return token

    def create_user(self, localpart: str, password: str, displayname: str) -> str:
        user_id = f"@{localpart}:{self.server_name}"
        response = self._admin(
            "PUT",
            f"/_synapse/admin/v2/users/{quote(user_id, safe='')}",
            {
                "password": password,
                "displayname": displayname,
                "admin": False,
                "deactivated": False,
                "logout_devices": False,
            },
        )
        if response.status_code not in (200, 201):
            raise MatrixCallError(response.status_code, response.text)
        return user_id

    def set_displayname(self, user_id: str, displayname: str) -> None:
        response = self._admin(
            "PUT",
            f"/_synapse/admin/v2/users/{quote(user_id, safe='')}",
            {"displayname": displayname, "logout_devices": False},
        )
        if response.status_code not in (200, 201):
            raise MatrixCallError(response.status_code, response.text)

    def reset_password_logout_devices(self, user_id: str, new_password: str) -> None:
        """Changes the password and logs devices out.

        Does not replace cross-signing keys and does not return a recovery key.
        """

        response = self._admin(
            "POST",
            f"/_synapse/admin/v1/reset_password/{quote(user_id, safe='')}",
            {"new_password": new_password, "logout_devices": True},
        )
        if response.status_code != 200:
            raise MatrixCallError(response.status_code, response.text)

    def joined_rooms(self, user_id: str) -> list[str]:
        response = self._admin(
            "GET",
            f"/_synapse/admin/v1/users/{quote(user_id, safe='')}/joined_rooms",
        )
        if response.status_code != 200:
            raise MatrixCallError(response.status_code, response.text)
        return list(response.json().get("joined_rooms") or [])

    def kick_from_room(self, room_id: str, user_id: str) -> None:
        response = self._admin(
            "POST",
            f"/_synapse/admin/v1/rooms/{quote(room_id, safe='')}/kick",
            {"user_id": user_id, "reason": "HooBird block"},
        )
        if response.status_code not in (200, 400, 403, 404):
            raise MatrixCallError(response.status_code, response.text)

    def reconcile_block(self, child_user_id: str, contact_user_id: str) -> dict:
        """Ask the homeserver module to remove a blocked contact.

        Retries so an invite that won the race by a few hundred milliseconds
        is kicked after the block is visible. This is not one database
        transaction with Synapse. Content checks still fail closed immediately.
        The module kicks as the child, so a room where the child has no power
        stays. The admin token only authorises the request. It does not join
        the room.
        """

        kicked: set[str] = set()
        errors = 0
        for _ in range(4):
            try:
                rooms = self.joined_rooms(child_user_id)
            except MatrixCallError:
                errors += 1
                rooms = []
            response = self.http.post(
                f"{self.base_url}/_hoobird/internal/reconcile",
                headers={"Authorization": f"Bearer {self._token}"},
                json={
                    "child_user_id": child_user_id,
                    "contact_user_id": contact_user_id,
                    "room_ids": rooms,
                },
            )
            if response.status_code == 200:
                for room_id in response.json().get("kicked_rooms") or []:
                    kicked.add(room_id)
            else:
                errors += 1
                logger.info("reconcile status %s", response.status_code)
            time.sleep(0.2)
        return {"kicked_rooms": sorted(kicked), "errors": errors}

    def delete_device(self, user_id: str, device_id: str) -> None:
        response = self._admin(
            "DELETE",
            f"/_synapse/admin/v2/users/{quote(user_id, safe='')}/devices/{quote(device_id, safe='')}",
        )
        if response.status_code not in (200, 404):
            raise MatrixCallError(response.status_code, response.text)

    def list_devices(self, user_id: str) -> list[dict]:
        response = self._admin(
            "GET",
            f"/_synapse/admin/v2/users/{quote(user_id, safe='')}/devices",
        )
        if response.status_code != 200:
            raise MatrixCallError(response.status_code, response.text)
        return list(response.json().get("devices") or [])

    def login(
        self,
        localpart: str,
        password: str,
        device_id: str | None,
        device_name: str,
    ) -> httpx.Response:
        body: dict = {
            "type": "m.login.password",
            "identifier": {"type": "m.id.user", "user": localpart},
            "password": password,
            "initial_device_display_name": device_name,
        }
        if device_id:
            body["device_id"] = device_id
        return self.http.post(f"{self.base_url}/_matrix/client/v3/login", json=body)

    def _password_login(self, localpart: str, password: str, device_id: str) -> str | None:
        response = self.login(localpart, password, device_id, "HooBird-Admin")
        if response.status_code != 200:
            return None
        return response.json().get("access_token")

    def _register_bootstrap_admin(self) -> str:
        nonce_response = self.http.get(f"{self.base_url}/_synapse/admin/v1/register")
        if nonce_response.status_code != 200:
            raise MatrixCallError(nonce_response.status_code, nonce_response.text)
        nonce = nonce_response.json()["nonce"]
        username = self.admin_localpart.encode("utf-8")
        password = self.admin_password.encode("utf-8")
        digest = hmac.new(self.shared_secret.encode("utf-8"), digestmod=hashlib.sha1)
        digest.update(nonce.encode("utf-8"))
        digest.update(b"\x00")
        digest.update(username)
        digest.update(b"\x00")
        digest.update(password)
        digest.update(b"\x00")
        digest.update(b"admin")
        response = self.http.post(
            f"{self.base_url}/_synapse/admin/v1/register",
            json={
                "nonce": nonce,
                "username": self.admin_localpart,
                "password": self.admin_password,
                "admin": True,
                "displayname": "hoobird-admin",
                "mac": digest.hexdigest(),
            },
        )
        if response.status_code != 200:
            raise MatrixCallError(response.status_code, response.text)
        token = response.json().get("access_token")
        if not token:
            raise RuntimeError("bootstrap registration returned no token")
        logger.info("bootstrap admin registered")
        return token

    def _admin(self, method: str, path: str, body: dict | None = None) -> httpx.Response:
        if not self._token:
            self.ensure_admin_token()
        response = self._send(method, path, body)
        if response.status_code == 401:
            self.ensure_admin_token()
            response = self._send(method, path, body)
        return response

    def _send(self, method: str, path: str, body: dict | None) -> httpx.Response:
        return self.http.request(
            method,
            f"{self.base_url}{path}",
            json=body,
            headers={"Authorization": f"Bearer {self._token}"},
        )
