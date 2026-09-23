import asyncio
from datetime import UTC, datetime, timedelta
from uuid import UUID

from fastapi.testclient import TestClient

from app.core.security import create_access_token
from app.main import app
from app.models.payment import Payment
from app.models.user import User
from tests.conftest import TestingSessionLocal

client = TestClient(app)


def _token(phone: str, role: str = "client", name: str = "User") -> str:
    r = client.post("/api/v1/auth/request-otp", json={"phone": phone})
    otp = r.json()["otp"]
    v = client.post("/api/v1/auth/verify-otp", json={"phone": phone, "otp": otp, "name": name, "role": role})
    return v.json()["access_token"]


def _uid(token: str) -> str:
    return client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"}).json()["id"]


def _create_booking(client_token: str, craftsman_id: str) -> str:
    resp = client.post(
        "/api/v1/bookings/",
        headers={"Authorization": f"Bearer {client_token}"},
        json={
            "craftsman_id": craftsman_id,
            "trade": "plumber",
            "description": "Payment test booking with enough description for validation",
            "address": "Algiers",
            "scheduled_at": (datetime.now(UTC) + timedelta(days=1)).isoformat(),
        },
    )
    return resp.json()["id"]


def _accept_and_complete(client_token: str, craftsman_token: str, bid: str) -> None:
    client.patch(f"/api/v1/bookings/{bid}/status", headers={"Authorization": f"Bearer {craftsman_token}"}, json={"action": "accept"})
    client.patch(f"/api/v1/bookings/{bid}/status", headers={"Authorization": f"Bearer {craftsman_token}"}, json={"action": "schedule"})
    client.patch(f"/api/v1/bookings/{bid}/status", headers={"Authorization": f"Bearer {craftsman_token}"}, json={"action": "start"})
    client.patch(f"/api/v1/bookings/{bid}/status", headers={"Authorization": f"Bearer {craftsman_token}"}, json={"action": "complete"})


def _create_admin_token() -> str:
    async def _create() -> str:
        async with TestingSessionLocal() as sess:
            from sqlalchemy import select

            res = await sess.execute(select(User).where(User.phone == "+213555999999"))
            user = res.scalar_one_or_none()
            if user is None:
                user = User(phone="+213555999999", role="admin", name="Admin", language_pref="fr", is_verified=True)
                sess.add(user)
                await sess.commit()
                await sess.refresh(user)
            return create_access_token(subject=str(user.id))

    return asyncio.run(_create())


def test_checkout_creation_and_validation() -> None:
    c_token = _token("+213555700001")
    cr_token = _token("+213555700002", role="craftsman")
    cr_id = _uid(cr_token)
    bid = _create_booking(c_token, cr_id)
    # cannot checkout while requested
    resp = client.post("/api/v1/payments/checkouts", headers={"Authorization": f"Bearer {c_token}"}, json={"booking_id": bid, "amount": 5000})
    assert resp.status_code == 400
    # accept
    client.patch(f"/api/v1/bookings/{bid}/status", headers={"Authorization": f"Bearer {cr_token}"}, json={"action": "accept"})
    resp2 = client.post("/api/v1/payments/checkouts", headers={"Authorization": f"Bearer {c_token}"}, json={"booking_id": bid, "amount": 5000})
    assert resp2.status_code == 201
    data = resp2.json()
    assert data["checkout_url"].startswith("https://pay.chargily.net/test/checkout/")
    assert data["status"] == "pending"
    # duplicate checkout fails
    resp3 = client.post("/api/v1/payments/checkouts", headers={"Authorization": f"Bearer {c_token}"}, json={"booking_id": bid, "amount": 5000})
    assert resp3.status_code == 400
    # craftsman cannot create checkout for same booking
    resp4 = client.post("/api/v1/payments/checkouts", headers={"Authorization": f"Bearer {cr_token}"}, json={"booking_id": bid, "amount": 5000})
    assert resp4.status_code == 403


