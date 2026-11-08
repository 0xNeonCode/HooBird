# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026. Legal name of the copyright holder is not recorded in this repository.
"""Unit tests for policy decisions. No Synapse and no network."""

from hoobird_rules import (
    ContactFacts,
    PolicyView,
    can_add_parent,
    can_lift_block,
    contact_allowed,
    content_event_allowed,
    fold_username,
    media_looks_like_plaintext,
    members_from_create_body,
    membership_allowed,
    state_event_allowed,
    valid_device_id,
    valid_ed25519,
    valid_username,
)


PARENT = "@parent:hoobird.local"
OTHER = "@other:hoobird.local"
CHILD = "@child:hoobird.local"
ADULT = "@adult:hoobird.local"
STRANGER = "@stranger:hoobird.local"
SIBLING = "@sibling:hoobird.local"


def _view(**kwargs) -> PolicyView:
    view = PolicyView(
        roles={
            PARENT: "parent",
            OTHER: "parent",
            CHILD: "child",
            ADULT: "adult",
            STRANGER: "adult",
            SIBLING: "child",
        },
        parents={CHILD: {PARENT}, SIBLING: {PARENT}},
    )
    for key, value in kwargs.items():
        setattr(view, key, value)
    return view


def _enc(**overrides):
    content = {
        "algorithm": "m.megolm.v1.aes-sha2",
        "sender_key": "curve",
        "ciphertext": "C" * 32,
        "session_id": "sess",
    }
    content.update(overrides)
    return content


def test_block_overrides_approval_and_reapproval_does_not_clear_it():
    blocked = ContactFacts(False, frozenset({OTHER}), PARENT)
    assert contact_allowed(blocked) is False
    # Re-approval is a separate fact. The block set is unchanged.
    assert blocked.approved_by == PARENT
    assert contact_allowed(blocked) is False
    assert can_lift_block(PARENT, blocked.blocked_by) is False
    assert can_lift_block(OTHER, blocked.blocked_by) is True
    lifted = ContactFacts(False, frozenset(), PARENT)
    assert contact_allowed(lifted) is True


def test_both_parents_must_lift_their_own_blocks():
    facts = ContactFacts(False, frozenset({PARENT, OTHER}), PARENT)
    assert can_lift_block(PARENT, facts.blocked_by) is True
    remaining = ContactFacts(False, frozenset({OTHER}), PARENT)
    assert contact_allowed(remaining) is False


def test_linked_parent_is_allowed_and_unapproved_adult_is_not():
    view = _view()
    assert contact_allowed(view.facts(CHILD, PARENT)) is True
    assert contact_allowed(view.facts(CHILD, ADULT)) is False


def test_two_children_need_mutual_approval():
    view = _view()
    current = {CHILD: "join", PARENT: "join"}
    allowed, _reason = membership_allowed(
        view, current, state_key=SIBLING, content={"membership": "invite"}
    )
    assert allowed is False
    view.approvals[(CHILD, SIBLING)] = PARENT
    allowed, _reason = membership_allowed(
        view, current, state_key=SIBLING, content={"membership": "invite"}
    )
    assert allowed is False
    view.approvals[(SIBLING, CHILD)] = PARENT
    allowed, reason = membership_allowed(
        view, current, state_key=SIBLING, content={"membership": "invite"}
    )
    assert allowed is True
    assert reason == "safe_membership"


def test_one_sided_sibling_approval_is_not_enough():
    view = _view()
    view.approvals[(CHILD, SIBLING)] = PARENT
    allowed, reason = membership_allowed(
        view, {CHILD: "join"}, state_key=SIBLING, content={"membership": "invite"}
    )
    assert allowed is False
    assert "unapproved_pair" in reason


def test_leave_is_allowed_even_when_the_room_is_unsafe():
    view = _view()
    current = {CHILD: "join", STRANGER: "join"}
    allowed, reason = membership_allowed(
        view, current, state_key=STRANGER, content={"membership": "leave"}
    )
    assert allowed is True
    assert reason == "membership_reduction"


def test_knock_and_plaintext_and_bad_algorithm_fail_closed():
    view = _view()
    assert membership_allowed(view, {CHILD: "join"}, state_key=ADULT, content={"membership": "knock"})[0] is False
    assert content_event_allowed(view, {CHILD: "join", PARENT: "join"}, event_type="m.room.message", content={"body": "Hallo"})[0] is False
    assert content_event_allowed(view, {CHILD: "join", PARENT: "join"}, event_type="m.reaction", content={"key": "👍"})[0] is False
    bad, reason = content_event_allowed(
        view,
        {CHILD: "join", PARENT: "join"},
        event_type="m.room.encrypted",
        content=_enc(algorithm="m.megolm.v1.aes-sha1"),
    )
    assert bad is False
    assert reason == "unsupported_algorithm"


def test_encrypted_event_rejected_when_an_unapproved_member_is_present():
    view = _view()
    view.approvals[(CHILD, ADULT)] = PARENT
    view.blocks[(CHILD, ADULT)] = {OTHER}
    allowed, reason = content_event_allowed(
        view,
        {CHILD: "join", ADULT: "join"},
        event_type="m.room.encrypted",
        content=_enc(),
    )
    assert allowed is False
    assert reason.startswith("unapproved_pair")


def test_create_room_invite_list_is_part_of_the_set():
    members = members_from_create_body(
        CHILD,
        {"invite": [PARENT, STRANGER], "is_direct": True},
    )
    view = _view()
    from hoobird_rules import unsafe_pairs

    assert unsafe_pairs(view, members)


def test_room_state_cannot_open_federation_or_public_history():
    assert state_event_allowed("m.room.join_rules", {"join_rule": "public"})[0] is False
    assert state_event_allowed("m.room.history_visibility", {"history_visibility": "shared"})[0] is False
    assert state_event_allowed("m.room.create", {"m.federate": True})[0] is False
    assert state_event_allowed("m.room.encryption", {"algorithm": "m.megolm.v1.aes-sha2"})[0] is True
    assert state_event_allowed("m.room.guest_access", {"guest_access": "can_join"})[0] is False


def test_username_device_and_parent_limit():
    assert valid_username("Mara") is True
    assert fold_username("Mara") == "mara"
    assert valid_username("ab") is False
    assert valid_username("a" * 33) is False
    assert valid_device_id("LINUSPHONE1") is True
    assert valid_device_id("../x") is False
    assert valid_ed25519("A" * 43) is True
    assert valid_ed25519("A" * 10) is False
    assert valid_ed25519("not a key") is False
    assert can_add_parent(0) is True
    assert can_add_parent(1) is True
    assert can_add_parent(2) is False


def test_media_magic_heuristic():
    assert media_looks_like_plaintext(b"\xff\xd8\xff\xe1rest") is True
    assert media_looks_like_plaintext(b"\x89PNG\r\n\x1a\nrest") is True
    assert media_looks_like_plaintext(b"RIFF....WAVE") is True
    assert media_looks_like_plaintext(b"OggSrest") is True
    assert media_looks_like_plaintext(b"\x00\x00\x00\x18ftypmp42") is True
    assert media_looks_like_plaintext(b"\x9f" * 16) is False
