# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026. Legal name of the copyright holder is not recorded in this repository.
"""HooBird policy HTTP API.

Account directory, parent links and device authorization live here.
Room and login enforcement does not: Synapse loads hoobird_policy.py and
rejects the same decisions for generic Matrix clients.
"""

from __future__ import annotations

import logging
import os
import re
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel, Field

from hoobird_policy_api.matrix_admin import MatrixCallError, SynapseAdmin
from hoobird_policy_api.store import Conflict, NotFound, PolicyStore
from hoobird_rules import (
    ContactFacts,
    can_add_parent,
    can_lift_block,
    contact_allowed,
    fold_username,
    valid_device_id,
    valid_ed25519,
    valid_username,
)

logger = logging.getLogger("hoobird.api")
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
ROLES = {"parent", "child", "adult"}


class LoginBody(BaseModel):
    username: str
    password: str = Field(min_length=10, max_length=200)
    device_id: str | None = None
    device_name: str = "HooBird"


class CreateAccountBody(BaseModel):
    username: str
    password: str = Field(min_length=10, max_length=200)
    role: str
    email: str | None = None
    device_id: str | None = None
    ed25519: str | None = None


class UsernameBody(BaseModel):
    username: str


class EmailBody(BaseModel):
    email: str


class ConfirmEmailBody(BaseModel):
    token: str


class ResetPasswordBody(BaseModel):
    new_password: str = Field(min_length=10, max_length=200)


class LinkCodeBody(BaseModel):
    ttl_seconds: int | None = None


class RedeemBody(BaseModel):
    code: str


class ContactBody(BaseModel):
    contact_user_id: str


class DeviceBody(BaseModel):
    device_id: str
    ed25519: str


def _settings() -> dict:
    return {
        "dsn": os.environ["POLICY_DSN"],
        "synapse_url": os.environ["SYNAPSE_URL"],
        "server_name": os.environ.get("SERVER_NAME", "hoobird.local"),
        "shared_secret": os.environ["REGISTRATION_SHARED_SECRET"],
        "admin_localpart": os.environ.get("ADMIN_LOCALPART", "hoobirdadmin"),
        "admin_username": os.environ.get("ADMIN_USERNAME", "hoobird-admin"),
        "admin_password": os.environ["ADMIN_PASSWORD"],
        "dev_email_tokens": os.environ.get("HOOBIRD_DEV_RETURN_EMAIL_TOKENS") == "1",
    }


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = _settings()
    store = PolicyStore(settings["dsn"])
    store.ensure_schema()
    admin = SynapseAdmin(
        base_url=settings["synapse_url"],
        server_name=settings["server_name"],
        shared_secret=settings["shared_secret"],
        admin_localpart=settings["admin_localpart"],
        admin_password=settings["admin_password"],
    )
    admin.wait_until_healthy()
    admin.ensure_admin_token()
    user_id = admin.admin_user_id
    if store.get_account(user_id) is None:
        store.insert_account(
            user_id=user_id,
            localpart=settings["admin_localpart"],
            username=settings["admin_username"],
            username_folded=fold_username(settings["admin_username"]),
            role="parent",
            created_by=None,
            is_bootstrap=True,
        )
    app.state.store = store
    app.state.admin = admin
    app.state.settings = settings
    logger.info("policy api ready")
    yield
    admin.close()


app = FastAPI(title="HooBird Policy", lifespan=lifespan)


def store_of(request: Request) -> PolicyStore:
    return request.app.state.store


def admin_of(request: Request) -> SynapseAdmin:
    return request.app.state.admin


def _fail(status: int, code: str, error: str) -> None:
    raise HTTPException(status_code=status, detail={"hoobird_code": code, "error": error})


def caller(request: Request) -> dict:
    header = request.headers.get("authorization", "")
    if not header.lower().startswith("bearer "):
        _fail(401, "missing_token", "Anmeldung fehlt.")
    token = header.split(" ", 1)[1].strip()
    if not token:
        _fail(401, "missing_token", "Anmeldung fehlt.")
    response = admin_of(request).http.get(
        f"{request.app.state.settings['synapse_url']}/_matrix/client/v3/account/whoami",
        headers={"Authorization": f"Bearer {token}"},
    )
    if response.status_code != 200:
        _fail(401, "bad_token", "Anmeldung ist ungültig.")
    user_id = response.json().get("user_id")
    account = store_of(request).get_account(user_id)
    if account is None:
        _fail(403, "unknown_account", "Kein HooBird-Konto für diese Matrix-ID.")
    account["device_id"] = response.json().get("device_id")
    account["token"] = token
    return account