def test_webhook_idempotency_and_held() -> None:
    c_token = _token("+213555700003")
    cr_token = _token("+213555700004", role="craftsman")
    cr_id = _uid(cr_token)
    bid = _create_booking(c_token, cr_id)
    client.patch(f"/api/v1/bookings/{bid}/status", headers={"Authorization": f"Bearer {cr_token}"}, json={"action": "accept"})
    checkout = client.post("/api/v1/payments/checkouts", headers={"Authorization": f"Bearer {c_token}"}, json={"booking_id": bid, "amount": 7000}).json()
    checkout_id = checkout["checkout_id"]
    payment_id = checkout["payment_id"]

    # webhook paid -> held
    event_id = "evt_test_001"
    resp = client.post("/api/v1/payments/webhook/chargily", json={"event_id": event_id, "type": "checkout.paid", "data": {"checkout_id": checkout_id}})
    assert resp.status_code == 200
    assert resp.json()["status"] == "processed"
    # check payment held
    pay = client.get(f"/api/v1/payments/{payment_id}", headers={"Authorization": f"Bearer {c_token}"}).json()
    assert pay["status"] == "held"
    assert pay["gateway_checkout_id"] == checkout_id

    # replay same event_id -> idempotent
    resp2 = client.post("/api/v1/payments/webhook/chargily", json={"event_id": event_id, "type": "checkout.paid", "data": {"checkout_id": checkout_id}})
    assert resp2.json()["status"] == "already_processed"
    # payment still held, not double
    pay2 = client.get(f"/api/v1/payments/{payment_id}", headers={"Authorization": f"Bearer {c_token}"}).json()
    assert pay2["status"] == "held"

    # unknown checkout -> unknown_checkout but still recorded
    resp3 = client.post("/api/v1/payments/webhook/chargily", json={"event_id": "evt_unknown_001", "type": "checkout.paid", "data": {"checkout_id": "chk_unknown_xyz"}})
    assert resp3.json()["status"] == "unknown_checkout"
    # replay unknown -> already_processed
    resp4 = client.post("/api/v1/payments/webhook/chargily", json={"event_id": "evt_unknown_001", "type": "checkout.paid", "data": {"checkout_id": "chk_unknown_xyz"}})
    assert resp4.json()["status"] == "already_processed"


def test_webhook_refund_path() -> None:
    c_token = _token("+213555700005")
    cr_token = _token("+213555700006", role="craftsman")
    cr_id = _uid(cr_token)
    bid = _create_booking(c_token, cr_id)
    client.patch(f"/api/v1/bookings/{bid}/status", headers={"Authorization": f"Bearer {cr_token}"}, json={"action": "accept"})
    chk = client.post("/api/v1/payments/checkouts", headers={"Authorization": f"Bearer {c_token}"}, json={"booking_id": bid, "amount": 8000}).json()
    checkout_id = chk["checkout_id"]
    payment_id = chk["payment_id"]
    # failed webhook -> refunded
    resp = client.post("/api/v1/payments/webhook/chargily", json={"event_id": "evt_fail_001", "type": "checkout.failed", "data": {"checkout_id": checkout_id}})
    assert resp.json()["status"] == "processed"
    pay = client.get(f"/api/v1/payments/{payment_id}", headers={"Authorization": f"Bearer {c_token}"}).json()
    assert pay["status"] == "refunded"
    # refund via webhook after held
    # create another payment
    bid2 = _create_booking(c_token, cr_id)
    client.patch(f"/api/v1/bookings/{bid2}/status", headers={"Authorization": f"Bearer {cr_token}"}, json={"action": "accept"})
    chk2 = client.post("/api/v1/payments/checkouts", headers={"Authorization": f"Bearer {c_token}"}, json={"booking_id": bid2, "amount": 9000}).json()
    client.post("/api/v1/payments/webhook/chargily", json={"event_id": "evt_paid_002", "type": "checkout.paid", "data": {"checkout_id": chk2["checkout_id"]}})
    # now refund
    client.post("/api/v1/payments/webhook/chargily", json={"event_id": "evt_refund_001", "type": "payment.refunded", "data": {"checkout_id": chk2["checkout_id"]}})
    pay2 = client.get(f"/api/v1/payments/{chk2['payment_id']}", headers={"Authorization": f"Bearer {c_token}"}).json()
    assert pay2["status"] == "refunded"


