# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026. Legal name of the copyright holder is not recorded in this repository.
"""Synapse module: enforce HooBird child policy inside the homeserver.

Generic clients hit these hooks even when they skip the HooBird app.
Synapse 1.163 has no module callback for /keys/upload,
/keys/device_signing/upload, or /keys/signatures/upload. This module therefore
wraps those three methods on the live E2eKeysHandler object. The servlets in
this version look the methods up on that object when a request arrives. If any
wrap cannot be installed, or the servlet source no longer calls it, child
logins are refused.

A child can publish device keys only when they are signed by the ed25519 key a
parent already stored. Cross-signing material can be uploaded before that
device signs the master key, because the Matrix Dart SDK does those steps in
that order. Signatures cannot bless a device until the master key carries a
signature from an approved device. Replacing a bound master key requires a new
signature from an approved device. MSC3814 dehydrated devices are disabled in
this homeserver. If that flag is turned on, a child dehydrated device is
refused unless its device keys match an approved fingerprint. If that wrap
cannot be installed, child logins are refused.

Policy reads are fail-closed: a database error rejects the operation.
"""

from __future__ import annotations

import inspect
import logging
from collections.abc import Mapping

from synapse.api.errors import NotFoundError, SynapseError
from synapse.http.servlet import parse_json_object_from_request
from synapse.module_api import NOT_SPAM, errors
from synapse.rest.admin._base import assert_user_is_admin
from twisted.internet import defer
from twisted.web.resource import Resource
from twisted.web.server import NOT_DONE_YET

from hoobird_policy_api.store import PolicyStore
from device_key_check import (
    child_cross_signing_upload_decision,
    child_key_upload_decision,
    child_signature_upload_decision,
)
from hoobird_rules import (
    apply_member_event,
    content_event_allowed,
    media_looks_like_plaintext,
    members_from_create_body,
    membership_allowed,
    state_event_allowed,
    unsafe_pairs,
)

logger = logging.getLogger("hoobird_policy")

CONTENT_TYPES = {"m.room.encrypted"} | {
    "m.room.message",
    "m.reaction",
    "m.sticker",
    "m.poll.start",
    "org.matrix.msc3381.poll.start",
}
GUARDED_STATE = {
    "m.room.join_rules",
    "m.room.history_visibility",
    "m.room.guest_access",
    "m.room.encryption",
    "m.room.create",
}