def _require_linked_parent(store: PolicyStore, actor: dict, child_id: str) -> dict:
    child = store.get_account(child_id)
    if child is None or child["role"] != "child":
        _fail(404, "child_not_found", "Kinderkonto nicht gefunden.")
    if not store.is_linked_parent(child_id, actor["user_id"]):
        _fail(403, "not_linked_parent", "Nur ein verknüpftes Elternkonto darf das.")
    return child


def _public_account(account: dict) -> dict:
    return {
        "user_id": account["user_id"],
        "username": account["username"],
        "role": account["role"],
        "mxid_immutable": True,
    }


@app.get("/_hoobird/health")
def health(request: Request):
    with store_of(request)._connect() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT 1")
            cur.fetchone()
    if not admin_of(request)._token:
        _fail(503, "not_ready", "Policy-Dienst ist nicht bereit.")
    return {"ok": True, "server_name": request.app.state.settings["server_name"]}


@app.post("/_hoobird/v1/login")
def login(body: LoginBody, request: Request):
    folded = fold_username(body.username)
    if not valid_username(folded):
        _fail(400, "bad_username", "Der Nutzername ist ungültig.")
    account = store_of(request).get_by_username(folded)
    if account is None:
        _fail(401, "login_failed", "Anmeldung fehlgeschlagen.")
    if account["role"] == "child":
        if not body.device_id or not valid_device_id(body.device_id):
            _fail(403, "device_not_authorized", "Dieses Gerät ist für das Kinderkonto nicht freigegeben.")
        if not store_of(request).device_authorized(account["user_id"], body.device_id):
            _fail(403, "device_not_authorized", "Dieses Gerät ist für das Kinderkonto nicht freigegeben.")
    response = admin_of(request).login(
        account["localpart"],
        body.password,
        body.device_id,
        body.device_name[:40] or "HooBird",
    )
    if response.status_code != 200:
        _fail(401, "login_failed", "Anmeldung fehlgeschlagen.")
    payload = response.json()
    payload["username"] = account["username"]
    payload["role"] = account["role"]
    payload["mxid_immutable"] = True
    return payload


@app.get("/_hoobird/v1/me")
def me(request: Request):
    account = caller(request)
    body = _public_account(account)
    body["device_id"] = account.get("device_id")
    body["email_confirmed"] = account["email_confirmed"]
    body["has_email"] = bool(account["email"])
    if account["role"] == "parent":
        body["children"] = store_of(request).children_of(account["user_id"])
    if account["role"] == "child":
        body["parents"] = store_of(request).parents_of(account["user_id"])
        body["devices"] = store_of(request).list_devices(account["user_id"])
    return body