def test_release_and_dispute_freeze() -> None:
    c_token = _token("+213555700007")
    cr_token = _token("+213555700008", role="craftsman")
    cr_id = _uid(cr_token)
    bid = _create_booking(c_token, cr_id)
    _accept_and_complete(c_token, cr_token, bid)
    chk = client.post("/api/v1/payments/checkouts", headers={"Authorization": f"Bearer {c_token}"}, json={"booking_id": bid, "amount": 10000}).json()
    payment_id = chk["payment_id"]
    checkout_id = chk["checkout_id"]
    client.post("/api/v1/payments/webhook/chargily", json={"event_id": "evt_rel_001", "type": "checkout.paid", "data": {"checkout_id": checkout_id}})
    # try release before completed? already completed, so ok
    # craftsman cannot release
    resp_craft = client.post(f"/api/v1/payments/{payment_id}/release", headers={"Authorization": f"Bearer {cr_token}"})
    assert resp_craft.status_code == 403
    # client can release
    resp = client.post(f"/api/v1/payments/{payment_id}/release", headers={"Authorization": f"Bearer {c_token}"})
    assert resp.status_code == 200
    assert resp.json()["status"] == "released"
    # double release fails
    resp2 = client.post(f"/api/v1/payments/{payment_id}/release", headers={"Authorization": f"Bearer {c_token}"})
    assert resp2.status_code == 400
    # dispute after released fails
    resp3 = client.post(f"/api/v1/payments/{payment_id}/dispute", headers={"Authorization": f"Bearer {c_token}"}, json={"reason": "bad work"})
    assert resp3.status_code == 400

    # dispute freezes
    bid2 = _create_booking(c_token, cr_id)
    _accept_and_complete(c_token, cr_token, bid2)
    chk2 = client.post("/api/v1/payments/checkouts", headers={"Authorization": f"Bearer {c_token}"}, json={"booking_id": bid2, "amount": 11000}).json()
    client.post("/api/v1/payments/webhook/chargily", json={"event_id": "evt_disp_001", "type": "checkout.paid", "data": {"checkout_id": chk2["checkout_id"]}})
    pid2 = chk2["payment_id"]
    resp4 = client.post(f"/api/v1/payments/{pid2}/dispute", headers={"Authorization": f"Bearer {c_token}"}, json={"reason": "not as described"})
    assert resp4.status_code == 200
    assert resp4.json()["status"] == "disputed"
    # check payment disputed
    pay = client.get(f"/api/v1/payments/{pid2}", headers={"Authorization": f"Bearer {c_token}"}).json()
    assert pay["status"] == "disputed"
    # release after disputed fails
    resp5 = client.post(f"/api/v1/payments/{pid2}/release", headers={"Authorization": f"Bearer {c_token}"})
    assert resp5.status_code == 400
    # admin can see dispute
    admin_token = _create_admin_token()
    resp6 = client.get("/api/v1/admin/disputes", headers={"Authorization": f"Bearer {admin_token}"})
    assert any(d["payment_id"] == pid2 for d in resp6.json())
    # admin can refund disputed
    resp7 = client.post(f"/api/v1/payments/{pid2}/refund", headers={"Authorization": f"Bearer {admin_token}"})
    assert resp7.status_code == 200
    assert resp7.json()["status"] == "refunded"


def test_payout_view() -> None:
    c_token = _token("+213555700009")
    cr_token = _token("+213555700010", role="craftsman")
    cr_id = _uid(cr_token)
    # craftsman payout view requires craftsman role
    resp_forbidden = client.get("/api/v1/payments/payouts/me", headers={"Authorization": f"Bearer {c_token}"})
    assert resp_forbidden.status_code == 403
    # create and release a payment to have pending
    bid = _create_booking(c_token, cr_id)
    _accept_and_complete(c_token, cr_token, bid)
    chk = client.post("/api/v1/payments/checkouts", headers={"Authorization": f"Bearer {c_token}"}, json={"booking_id": bid, "amount": 12000}).json()
    client.post("/api/v1/payments/webhook/chargily", json={"event_id": "evt_payout_001", "type": "checkout.paid", "data": {"checkout_id": chk["checkout_id"]}})
    client.post(f"/api/v1/payments/{chk['payment_id']}/release", headers={"Authorization": f"Bearer {c_token}"})
    resp = client.get("/api/v1/payments/payouts/me", headers={"Authorization": f"Bearer {cr_token}"})
    assert resp.status_code == 200
    data = resp.json()
    assert "pending_amount" in data
    assert "released_amount" in data
    assert data["pending_amount"] >= 12000
    assert len(data["history"]) >= 1


