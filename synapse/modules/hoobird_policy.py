# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026. Legal name of the copyright holder is not recorded in this repository.
"""Synapse module: enforce HooBird child policy inside the homeserver.

Generic clients hit these hooks even when they skip the HooBird app.
There is no module callback for /keys/upload or /keys/device_signing/upload.
Those routes still require an access token, and a child token is only issued
by login, which this module can reject. Revocation deletes the Synapse device.

Policy reads are fail-closed: a database error rejects the operation.
"""

from __future__ import annotations

import logging
from collections.abc import Mapping

from synapse.api.errors import NotFoundError, SynapseError
from synapse.module_api import NOT_SPAM, errors

from hoobird_policy_api.store import PolicyStore
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
        logger.info("hoobird policy module registered")

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