@app.post("/_hoobird/v1/accounts")
def create_account(body: CreateAccountBody, request: Request):
    actor = caller(request)
    folded = fold_username(body.username)
    if body.role not in ROLES or not valid_username(folded):
        _fail(400, "bad_account", "Rolle oder Nutzername ist ungültig.")
    if "\x00" in body.password:
        _fail(400, "bad_password", "Das Passwort ist ungültig.")
    store = store_of(request)
    if body.role == "child":
        if actor["is_bootstrap"] or actor["role"] != "parent":
            _fail(403, "parent_required", "Nur ein Elternkonto kann ein Kinderkonto anlegen.")
    elif not actor["is_bootstrap"]:
        _fail(403, "bootstrap_required", "Dieses Konto darf keine weiteren Erwachsenenkonten anlegen.")
    email = None
    if body.email:
        email = body.email.strip().lower()
        if not EMAIL_RE.fullmatch(email):
            _fail(400, "bad_email", "Die E-Mail-Adresse ist ungültig.")
    if body.device_id and not valid_device_id(body.device_id):
        _fail(400, "bad_device", "Die Gerätekennung ist ungültig.")
    if body.role == "child" and body.device_id and not valid_ed25519(body.ed25519 or ""):
        _fail(
            400,
            "fingerprint_required",
            "Ein Kindergerät braucht die ed25519-Kennung, die das Gerät anzeigt.",
        )
    localpart = None
    user_id = None
    for _ in range(3):
        localpart = __import__("hoobird_policy_api.store", fromlist=["new_localpart"]).new_localpart()
        user_id = f"@{localpart}:{request.app.state.settings['server_name']}"
        if store.get_account(user_id) is None:
            break
    assert localpart and user_id
    try:
        store.insert_account(
            user_id=user_id,
            localpart=localpart,
            username=folded,
            username_folded=folded,
            role=body.role,
            created_by=actor["user_id"],
        )
    except Conflict:
        _fail(409, "username_taken", "Der Nutzername ist schon vergeben.")
    try:
        admin_of(request).create_user(localpart, body.password, folded)
    except MatrixCallError as exc:
        store.delete_account(user_id)
        logger.info("matrix create failed status=%s", exc.status_code)
        _fail(502, "matrix_create_failed", "Das Matrix-Konto konnte nicht angelegt werden.")
    if body.role == "child":
        store.link_parent(user_id, actor["user_id"])
        if body.device_id:
            store.authorize_device(user_id, body.device_id, actor["user_id"], body.ed25519 or "")
    dev_token = None
    if email:
        import secrets

        dev_token = secrets.token_urlsafe(24)
        store.set_email(user_id, email, dev_token)
    result = _public_account(store.get_account(user_id))
    result["localpart_opaque"] = True
    if body.role == "child":
        result["parents"] = store.parents_of(user_id)
        result["devices"] = store.list_devices(user_id)
    if dev_token and request.app.state.settings["dev_email_tokens"]:
        result["dev_only_email_token"] = dev_token
        result["dev_only_email_token_note"] = (
            "Nur die lokale Wegwerf-Umgebung gibt den Token zurück. "
            "Das bestätigt ein Postfach, nicht Alter oder Identität."
        )
    return result


@app.patch("/_hoobird/v1/accounts/{user_id}/username")
def change_username(user_id: str, body: UsernameBody, request: Request):
    actor = caller(request)
    store = store_of(request)
    target = store.get_account(user_id)
    if target is None:
        _fail(404, "account_not_found", "Konto nicht gefunden.")
    if actor["user_id"] != user_id and not (
        target["role"] == "child" and store.is_linked_parent(user_id, actor["user_id"])
    ):
        _fail(403, "forbidden", "Dieser Nutzername darf nicht geändert werden.")
    folded = fold_username(body.username)
    if not valid_username(folded):
        _fail(400, "bad_username", "Der Nutzername ist ungültig.")
    try:
        store.update_username(user_id, folded, folded)
    except Conflict:
        _fail(409, "username_taken", "Der Nutzername ist schon vergeben.")
    except NotFound:
        _fail(404, "account_not_found", "Konto nicht gefunden.")
    try:
        admin_of(request).set_displayname(user_id, folded)
    except MatrixCallError:
        logger.info("displayname mirror failed for %s", user_id)
    updated = store.get_account(user_id)
    return {
        "user_id": updated["user_id"],
        "username": updated["username"],
        "mxid_unchanged": True,
    }


@app.post("/_hoobird/v1/accounts/{user_id}/email")
def set_email(user_id: str, body: EmailBody, request: Request):
    actor = caller(request)
    store = store_of(request)
    target = store.get_account(user_id)
    if target is None:
        _fail(404, "account_not_found", "Konto nicht gefunden.")
    if actor["user_id"] != user_id and not (
        target["role"] == "child" and store.is_linked_parent(user_id, actor["user_id"])
    ):
        _fail(403, "forbidden", "Die E-Mail-Adresse darf nicht gesetzt werden.")
    email = body.email.strip().lower()
    if not EMAIL_RE.fullmatch(email):
        _fail(400, "bad_email", "Die E-Mail-Adresse ist ungültig.")
    import secrets

    token = secrets.token_urlsafe(24)
    store.set_email(user_id, email, token)
    result = {"email_confirmed": False, "mailbox_check_only": True}
    if request.app.state.settings["dev_email_tokens"]:
        result["dev_only_email_token"] = token
    return result