def test_auto_release_job() -> None:
    c_token = _token("+213555700011")
    cr_token = _token("+213555700012", role="craftsman")
    cr_id = _uid(cr_token)
    bid = _create_booking(c_token, cr_id)
    _accept_and_complete(c_token, cr_token, bid)
    chk = client.post("/api/v1/payments/checkouts", headers={"Authorization": f"Bearer {c_token}"}, json={"booking_id": bid, "amount": 13000}).json()
    payment_id = chk["payment_id"]
    checkout_id = chk["checkout_id"]
    client.post("/api/v1/payments/webhook/chargily", json={"event_id": "evt_auto_001", "type": "checkout.paid", "data": {"checkout_id": checkout_id}})
    # Manually set held_at to 8 days ago (past deadline)
    async def _adjust() -> None:
        from sqlalchemy import select

        async with TestingSessionLocal() as sess:
            res = await sess.execute(select(Payment).where(Payment.id == UUID(payment_id)))
            p = res.scalar_one()
            p.held_at = datetime.now(UTC) - timedelta(days=8)
            await sess.commit()

    asyncio.run(_adjust())
    # Run auto-release
    from app.modules.payments.tasks import auto_release_expired_payments

    async def _run_auto() -> list[str]:
        async with TestingSessionLocal() as sess:
            return await auto_release_expired_payments(sess)

    released = asyncio.run(_run_auto())
    assert payment_id in released
    pay = client.get(f"/api/v1/payments/{payment_id}", headers={"Authorization": f"Bearer {c_token}"}).json()
    assert pay["status"] == "released"

    # Test not yet deadline (6 days) not released
    bid2 = _create_booking(c_token, cr_id)
    _accept_and_complete(c_token, cr_token, bid2)
    chk2 = client.post("/api/v1/payments/checkouts", headers={"Authorization": f"Bearer {c_token}"}, json={"booking_id": bid2, "amount": 14000}).json()
    client.post("/api/v1/payments/webhook/chargily", json={"event_id": "evt_auto_002", "type": "checkout.paid", "data": {"checkout_id": chk2["checkout_id"]}})

    async def _adjust2() -> None:
        from sqlalchemy import select

        async with TestingSessionLocal() as sess:
            res = await sess.execute(select(Payment).where(Payment.id == UUID(chk2["payment_id"])))
            p = res.scalar_one()
            p.held_at = datetime.now(UTC) - timedelta(days=6)
            await sess.commit()

    asyncio.run(_adjust2())
    released2 = asyncio.run(_run_auto())
    assert chk2["payment_id"] not in released2
    pay2 = client.get(f"/api/v1/payments/{chk2['payment_id']}", headers={"Authorization": f"Bearer {c_token}"}).json()
    assert pay2["status"] == "held"

    # Test disputed not auto-released even after deadline
    bid3 = _create_booking(c_token, cr_id)
    _accept_and_complete(c_token, cr_token, bid3)
    chk3 = client.post("/api/v1/payments/checkouts", headers={"Authorization": f"Bearer {c_token}"}, json={"booking_id": bid3, "amount": 15000}).json()
    client.post("/api/v1/payments/webhook/chargily", json={"event_id": "evt_auto_003", "type": "checkout.paid", "data": {"checkout_id": chk3["checkout_id"]}})
    client.post(f"/api/v1/payments/{chk3['payment_id']}/dispute", headers={"Authorization": f"Bearer {c_token}"}, json={"reason": "dispute"})

    async def _adjust3() -> None:
        from sqlalchemy import select

        async with TestingSessionLocal() as sess:
            res = await sess.execute(select(Payment).where(Payment.id == UUID(chk3["payment_id"])))
            p = res.scalar_one()
            p.held_at = datetime.now(UTC) - timedelta(days=8)
            await sess.commit()

    asyncio.run(_adjust3())
    released3 = asyncio.run(_run_auto())
    assert chk3["payment_id"] not in released3
    pay3 = client.get(f"/api/v1/payments/{chk3['payment_id']}", headers={"Authorization": f"Bearer {c_token}"}).json()
    assert pay3["status"] == "disputed"


def test_admin_refund_path() -> None:
    c_token = _token("+213555700013")
    cr_token = _token("+213555700014", role="craftsman")
    cr_id = _uid(cr_token)
    bid = _create_booking(c_token, cr_id)
    client.patch(f"/api/v1/bookings/{bid}/status", headers={"Authorization": f"Bearer {cr_token}"}, json={"action": "accept"})
    chk = client.post("/api/v1/payments/checkouts", headers={"Authorization": f"Bearer {c_token}"}, json={"booking_id": bid, "amount": 16000}).json()
    client.post("/api/v1/payments/webhook/chargily", json={"event_id": "evt_ref_002", "type": "checkout.paid", "data": {"checkout_id": chk["checkout_id"]}})
    admin_token = _create_admin_token()
    # client cannot refund
    resp = client.post(f"/api/v1/payments/{chk['payment_id']}/refund", headers={"Authorization": f"Bearer {c_token}"})
    assert resp.status_code == 403
    # admin can refund held
    resp2 = client.post(f"/api/v1/payments/{chk['payment_id']}/refund", headers={"Authorization": f"Bearer {admin_token}"})
    assert resp2.status_code == 200
    assert resp2.json()["status"] == "refunded"