class HoobirdPolicyModule:
    def __init__(self, config: dict, api):
        self.api = api
        self.store = PolicyStore(config["policy_dsn"])
        api.register_spam_checker_callbacks(
            check_event_for_spam=self.check_event_for_spam,
            user_may_join_room=self.user_may_join_room,
            user_may_invite=self.user_may_invite,
            federated_user_may_invite=self.federated_user_may_invite,
            user_may_send_3pid_invite=self.user_may_send_3pid_invite,
            user_may_create_room=self.user_may_create_room,
            user_may_publish_room=self.user_may_publish_room,
            check_media_file_for_spam=self.check_media_file_for_spam,
            check_login_for_spam=self.check_login_for_spam,
            should_drop_federated_event=self.should_drop_federated_event,
        )
        api.register_third_party_rules_callbacks(
            check_event_allowed=self.check_event_allowed,
            on_create_room=self.on_create_room,
        )
        self.key_guard = self._install_key_guard()
        api.register_web_resource("/_hoobird/internal/reconcile", _ReconcileResource(self))
        logger.info(
            "hoobird policy module registered key_guard=%s dehydrated_devices=%s",
            self.key_guard,
            getattr(self, "dehydrated_devices_enabled", None),
        )

    @staticmethod
    def parse_config(config: dict) -> dict:
        if "policy_dsn" not in config:
            raise ValueError("policy_dsn is required")
        return config

    async def check_event_for_spam(self, event):
        decision = await self._guarded_decision(event, None)
        if decision != "allow":
            logger.info("reject event %s: %s", getattr(event, "type", "?"), decision)
            return errors.Codes.FORBIDDEN
        return NOT_SPAM

    async def check_event_allowed(self, event, state_events):
        decision = await self._guarded_decision(event, state_events)
        if decision != "allow":
            logger.info("reject event %s via third-party rules: %s", event.type, decision)
            return False, None
        return True, None

    async def user_may_join_room(self, user_id: str, room_id: str, is_invited: bool):
        try:
            members = await self._load_members(room_id)
            if members is None:
                logger.info("join denied, room state unavailable %s", room_id)
                return errors.Codes.FORBIDDEN
            members[user_id] = "join"
            if unsafe_pairs(self.store.view_for(list(members)), members):
                return errors.Codes.FORBIDDEN
            return NOT_SPAM
        except Exception:
            logger.exception("join check failed")
            return errors.Codes.FORBIDDEN

    async def user_may_invite(self, inviter: str, invitee: str, room_id: str):
        try:
            members = await self._load_members(room_id)
            if members is None:
                logger.info("invite denied, room state unavailable %s", room_id)
                return errors.Codes.FORBIDDEN
            members[invitee] = "invite"
            if inviter not in members:
                members[inviter] = "join"
            if unsafe_pairs(self.store.view_for(list(members)), members):
                return errors.Codes.FORBIDDEN
            return NOT_SPAM
        except Exception:
            logger.exception("invite check failed")
            return errors.Codes.FORBIDDEN

    async def federated_user_may_invite(self, event):
        return errors.Codes.FORBIDDEN

    async def user_may_send_3pid_invite(self, inviter: str, medium: str, address: str, room_id: str):
        return errors.Codes.FORBIDDEN

    async def user_may_create_room(self, user_id: str, room_config: dict):
        try:
            if not isinstance(room_config, dict):
                return errors.Codes.FORBIDDEN
            members = members_from_create_body(user_id, room_config)
            if unsafe_pairs(self.store.view_for(list(members)), members):
                return errors.Codes.FORBIDDEN
            return NOT_SPAM
        except Exception:
            logger.exception("create room check failed")
            return errors.Codes.FORBIDDEN

    async def user_may_publish_room(self, user_id: str, room_id: str):
        return errors.Codes.FORBIDDEN

    async def check_login_for_spam(
        self,
        user_id: str,
        device_id: str | None,
        initial_display_name: str | None,
        request_info,
        auth_provider_id: str | None = None,
    ):
        try:
            if self.store.role_of(user_id) != "child":
                return NOT_SPAM
            if not self.key_guard:
                logger.error("child login denied because the key upload guard is missing")
                return errors.Codes.FORBIDDEN
            if not device_id or not self.store.device_authorized(user_id, device_id):
                logger.info("child device login denied")
                return errors.Codes.FORBIDDEN
            return NOT_SPAM
        except Exception:
            logger.exception("login check failed")
            return errors.Codes.FORBIDDEN

    async def check_media_file_for_spam(self, file_wrapper, file_info):
        try:
            path = getattr(file_wrapper, "path", None)
            if not path:
                return errors.Codes.FORBIDDEN
            with open(path, "rb") as handle:
                header = handle.read(16)
            if media_looks_like_plaintext(header):
                logger.info("plaintext media magic rejected")
                return errors.Codes.FORBIDDEN
            return NOT_SPAM
        except Exception:
            logger.exception("media check failed")
            return errors.Codes.FORBIDDEN

    async def should_drop_federated_event(self, event) -> bool:
        return True

    async def on_create_room(self, requester, request_content: dict, is_requester_admin: bool) -> None:
        creation = request_content.get("creation_content")
        if not isinstance(creation, dict):
            creation = {}
            request_content["creation_content"] = creation
        creation["m.federate"] = False
        request_content["visibility"] = "private"
        request_content["preset"] = "private_chat"
        initial = request_content.get("initial_state")
        if not isinstance(initial, list):
            initial = []
            request_content["initial_state"] = initial
        _ensure_state(initial, "m.room.encryption", {"algorithm": "m.megolm.v1.aes-sha2"})
        _ensure_state(initial, "m.room.join_rules", {"join_rule": "invite"})
        _ensure_state(initial, "m.room.history_visibility", {"history_visibility": "joined"})
        _ensure_state(initial, "m.room.guest_access", {"guest_access": "forbidden"})

    async def _guarded_decision(self, event, state_events) -> str:
        try:
            return await self._decide(event, state_events)
        except Exception:
            logger.exception("policy decision failed")
            return "policy_store_unavailable"

    async def _decide(self, event, state_events) -> str:
        event_type = str(getattr(event, "type", ""))
        content = _as_dict(getattr(event, "content", {}) or {})
        if event_type not in CONTENT_TYPES and event_type != "m.room.member" and event_type not in GUARDED_STATE:
            return "allow"
        if event_type in GUARDED_STATE and event_type != "m.room.member":
            allowed, reason = state_event_allowed(event_type, content)
            return "allow" if allowed else reason
        members = self._members_from_map(state_events) if state_events is not None else None
        if members is None:
            room_id = getattr(event, "room_id", None)
            members = await self._load_members(room_id) if room_id else None
        if event_type == "m.room.member":
            if members is None:
                # Room creation may not have readable state yet. user_may_create_room
                # has already seen the invite list. Log it so tests can see the gap.
                logger.info("member event without room state; deferring to create/invite hooks")
                return "allow"
            sender = getattr(event, "sender", None)
            if isinstance(sender, str) and sender not in members:
                members = dict(members)
                members[sender] = "join"
            view = self.store.view_for(list(apply_member_event(members, event.state_key, content)))
            allowed, reason = membership_allowed(
                view,
                members,
                state_key=getattr(event, "state_key", None),
                content=content,
            )
            return "allow" if allowed else reason
        if members is None:
            return "state_unavailable"
        view = self.store.view_for(list(members))
        allowed, reason = content_event_allowed(
            view, members, event_type=event_type, content=content
        )
        return "allow" if allowed else reason

    async def _load_members(self, room_id: str) -> dict[str, str] | None:
        try:
            state = await self.api.get_room_state(room_id, [("m.room.member", None)])
        except NotFoundError:
            return None
        except SynapseError as exc:
            if getattr(exc, "code", None) == 404:
                return None
            raise
        return self._members_from_map(state)

    @staticmethod
    def _members_from_map(state_events) -> dict[str, str]:
        members: dict[str, str] = {}
        if not state_events:
            return members
        for key, event in state_events.items():
            event_type, state_key = key
            if event_type != "m.room.member" or not isinstance(state_key, str):
                continue
            content = _as_dict(getattr(event, "content", {}) or {})
            membership = content.get("membership")
            if isinstance(membership, str):
                members[state_key] = membership
        return members


    def _install_key_guard(self) -> bool:
        homeserver = getattr(self.api, "_hs", None)
        if homeserver is None:
            logger.error("synapse homeserver handle missing")
            return False
        try:
            handler = homeserver.get_e2e_keys_handler()
        except Exception:
            logger.exception("e2e key handler missing")
            return False
        if not _servlets_call_handler_methods():
            logger.error("synapse key servlets no longer call the wrapped handler methods")
            return False
        original_upload = handler.upload_keys_for_user
        original_signing = handler.upload_signing_keys_for_user
        original_signatures = handler.upload_signatures_for_device_keys

        async def guarded_upload(user_id: str, device_id: str, keys: dict):
            decision = await self._child_upload_decision(handler, user_id, device_id, keys)
            if decision != "allow":
                logger.info("child key upload rejected: %s", decision)
                raise SynapseError(403, decision, errors.Codes.FORBIDDEN)
            return await original_upload(user_id, device_id, keys)

        async def guarded_signing(user_id: str, keys: dict):
            decision = await self._child_signing_decision(handler, user_id, keys)
            if decision != "allow":
                logger.info("child signing-key upload rejected: %s", decision)
                raise SynapseError(403, decision, errors.Codes.FORBIDDEN)
            return await original_signing(user_id, keys)

        async def guarded_signatures(user_id: str, signatures: dict):
            decision = await self._child_signature_decision(handler, user_id, signatures)
            if decision != "allow":
                logger.info("child signature upload rejected: %s", decision)
                raise SynapseError(403, decision, errors.Codes.FORBIDDEN)
            return await original_signatures(user_id, signatures)

        handler.upload_keys_for_user = guarded_upload
        handler.upload_signing_keys_for_user = guarded_signing
        handler.upload_signatures_for_device_keys = guarded_signatures
        if (
            handler.upload_keys_for_user is not guarded_upload
            or handler.upload_signing_keys_for_user is not guarded_signing
            or handler.upload_signatures_for_device_keys is not guarded_signatures
        ):
            logger.error("key upload wrappers were not installed on the live handler")
            return False
        self.dehydrated_devices_enabled = bool(
            getattr(homeserver.config.experimental, "msc3814_enabled", False)
        )
        if self.dehydrated_devices_enabled and not self._install_dehydrated_guard(homeserver):
            return False
        return True

    def _install_dehydrated_guard(self, homeserver) -> bool:
        try:
            device_handler = homeserver.get_device_handler()
        except Exception:
            logger.exception("device handler missing")
            return False
        original = getattr(device_handler, "store_dehydrated_device", None)
        if original is None:
            logger.error("dehydrated device storage is enabled but the method is missing")
            return False

        async def guarded(user_id, device_id, device_data, initial_device_display_name, keys_for_device):
            decision = self._dehydrated_decision(user_id, device_id, keys_for_device)
            if decision != "allow":
                logger.info("child dehydrated device rejected: %s", decision)
                raise SynapseError(403, decision, errors.Codes.FORBIDDEN)
            return await original(
                user_id, device_id, device_data, initial_device_display_name, keys_for_device
            )

        device_handler.store_dehydrated_device = guarded
        return device_handler.store_dehydrated_device is guarded

    def _dehydrated_decision(self, user_id: str, device_id: str | None, keys_for_device) -> str:
        try:
            if self.store.role_of(user_id) != "child":
                return "allow"
            if not isinstance(device_id, str) or not device_id:
                return "device_not_authorized"
            body = keys_for_device if isinstance(keys_for_device, Mapping) else {}
            present = body.get("device_keys")
            return child_key_upload_decision(
                approved_ed25519=self.store.device_ed25519(user_id, device_id),
                device_keys=present,
                user_id=user_id,
                device_id=device_id,
                published_ed25519=None,
                uploads_material=True,
            )
        except Exception:
            logger.exception("dehydrated device decision failed")
            return "policy_store_unavailable"

    async def _child_signing_decision(self, handler, user_id: str, keys: dict) -> str:
        try:
            if self.store.role_of(user_id) != "child":
                return "allow"
            approved = _approved_ed25519(self, user_id)
            published = await _published_ed25519_map(handler, user_id)
            # Signatures live in a separate table. Passing the user includes
            # the signatures that user made on the master key.
            stored = await handler.store.get_e2e_cross_signing_key(user_id, "master", user_id)
            return child_cross_signing_upload_decision(
                body=keys,
                user_id=user_id,
                approved=approved,
                published=published,
                stored_master=stored,
            )
        except Exception:
            logger.exception("child signing-key decision failed")
            return "policy_store_unavailable"

    async def _child_signature_decision(self, handler, user_id: str, signatures: dict) -> str:
        try:
            if self.store.role_of(user_id) != "child":
                return "allow"
            approved = _approved_ed25519(self, user_id)
            published = await _published_ed25519_map(handler, user_id)
            stored = await handler.store.get_e2e_cross_signing_key(user_id, "master", user_id)
            return child_signature_upload_decision(
                user_id=user_id,
                signatures=signatures,
                approved=approved,
                published=published,
                stored_master=stored,
            )
        except Exception:
            logger.exception("child signature decision failed")
            return "policy_store_unavailable"

    async def _child_upload_decision(self, handler, user_id: str, device_id: str, keys: dict) -> str:
        try:
            if self.store.role_of(user_id) != "child":
                return "allow"
            approved = self.store.device_ed25519(user_id, device_id)
            body = keys if isinstance(keys, dict) else {}
            present = body["device_keys"] if "device_keys" in body else None
            published = None
            if present is None:
                published = await _published_ed25519(handler, user_id, device_id)
            uploads_material = bool(body.get("one_time_keys") or body.get("fallback_keys"))
            return child_key_upload_decision(
                approved_ed25519=approved,
                device_keys=present,
                user_id=user_id,
                device_id=device_id,
                published_ed25519=published,
                uploads_material=uploads_material,
            )
        except Exception:
            logger.exception("child key decision failed")
            return "policy_store_unavailable"


    async def reconcile_blocked_contact(
        self, child_user_id: str, contact_user_id: str, room_ids: list[str]
    ) -> list[str]:
        """Kick a blocked contact out of rooms the child already joined.

        The child is the sender, so this only works where that child can kick.
        A room where the child has no power stays as it is. Content checks
        still reject the pair. This is not one transaction with the block.
        """

        kicked: list[str] = []
        for room_id in room_ids:
            if not isinstance(room_id, str) or not room_id.startswith("!"):
                continue
            try:
                await self.api.update_room_membership(
                    child_user_id,
                    contact_user_id,
                    room_id,
                    "kick",
                    content={"reason": "HooBird block"},
                )
                kicked.append(room_id)
            except Exception:
                logger.info("reconcile did not remove membership", exc_info=True)
        return kicked