@app.post("/_hoobird/v1/accounts/{user_id}/email/confirm")
def confirm_email(user_id: str, body: ConfirmEmailBody, request: Request):
    if not store_of(request).confirm_email(user_id, body.token):
        _fail(400, "bad_token", "Der Bestätigungscode ist ungültig.")
    return {
        "email_confirmed": True,
        "proves": "mailbox_control",
        "does_not_prove": ["legal_identity", "age", "guardianship"],
    }


@app.post("/_hoobird/v1/accounts/{user_id}/reset-password")
def reset_password(user_id: str, body: ResetPasswordBody, request: Request):
    actor = caller(request)
    store = store_of(request)
    target = _require_linked_parent(store, actor, user_id)
    if "\x00" in body.new_password:
        _fail(400, "bad_password", "Das Passwort ist ungültig.")
    try:
        admin_of(request).reset_password_logout_devices(user_id, body.new_password)
    except MatrixCallError as exc:
        logger.info("password reset failed status=%s", exc.status_code)
        _fail(502, "reset_failed", "Das Passwort konnte nicht zurückgesetzt werden.")
    return {
        "user_id": target["user_id"],
        "mxid_unchanged": True,
        "devices_logged_out": True,
        "device_authorizations_kept": True,
        "recovery_key_returned": False,
        "cross_signing_reset": False,
        "message_keys_returned": False,
    }


@app.get("/_hoobird/v1/directory/{username}")
def lookup_username(username: str, request: Request):
    caller(request)
    folded = fold_username(username)
    account = store_of(request).get_by_username(folded)
    if account is None or account["is_bootstrap"]:
        _fail(404, "not_found", "Nutzername nicht gefunden.")
    return _public_account(account)


@app.get("/_hoobird/v1/directory")
def search_directory(request: Request, q: str = ""):
    caller(request)
    folded = fold_username(q)
    if len(folded) < 2 or not valid_username(folded) and not re.fullmatch(r"[a-z0-9._-]{2,32}", folded):
        _fail(400, "bad_query", "Bitte mindestens zwei Zeichen angeben.")
    return {"results": [_public_account(row) for row in store_of(request).search_usernames(folded)]}


@app.get("/_hoobird/v1/children/{child_id}")
def child_policy(child_id: str, request: Request):
    actor = caller(request)
    store = store_of(request)
    child = store.get_account(child_id)
    if child is None or child["role"] != "child":
        _fail(404, "child_not_found", "Kinderkonto nicht gefunden.")
    if actor["user_id"] != child_id and not store.is_linked_parent(child_id, actor["user_id"]):
        _fail(403, "forbidden", "Diese Kinderrichtlinie ist nicht sichtbar.")
    return _policy_body(store, child)


@app.post("/_hoobird/v1/children/{child_id}/link-codes")
def create_link_code(child_id: str, body: LinkCodeBody, request: Request):
    actor = caller(request)
    store = store_of(request)
    _require_linked_parent(store, actor, child_id)
    ttl = 900
    if body.ttl_seconds is not None:
        if not request.app.state.settings["dev_email_tokens"]:
            _fail(400, "ttl_not_allowed", "Die Gültigkeit ist fest vorgegeben.")
        if not 1 <= body.ttl_seconds <= 900:
            _fail(400, "bad_ttl", "Die Gültigkeit muss zwischen 1 und 900 Sekunden liegen.")
        ttl = body.ttl_seconds
    code = store.create_link_code(child_id, actor["user_id"], ttl)
    return {
        "code": code,
        "ttl_seconds": ttl,
        "proves": "short_lived_shared_secret",
        "does_not_prove": ["guardianship", "proximity", "age"],
        "qr_implemented": False,
    }


