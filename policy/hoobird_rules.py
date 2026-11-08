# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026. Legal name of the copyright holder is not recorded in this repository.
"""Pure HooBird child-policy decisions.

No I/O and no cryptography. The Synapse module and the policy API both call
these functions so a direct Matrix request and a management request cannot
drift apart.

Conservative prototype assumptions are documented in
docs/confirmed-product-spec.md. They are not confirmed product decisions.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

USERNAME_RE = re.compile(r"^[a-z0-9][a-z0-9._-]{2,31}$")
DEVICE_ID_RE = re.compile(r"^[A-Za-z0-9._~-]{4,64}$")
LOCALPART_RE = re.compile(r"^hb[0-9a-f]{32}$")

ACTIVE_MEMBERSHIPS = frozenset({"join", "invite"})
REDUCTION_MEMBERSHIPS = frozenset({"leave", "ban"})
MAX_PARENTS = 2
MEGOLM = "m.megolm.v1.aes-sha2"

# Event types that would reveal message content to the server or to room
# members without Megolm. Reactions and stickers are included so a generic
# client cannot bypass mandatory encryption with a side channel event.
PLAINTEXT_CONTENT_TYPES = frozenset(
    {
        "m.room.message",
        "m.reaction",
        "m.sticker",
        "m.poll.start",
        "org.matrix.msc3381.poll.start",
    }
)

PLAINTEXT_MEDIA_PREFIXES = (
    b"\xff\xd8\xff",  # JPEG
    b"\x89PNG\r\n\x1a\n",
    b"GIF87a",
    b"GIF89a",
    b"OggS",
    b"ID3",
    b"%PDF",
    b"RIFF",  # WAV / WebP
    b"\x1aE\xdf\xa3",  # WebM / Matroska
)


@dataclass(frozen=True)
class ContactFacts:
    is_linked_parent: bool
    blocked_by: frozenset[str]
    approved_by: str | None


@dataclass
class PolicyView:
    """Snapshot of the accounts relevant to one decision."""

    roles: dict[str, str] = field(default_factory=dict)
    parents: dict[str, set[str]] = field(default_factory=dict)
    approvals: dict[tuple[str, str], str] = field(default_factory=dict)
    blocks: dict[tuple[str, str], set[str]] = field(default_factory=dict)

    def children_in(self, user_ids: set[str]) -> set[str]:
        return {user_id for user_id in user_ids if self.roles.get(user_id) == "child"}

    def facts(self, child_id: str, other_id: str) -> ContactFacts:
        return ContactFacts(
            is_linked_parent=other_id in self.parents.get(child_id, set()),
            blocked_by=frozenset(self.blocks.get((child_id, other_id), set())),
            approved_by=self.approvals.get((child_id, other_id)),
        )


def fold_username(username: str) -> str:
    return username.strip().casefold()


def valid_username(username: str) -> bool:
    return bool(USERNAME_RE.fullmatch(fold_username(username)))


def valid_device_id(device_id: str) -> bool:
    return bool(DEVICE_ID_RE.fullmatch(device_id))


def contact_allowed(facts: ContactFacts) -> bool:
    """Linked parents are implicitly allowed and cannot be blocked.

    Any block overrides approval. A second parent's approval does not remove
    a block; that is enforced by leaving the block row in place.
    """

    if facts.is_linked_parent:
        return True
    if facts.blocked_by:
        return False
    return facts.approved_by is not None


def can_lift_block(actor_id: str, blocked_by: frozenset[str]) -> bool:
    """Only the parent who stored this block may remove it."""

    return actor_id in blocked_by


def can_add_parent(existing_parent_count: int) -> bool:
    return existing_parent_count < MAX_PARENTS


def active_members(memberships: dict[str, str]) -> set[str]:
    return {
        user_id
        for user_id, membership in memberships.items()
        if membership in ACTIVE_MEMBERSHIPS
    }


def unsafe_pairs(view: PolicyView, memberships: dict[str, str]) -> list[tuple[str, str]]:
    members = active_members(memberships)
    problems: list[tuple[str, str]] = []
    for child_id in sorted(view.children_in(members)):
        for other_id in sorted(members):
            if other_id == child_id:
                continue
            if not contact_allowed(view.facts(child_id, other_id)):
                problems.append((child_id, other_id))
    return problems


def membership_allowed(
    view: PolicyView,
    current: dict[str, str],
    *,
    state_key: str | None,
    content: dict | None,
) -> tuple[bool, str]:
    """Fail closed unless the resulting active set is safe.

    Leave and ban are allowed so a room can shrink back to a safe set.
    Knock is rejected. The prototype does not auto-remove a child; it refuses
    the membership that would expose one.
    """

    if not state_key or not isinstance(content, dict):
        return False, "malformed_member_event"
    membership = content.get("membership")
    if not isinstance(membership, str):
        return False, "malformed_member_event"
    if membership in REDUCTION_MEMBERSHIPS:
        return True, "membership_reduction"
    if membership == "knock":
        return False, "knock_rejected"
    if membership not in ACTIVE_MEMBERSHIPS:
        return False, "unknown_membership"
    resulting = dict(current)
    resulting[state_key] = membership
    problems = unsafe_pairs(view, resulting)
    if problems:
        child_id, other_id = problems[0]
        return False, f"unapproved_pair:{child_id}:{other_id}"
    return True, "safe_membership"


def content_event_allowed(
    view: PolicyView,
    current: dict[str, str],
    *,
    event_type: str,
    content: dict | None,
) -> tuple[bool, str]:
    if event_type in PLAINTEXT_CONTENT_TYPES:
        return False, "plaintext_rejected"
    if event_type != "m.room.encrypted":
        return False, "unsupported_content"
    if not isinstance(content, dict):
        return False, "malformed_encrypted_event"
    if content.get("algorithm") != MEGOLM:
        return False, "unsupported_algorithm"
    ciphertext = content.get("ciphertext")
    sender_key = content.get("sender_key")
    session_id = content.get("session_id")
    if not isinstance(ciphertext, str) or len(ciphertext) < 16:
        return False, "missing_ciphertext"
    if not isinstance(sender_key, str) or not sender_key:
        return False, "missing_sender_key"
    if not isinstance(session_id, str) or not session_id:
        return False, "missing_session_id"
    problems = unsafe_pairs(view, current)
    if problems:
        child_id, other_id = problems[0]
        return False, f"unapproved_pair:{child_id}:{other_id}"
    return True, "encrypted_ok"


def state_event_allowed(event_type: str, content: dict | None) -> tuple[bool, str]:
    """Room policy that must not be relaxed by a client."""

    body = content if isinstance(content, dict) else {}
    if event_type == "m.room.join_rules":
        if body.get("join_rule") != "invite":
            return False, "join_rule_not_invite"
        return True, "join_rule_ok"
    if event_type == "m.room.history_visibility":
        if body.get("history_visibility") != "joined":
            return False, "history_visibility_not_joined"
        return True, "history_ok"
    if event_type == "m.room.guest_access":
        if body.get("guest_access") == "can_join":
            return False, "guest_access_rejected"
        return True, "guest_access_ok"
    if event_type == "m.room.encryption":
        if body.get("algorithm") != MEGOLM:
            return False, "encryption_algorithm_rejected"
        return True, "encryption_ok"
    if event_type == "m.room.create":
        if body.get("m.federate") is True:
            return False, "federation_rejected"
        return True, "create_ok"
    return True, "state_allowed"


def members_from_create_body(creator_id: str, room_config: dict | None) -> dict[str, str]:
    members = {creator_id: "join"}
    if not isinstance(room_config, dict):
        return members
    for invitee in room_config.get("invite") or []:
        if isinstance(invitee, str) and invitee:
            members[invitee] = "invite"
    for event in room_config.get("initial_state") or []:
        if not isinstance(event, dict) or event.get("type") != "m.room.member":
            continue
        state_key = event.get("state_key")
        membership = (event.get("content") or {}).get("membership", "invite")
        if isinstance(state_key, str) and state_key:
            members[state_key] = membership if membership in ACTIVE_MEMBERSHIPS else "invite"
    return members


def media_looks_like_plaintext(header: bytes) -> bool:
    """Heuristic only: common container magic, not a proof of encryption.

    Megolm ciphertext is random-looking. A genuine ciphertext could theoretically
    start with these bytes; that collision is not treated as a security property.
    """

    if any(header.startswith(prefix) for prefix in PLAINTEXT_MEDIA_PREFIXES):
        return True
    return len(header) >= 12 and header[4:8] == b"ftyp"


def apply_member_event(
    current: dict[str, str], state_key: str | None, content: dict | None
) -> dict[str, str]:
    updated = dict(current)
    if state_key and isinstance(content, dict) and isinstance(content.get("membership"), str):
        updated[state_key] = content["membership"]
    return updated
