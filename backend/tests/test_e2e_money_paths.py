"""Phase 3 end-to-end sandbox verification for money paths.

Full lifecycle per booking through the Chargily sandbox client (no live
credentials): checkout (pending) -> webhook paid (held/escrow) ->
complete -> release (released) / dispute (frozen) -> admin resolve.

Also asserts the Phase 3 wiring: in-app notifications are created for both
participants on booking/payment events, and mutating admin actions write
audit log entries. Human review of money paths is still required before
switching CHARGILY_SANDBOX to false (see README "Production checklist").
"""

import asyncio
from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient
from sqlalchemy import select

from app.core.security import create_access_token
from app.main import app
from app.models.user import User
from tests.conftest import TestingSessionLocal

client = TestClient(app)


def _token(phone: str, role: str = "client") -> str:
    r = client.post("/api/v1/auth/request-otp", json={"phone": phone})
    otp = r.json()["otp"]
    v = client.post("/api/v1/auth/verify-otp", json={"phone": phone, "otp": otp, "name": "E2E", "role": role})
    return v.json()["access_token"]


def _uid(token: str) -> str:
    return client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"}).json()["id"]


def _booking(c_token: str, cr_id: str) -> str:
    resp = client.post(
        "/api/v1/bookings/",
        headers={"Authorization": f"Bearer {c_token}"},
        json={
            "craftsman_id": cr_id,
            "trade": "electrician",
            "description": "E2E full lifecycle booking with enough description",
            "address": "Oran, Algeria",
            "scheduled_at": (datetime.now(UTC) + timedelta(days=1)).isoformat(),
        },
    )
    assert resp.status_code == 201
    return resp.json()["id"]


def _admin_token() -> str:
    async def _create() -> str:
        async with TestingSessionLocal() as sess:
            res = await sess.execute(select(User).where(User.phone == "+213555888888"))
            user = res.scalar_one_or_none()
            if user is None:
                user = User(phone="+213555888888", role="admin", name="E2E Admin", language_pref="fr", is_verified=True)
                sess.add(user)
                await sess.commit()
                await sess.refresh(user)
            return create_access_token(subject=str(user.id))

    return asyncio.run(_create())


def _notifications(token: str) -> list[dict]:
    r = client.get("/api/v1/notifications/", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 200
    return r.json()


def test_e2e_happy_path_release_with_notifications() -> None:
    c_token = _token("+213555810001")
    cr_token = _token("+213555810002", role="craftsman")
    cr_id = _uid(cr_token)
    bid = _booking(c_token, cr_id)

    client.patch(f"/api/v1/bookings/{bid}/status", headers={"Authorization": f"Bearer {cr_token}"}, json={"action": "accept"})
    chk = client.post(
        "/api/v1/payments/checkouts", headers={"Authorization": f"Bearer {c_token}"}, json={"booking_id": bid, "amount": 20000}
    ).json()
    assert chk["status"] == "pending"
    pid, cid = chk["payment_id"], chk["checkout_id"]

    # Sandbox webhook: funds collected -> escrow held.
    w = client.post(
        "/api/v1/payments/webhook/chargily",
        json={"event_id": "evt_e2e_happy_001", "type": "checkout.paid", "data": {"checkout_id": cid}},
    )
    assert w.json()["status"] == "processed"
    assert client.get(f"/api/v1/payments/{pid}", headers={"Authorization": f"Bearer {c_token}"}).json()["status"] == "held"
    # Webhook replay must not double-process.
    w2 = client.post(
        "/api/v1/payments/webhook/chargily",
        json={"event_id": "evt_e2e_happy_001", "type": "checkout.paid", "data": {"checkout_id": cid}},
    )
    assert w2.json()["status"] == "already_processed"

    # Finish the job, then release escrow.
    for action in ("schedule", "start", "complete"):
        client.patch(f"/api/v1/bookings/{bid}/status", headers={"Authorization": f"Bearer {cr_token}"}, json={"action": action})
    rel = client.post(f"/api/v1/payments/{pid}/release", headers={"Authorization": f"Bearer {c_token}"})
    assert rel.status_code == 200
    assert rel.json()["status"] == "released"

    # Phase 3 wiring: both sides got booking + payment notifications (in-app fallback).
    c_types = {n["type"] for n in _notifications(c_token)}
    cr_types = {n["type"] for n in _notifications(cr_token)}
    assert "booking_status" in c_types and "payment_event" in c_types
    assert "booking_status" in cr_types and "payment_event" in cr_types

    # Craftsman payout view reflects the released escrow.
    payouts = client.get("/api/v1/payments/payouts/me", headers={"Authorization": f"Bearer {cr_token}"}).json()
    assert payouts["released_amount"] >= 20000


def test_e2e_dispute_freeze_admin_resolve_audited() -> None:
    c_token = _token("+213555810003")
    cr_token = _token("+213555810004", role="craftsman")
    cr_id = _uid(cr_token)
    bid = _booking(c_token, cr_id)

    for action in ("accept", "schedule", "start", "complete"):
        client.patch(f"/api/v1/bookings/{bid}/status", headers={"Authorization": f"Bearer {cr_token}"}, json={"action": action})
    chk = client.post(
        "/api/v1/payments/checkouts", headers={"Authorization": f"Bearer {c_token}"}, json={"booking_id": bid, "amount": 25000}
    ).json()
    pid, cid = chk["payment_id"], chk["checkout_id"]
    client.post(
        "/api/v1/payments/webhook/chargily",
        json={"event_id": "evt_e2e_disp_001", "type": "checkout.paid", "data": {"checkout_id": cid}},
    )

    # Client disputes: escrow frozen, release blocked.
    d = client.post(f"/api/v1/payments/{pid}/dispute", headers={"Authorization": f"Bearer {c_token}"}, json={"reason": "e2e quality"})
    assert d.json()["status"] == "disputed"
    assert client.post(f"/api/v1/payments/{pid}/release", headers={"Authorization": f"Bearer {c_token}"}).status_code == 400

    # Admin resolves via dispute queue (RBAC: legacy admin has *).
    admin = _admin_token()
    disputes = client.get("/api/v1/admin/disputes", headers={"Authorization": f"Bearer {admin}"}).json()
    match = [x for x in disputes if x["payment_id"] == pid]
    assert len(match) == 1
    res = client.post(f"/api/v1/admin/disputes/{match[0]['id']}/resolve?decision=release", headers={"Authorization": f"Bearer {admin}"})
    assert res.status_code == 200
    assert res.json()["payment_status"] == "released"

    # Mutating admin action was audit-logged.
    logs = client.get("/api/v1/admin/audit-logs", headers={"Authorization": f"Bearer {admin}"}).json()
    assert any(entry["action"] == "dispute.resolve.release" for entry in logs)

    # Client-tier tokens are locked out of admin routes (RBAC).
    assert client.get("/api/v1/admin/disputes", headers={"Authorization": f"Bearer {c_token}"}).status_code == 403