@app.post("/_hoobird/v1/children/{child_id}/parents")
def redeem_parent(child_id: str, body: RedeemBody, request: Request):
    actor = caller(request)
    store = store_of(request)
    child = store.get_account(child_id)
    if child is None or child["role"] != "child":
        _fail(404, "child_not_found", "Kinderkonto nicht gefunden.")
    if actor["role"] != "parent" or actor["is_bootstrap"]:
        _fail(403, "parent_account_required", "Nur ein bestehendes Elternkonto kann sich verknüpfen.")
    if not can_add_parent(store.parent_count(child_id)):
        _fail(409, "parent_limit", "Es sind bereits zwei Elternkonten verknüpft.")
    result = store.redeem_link_code(child_id, actor["user_id"], body.code.strip())
    messages = {
        "bad_code": (400, "Der Verknüpfungscode ist ungültig."),
        "consumed": (400, "Der Verknüpfungscode wurde schon benutzt."),
        "expired": (400, "Der Verknüpfungscode ist abgelaufen."),
        "parent_limit": (409, "Es sind bereits zwei Elternkonten verknüpft."),
        "already_linked": (409, "Dieses Elternkonto ist schon verknüpft."),
    }
    if result != "ok":
        status, message = messages[result]
        _fail(status, result, message)
    return {"child_user_id": child_id, "parents": store.parents_of(child_id), "guardianship_proven": False}


@app.post("/_hoobird/v1/children/{child_id}/approvals")
def approve_contact(child_id: str, body: ContactBody, request: Request):
    actor = caller(request)
    store = store_of(request)
    _require_linked_parent(store, actor, child_id)
    contact = _contact(store, child_id, body.contact_user_id)
    if store.is_linked_parent(child_id, contact["user_id"]):
        _fail(409, "parent_implicit", "Verknüpfte Eltern sind bereits erlaubt und brauchen keine Freigabe.")
    store.add_approval(child_id, contact["user_id"], actor["user_id"])
    facts = _facts(store, child_id, contact["user_id"])
    return {
        "contact_user_id": contact["user_id"],
        "approval_stored": True,
        "effective": contact_allowed(facts),
        "blocked_by": sorted(facts.blocked_by),
        "block_overrides_approval": bool(facts.blocked_by),
    }


@app.delete("/_hoobird/v1/children/{child_id}/approvals/{contact_user_id}")
def revoke_approval(child_id: str, contact_user_id: str, request: Request):
    actor = caller(request)
    store = store_of(request)
    _require_linked_parent(store, actor, child_id)
    if not store.delete_approval(child_id, contact_user_id):
        _fail(404, "approval_missing", "Keine Freigabe für diesen Kontakt.")
    return {"revoked": True, "effective": contact_allowed(_facts(store, child_id, contact_user_id))}


@app.post("/_hoobird/v1/children/{child_id}/blocks")
def block_contact(child_id: str, body: ContactBody, request: Request):
    actor = caller(request)
    store = store_of(request)
    _require_linked_parent(store, actor, child_id)
    contact = _contact(store, child_id, body.contact_user_id)
    if store.is_linked_parent(child_id, contact["user_id"]):
        _fail(400, "cannot_block_parent", "Ein verknüpftes Elternkonto kann hier nicht blockiert werden.")
    store.add_block(child_id, contact["user_id"], actor["user_id"])
    repair = admin_of(request).reconcile_block(child_id, contact["user_id"])
    return {
        "blocked_by": sorted(store.blocks_for(child_id, contact["user_id"])),
        "effective": False,
        "reapproval_does_not_lift": True,
        "reconcile": repair,
    }


@app.post("/_hoobird/v1/children/{child_id}/blocks/{contact_user_id}/reconcile")
def reconcile_block(child_id: str, contact_user_id: str, request: Request):
    actor = caller(request)
    store = store_of(request)
    _require_linked_parent(store, actor, child_id)
    if not store.blocks_for(child_id, contact_user_id):
        _fail(404, "block_missing", "Keine Sperre für diesen Kontakt.")
    return admin_of(request).reconcile_block(child_id, contact_user_id)