class _ReconcileResource(Resource):
    isLeaf = True

    def __init__(self, module: HoobirdPolicyModule):
        super().__init__()
        self.module = module

    def render_POST(self, request):
        deferred = defer.ensureDeferred(self._run(request))

        def finish(body: bytes) -> None:
            request.setResponseCode(200)
            request.setHeader(b"content-type", b"application/json")
            request.write(body)
            request.finish()

        def fail(failure) -> None:
            logger.info("reconcile request rejected: %s", failure.getErrorMessage())
            request.setResponseCode(403)
            request.setHeader(b"content-type", b"application/json")
            request.write(b'{"errcode":"M_FORBIDDEN","error":"reconcile_rejected"}')
            if not request.finished:
                request.finish()

        deferred.addCallbacks(finish, fail)
        return NOT_DONE_YET

    async def _run(self, request) -> bytes:
        auth = self.module.api._hs.get_auth()
        requester = await auth.get_user_by_req(request)
        await assert_user_is_admin(auth, requester)
        body = parse_json_object_from_request(request)
        child_user_id = body.get("child_user_id")
        contact_user_id = body.get("contact_user_id")
        room_ids = body.get("room_ids")
        if (
            not isinstance(child_user_id, str)
            or not isinstance(contact_user_id, str)
            or not isinstance(room_ids, list)
        ):
            raise SynapseError(400, "bad_reconcile")
        if self.module.store.role_of(child_user_id) != "child":
            raise SynapseError(403, "not_a_child")
        if not self.module.store.blocks_for(child_user_id, contact_user_id):
            raise SynapseError(403, "block_missing")
        kicked = await self.module.reconcile_blocked_contact(
            child_user_id, contact_user_id, room_ids
        )
        import json

        return json.dumps({"kicked_rooms": kicked}).encode()


