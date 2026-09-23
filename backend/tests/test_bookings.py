from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _token(phone: str, role: str = "client", name: str = "User") -> str:
    r = client.post("/api/v1/auth/request-otp", json={"phone": phone})
    otp = r.json()["otp"]
    v = client.post("/api/v1/auth/verify-otp", json={"phone": phone, "otp": otp, "name": name, "role": role})
    return v.json()["access_token"]


def _auth_header(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def _user_id(token: str) -> str:
    me = client.get("/api/v1/auth/me", headers=_auth_header(token)).json()
    return me["id"]


def test_create_booking_requires_auth() -> None:
    resp = client.post("/api/v1/bookings/", json={})
    assert resp.status_code == 401


def test_create_booking_validation() -> None:
    token = _token("+213555300001")
    craftsman_token = _token("+213555300002", role="craftsman")
    craftsman_id = _user_id(craftsman_token)

    # missing fields
    resp = client.post("/api/v1/bookings/", headers=_auth_header(token), json={})
    assert resp.status_code == 422

    # short description
    resp2 = client.post(
        "/api/v1/bookings/",
        headers=_auth_header(token),
        json={
            "craftsman_id": craftsman_id,
            "trade": "plumber",
            "description": "short",
            "address": "Algiers",
            "scheduled_at": (datetime.now(UTC) + timedelta(days=1)).isoformat(),
        },
    )
    assert resp2.status_code == 422

    # invalid craftsman not found
    resp3 = client.post(
        "/api/v1/bookings/",
        headers=_auth_header(token),
        json={
            "craftsman_id": "00000000-0000-0000-0000-000000000000",
            "trade": "plumber",
            "description": "Need plumber for kitchen sink repair urgently",
            "address": "Algiers, Rue 123",
            "scheduled_at": (datetime.now(UTC) + timedelta(days=1)).isoformat(),
        },
    )
    assert resp3.status_code == 404


def test_create_booking_success_and_list() -> None:
    client_token = _token("+213555300003")
    craftsman_token = _token("+213555300004", role="craftsman")
    craftsman_id = _user_id(craftsman_token)

    resp = client.post(
        "/api/v1/bookings/",
        headers=_auth_header(client_token),
        json={
            "craftsman_id": craftsman_id,
            "trade": "MyCustomTrade",
            "description": "Need help with custom trade work for home renovation",
            "address": "123 Rue d'Alger, Algiers",
            "scheduled_at": (datetime.now(UTC) + timedelta(days=2)).isoformat(),
        },
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["trade"] == "mycustomtrade"  # lowercased free-form
    assert data["status"] == "requested"

    # list as client
    resp2 = client.get("/api/v1/bookings/", headers=_auth_header(client_token))
    assert resp2.status_code == 200
    assert any(b["id"] == data["id"] for b in resp2.json())

    # get by id as craftsman
    resp3 = client.get(f"/api/v1/bookings/{data['id']}", headers=_auth_header(craftsman_token))
    assert resp3.status_code == 200

    # forbidden for third user
    third = _token("+213555300005")
    resp4 = client.get(f"/api/v1/bookings/{data['id']}", headers=_auth_header(third))
    assert resp4.status_code == 403


def test_booking_self_booking_fails() -> None:
    token = _token("+213555300006", role="craftsman")
    uid = _user_id(token)
    resp = client.post(
        "/api/v1/bookings/",
        headers=_auth_header(token),
        json={
            "craftsman_id": uid,
            "trade": "plumber",
            "description": "Self booking attempt should fail for test case",
            "address": "Algiers",
            "scheduled_at": (datetime.now(UTC) + timedelta(days=1)).isoformat(),
        },
    )
    assert resp.status_code == 400


def test_booking_state_machine() -> None:
    client_token = _token("+213555300007")
    craftsman_token = _token("+213555300008", role="craftsman")
    craftsman_id = _user_id(craftsman_token)

    resp = client.post(
        "/api/v1/bookings/",
        headers=_auth_header(client_token),
        json={
            "craftsman_id": craftsman_id,
            "trade": "electrician",
            "description": "Need electrician for wiring check in apartment",
            "address": "Algiers",
            "scheduled_at": (datetime.now(UTC) + timedelta(days=1)).isoformat(),
        },
    )
    bid = resp.json()["id"]

    # client cannot accept
    resp2 = client.patch(f"/api/v1/bookings/{bid}/status", headers=_auth_header(client_token), json={"action": "accept"})
    assert resp2.status_code == 403

    # craftsman accepts
    resp3 = client.patch(f"/api/v1/bookings/{bid}/status", headers=_auth_header(craftsman_token), json={"action": "accept"})
    assert resp3.status_code == 200
    assert resp3.json()["status"] == "accepted"

    # cannot accept again
    resp4 = client.patch(f"/api/v1/bookings/{bid}/status", headers=_auth_header(craftsman_token), json={"action": "accept"})
    assert resp4.status_code == 400

    # schedule
    resp5 = client.patch(f"/api/v1/bookings/{bid}/status", headers=_auth_header(craftsman_token), json={"action": "schedule"})
    assert resp5.status_code == 200
    assert resp5.json()["status"] == "scheduled"

    # client cancels scheduled
    resp6 = client.patch(f"/api/v1/bookings/{bid}/status", headers=_auth_header(client_token), json={"action": "cancel"})
    assert resp6.status_code == 200
    assert resp6.json()["status"] == "cancelled"


def test_booking_decline_flow() -> None:
    c1 = _token("+213555300009")
    cr = _token("+213555300010", role="craftsman")
    cid = _user_id(cr)
    bid = client.post(
        "/api/v1/bookings/",
        headers=_auth_header(c1),
        json={
            "craftsman_id": cid,
            "trade": "painter",
            "description": "Need painter for living room walls repaint",
            "address": "Algiers",
            "scheduled_at": (datetime.now(UTC) + timedelta(days=1)).isoformat(),
        },
    ).json()["id"]
    resp = client.patch(f"/api/v1/bookings/{bid}/status", headers=_auth_header(cr), json={"action": "decline"})
    assert resp.status_code == 200
    assert resp.json()["status"] == "declined"
    # cannot schedule after declined
    resp2 = client.patch(f"/api/v1/bookings/{bid}/status", headers=_auth_header(cr), json={"action": "schedule"})
    assert resp2.status_code == 400


def test_booking_not_found_and_auth() -> None:
    token = _token("+213555300011")
    resp = client.get("/api/v1/bookings/00000000-0000-0000-0000-000000000000", headers=_auth_header(token))
    assert resp.status_code == 404
    resp2 = client.patch(
        "/api/v1/bookings/00000000-0000-0000-0000-000000000000/status",
        headers=_auth_header(token),
        json={"action": "cancel"},
    )
    assert resp2.status_code == 404