@app.delete("/_hoobird/v1/children/{child_id}/blocks/{contact_user_id}")
def lift_block(child_id: str, contact_user_id: str, request: Request):
    actor = caller(request)
    store = store_of(request)
    _require_linked_parent(store, actor, child_id)
    blocked_by = store.blocks_for(child_id, contact_user_id)
    if not blocked_by:
        _fail(404, "block_missing", "Keine Sperre für diesen Kontakt.")
    if not can_lift_block(actor["user_id"], frozenset(blocked_by)):
        _fail(403, "block_not_owner", "Nur das Elternkonto, das gesperrt hat, kann diese Sperre aufheben.")
    store.delete_block(child_id, contact_user_id, actor["user_id"])
    facts = _facts(store, child_id, contact_user_id)
    return {
        "remaining_blocked_by": sorted(facts.blocked_by),
        "effective": contact_allowed(facts),
    }


@app.post("/_hoobird/v1/children/{child_id}/devices")
def authorize_device(child_id: str, body: DeviceBody, request: Request):
    actor = caller(request)
    store = store_of(request)
    _require_linked_parent(store, actor, child_id)
    if not valid_device_id(body.device_id):
        _fail(400, "bad_device", "Die Gerätekennung ist ungültig.")
    if not valid_ed25519(body.ed25519):
        _fail(400, "fingerprint_required", "Die ed25519-Kennung des Geräts fehlt oder ist ungültig.")
    outcome = store.authorize_device(child_id, body.device_id, actor["user_id"], body.ed25519)
    if outcome == "conflict":
        _fail(
            409,
            "fingerprint_conflict",
            "Für diese Gerätekennung ist schon ein anderer Schlüssel gespeichert. Ein anderes Elternteil ersetzt ihn nicht.",
        )
    return {
        "device_id": body.device_id,
        "authorized": True,
        "binds_key_fingerprint": True,
        "one_parent_sufficient": True,
        "stored": outcome,
    }


@app.delete("/_hoobird/v1/children/{child_id}/devices/{device_id}")
def revoke_device(child_id: str, device_id: str, request: Request):
    actor = caller(request)
    store = store_of(request)
    _require_linked_parent(store, actor, child_id)
    store.revoke_device(child_id, device_id)
    try:
        admin_of(request).delete_device(child_id, device_id)
    except MatrixCallError as exc:
        logger.info("device delete failed status=%s", exc.status_code)
        _fail(502, "device_delete_failed", "Die Synapse-Sitzung konnte nicht gelöscht werden.")
    return {"device_id": device_id, "authorized": False, "synapse_device_deleted": True}


def _contact(store: PolicyStore, child_id: str, contact_user_id: str) -> dict:
    if contact_user_id == child_id:
        _fail(400, "self_contact", "Das Kinderkonto kann nicht sein eigener Kontakt sein.")
    contact = store.get_account(contact_user_id)
    if contact is None or contact["is_bootstrap"]:
        _fail(404, "contact_not_found", "Kontaktkonto nicht gefunden.")
    return contact


def _facts(store: PolicyStore, child_id: str, contact_user_id: str) -> ContactFacts:
    approvals = {
        row["contact_user_id"]: row["approved_by"] for row in store.list_approvals(child_id)
    }
    return ContactFacts(
        is_linked_parent=store.is_linked_parent(child_id, contact_user_id),
        blocked_by=frozenset(store.blocks_for(child_id, contact_user_id)),
        approved_by=approvals.get(contact_user_id),
    )


def _policy_body(store: PolicyStore, child: dict) -> dict:
    child_id = child["user_id"]
    contacts = set(store.parents_of(child_id))
    approvals = store.list_approvals(child_id)
    blocks = store.list_blocks(child_id)
    for row in approvals:
        contacts.add(row["contact_user_id"])
    for row in blocks:
        contacts.add(row["contact_user_id"])
    effective = []
    for contact_id in sorted(contacts):
        facts = _facts(store, child_id, contact_id)
        account = store.get_account(contact_id)
        effective.append(
            {
                "user_id": contact_id,
                "username": account["username"] if account else None,
                "effective": contact_allowed(facts),
                "linked_parent": facts.is_linked_parent,
                "approved_by": facts.approved_by,
                "blocked_by": sorted(facts.blocked_by),
            }
        )
    return {
        "child": _public_account(child),
        "parents": store.parents_of(child_id),
        "contacts": effective,
        "devices": store.list_devices(child_id),
        "messages_included": False,
        "keys_included": False,
    }