def _servlets_call_handler_methods() -> bool:
    """Fail closed when this Synapse build no longer reaches the wrapped methods.

    The check reads the servlet source that is installed in the process. A
    renamed call, or a copy of the bound method taken at startup, makes the
    guard report itself missing and child logins stop.
    """

    try:
        from synapse.rest.client.keys import (
            KeyUploadServlet,
            SignaturesUploadServlet,
            SigningKeyUploadServlet,
        )
    except Exception:
        logger.exception("synapse key servlets could not be imported")
        return False
    expected = {
        KeyUploadServlet: "upload_keys_for_user",
        SigningKeyUploadServlet: "upload_signing_keys_for_user",
        SignaturesUploadServlet: "upload_signatures_for_device_keys",
    }
    for servlet, method in expected.items():
        try:
            # on_POST may be a decorator wrapper whose body does not name the
            # handler. The class source is the version that is installed.
            source = inspect.getsource(servlet)
        except Exception:
            logger.exception("could not read %s", servlet.__name__)
            return False
        if "e2e_keys_handler" not in source or method not in source:
            logger.error("%s no longer calls %s on the handler", servlet.__name__, method)
            return False
    return True


def _approved_ed25519(module, user_id: str) -> dict[str, str]:
    approved: dict[str, str] = {}
    for row in module.store.list_devices(user_id):
        device_id = row.get("device_id")
        ed25519 = row.get("ed25519")
        if isinstance(device_id, str) and isinstance(ed25519, str) and ed25519:
            approved[device_id] = ed25519
    return approved


async def _published_ed25519_map(handler, user_id: str) -> dict[str, str]:
    found = await handler.store.get_e2e_device_keys_for_cs_api([(user_id, None)])
    devices = (found or {}).get(user_id) or {}
    published: dict[str, str] = {}
    for device_id, device in devices.items():
        if not isinstance(device, Mapping):
            continue
        keys = device.get("keys") or {}
        value = keys.get(f"ed25519:{device_id}")
        if isinstance(device_id, str) and isinstance(value, str):
            published[device_id] = value
    return published


async def _published_ed25519(handler, user_id: str, device_id: str) -> str | None:
    found = await handler.store.get_e2e_device_keys_for_cs_api([(user_id, device_id)])
    device = ((found or {}).get(user_id) or {}).get(device_id) or {}
    keys = device.get("keys") or {}
    value = keys.get(f"ed25519:{device_id}")
    return value if isinstance(value, str) else None


def _as_dict(value) -> dict:
    """Synapse event content is often a FrozenDict, which is not a dict."""

    if isinstance(value, Mapping):
        return dict(value)
    return {}


def _ensure_state(initial: list, event_type: str, content: dict) -> None:
    for event in initial:
        if (
            isinstance(event, dict)
            and event.get("type") == event_type
            and event.get("state_key", "") == ""
        ):
            event["content"] = content
            event["state_key"] = ""
            return
    initial.append({"type": event_type, "state_key": "", "content": content})
