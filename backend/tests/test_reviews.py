from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient

from app.main import app

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
            "description": "Need plumber for review test booking with enough description",
            "address": "Algiers 123",
            "scheduled_at": (datetime.now(UTC) + timedelta(days=1)).isoformat(),
        },
    )
    return resp.json()["id"]


def _complete_booking(client_token: str, craftsman_token: str, booking_id: str) -> None:
    # craftsman accepts -> scheduled -> start -> complete
    client.patch(f"/api/v1/bookings/{booking_id}/status", headers={"Authorization": f"Bearer {craftsman_token}"}, json={"action": "accept"})
    client.patch(f"/api/v1/bookings/{booking_id}/status", headers={"Authorization": f"Bearer {craftsman_token}"}, json={"action": "schedule"})
    client.patch(f"/api/v1/bookings/{booking_id}/status", headers={"Authorization": f"Bearer {craftsman_token}"}, json={"action": "start"})
    client.patch(f"/api/v1/bookings/{booking_id}/status", headers={"Authorization": f"Bearer {craftsman_token}"}, json={"action": "complete"})


def test_review_requires_completed() -> None:
    c_token = _token("+213555500001")
    cr_token = _token("+213555500002", role="craftsman")
    cr_id = _uid(cr_token)
    client.patch(
        "/api/v1/users/me", headers={"Authorization": f"Bearer {cr_token}"}, json={"craftsman_profile": {"trades": ["plumber"]}}
    )
    bid = _create_booking(c_token, cr_id)
    # try review before completed
    resp = client.post("/api/v1/reviews/", headers={"Authorization": f"Bearer {c_token}"}, json={"booking_id": bid, "rating": 5})
    assert resp.status_code == 400
    assert "completed" in resp.json()["detail"].lower()


def test_review_success_and_rating_avg() -> None:
    c_token = _token("+213555500003")
    cr_token = _token("+213555500004", role="craftsman")
    cr_id = _uid(cr_token)
    client.patch("/api/v1/users/me", headers={"Authorization": f"Bearer {cr_token}"}, json={"craftsman_profile": {"trades": ["review-trade"], "hourly_rate": 1000}})
    bid = _create_booking(c_token, cr_id)
    _complete_booking(c_token, cr_token, bid)
    resp = client.post("/api/v1/reviews/", headers={"Authorization": f"Bearer {c_token}"}, json={"booking_id": bid, "rating": 5, "comment": "Excellent work"})
    assert resp.status_code == 201
    assert resp.json()["rating"] == 5
    # rating_avg should be 5
    me = client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {cr_token}"}).json()
    assert me["craftsman_profile"]["rating_avg"] == 5.0
    # second review on same booking fails (duplicate)
    resp2 = client.post("/api/v1/reviews/", headers={"Authorization": f"Bearer {c_token}"}, json={"booking_id": bid, "rating": 4})
    assert resp2.status_code == 400
    # second booking with 3 rating should average to 4
    bid2 = _create_booking(c_token, cr_id)
    _complete_booking(c_token, cr_token, bid2)
    client.post("/api/v1/reviews/", headers={"Authorization": f"Bearer {c_token}"}, json={"booking_id": bid2, "rating": 3})
    me2 = client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {cr_token}"}).json()
    assert me2["craftsman_profile"]["rating_avg"] == 4.0
    # discovery filter min_rating
    search = client.get("/api/v1/discovery/search", params={"trade": "review-trade", "min_rating": 4}).json()
    assert search["total"] >= 1
    search2 = client.get("/api/v1/discovery/search", params={"trade": "review-trade", "min_rating": 5}).json()
    # after avg 4, should not appear with min 5
    assert search2["total"] == 0


def test_review_only_client_can_review() -> None:
    c_token = _token("+213555500005")
    cr_token = _token("+213555500006", role="craftsman")
    other_token = _token("+213555500007")
    cr_id = _uid(cr_token)
    bid = _create_booking(c_token, cr_id)
    _complete_booking(c_token, cr_token, bid)
    # craftsman tries to review own booking
    resp = client.post("/api/v1/reviews/", headers={"Authorization": f"Bearer {cr_token}"}, json={"booking_id": bid, "rating": 5})
    assert resp.status_code == 403
    # other client not participant
    resp2 = client.post("/api/v1/reviews/", headers={"Authorization": f"Bearer {other_token}"}, json={"booking_id": bid, "rating": 5})
    assert resp2.status_code == 403


def test_review_validation() -> None:
    c_token = _token("+213555500008")
    cr_token = _token("+213555500009", role="craftsman")
    cr_id = _uid(cr_token)
    bid = _create_booking(c_token, cr_id)
    _complete_booking(c_token, cr_token, bid)
    resp = client.post("/api/v1/reviews/", headers={"Authorization": f"Bearer {c_token}"}, json={"booking_id": bid, "rating": 6})
    assert resp.status_code == 422
    resp2 = client.post("/api/v1/reviews/", headers={"Authorization": f"Bearer {c_token}"}, json={"booking_id": bid, "rating": 0})
    assert resp2.status_code == 422
    resp3 = client.post("/api/v1/reviews/", headers={"Authorization": f"Bearer {c_token}"}, json={"booking_id": "00000000-0000-0000-0000-000000000000", "rating": 5})
    assert resp3.status_code == 404


def test_review_list() -> None:
    c_token = _token("+213555500010")
    cr_token = _token("+213555500011", role="craftsman")
    cr_id = _uid(cr_token)
    client.patch("/api/v1/users/me", headers={"Authorization": f"Bearer {cr_token}"}, json={"craftsman_profile": {"trades": ["list-review-trade"]}})
    bid = _create_booking(c_token, cr_id)
    _complete_booking(c_token, cr_token, bid)
    client.post("/api/v1/reviews/", headers={"Authorization": f"Bearer {c_token}"}, json={"booking_id": bid, "rating": 4, "comment": "ok"})
    resp = client.get("/api/v1/reviews/", params={"craftsman_id": cr_id})
    assert resp.status_code == 200
    assert len(resp.json()) >= 1
    resp2 = client.get(f"/api/v1/reviews/booking/{bid}")
    assert resp2.status_code == 200
    assert resp2.json()["booking_id"] == bid
    resp3 = client.get("/api/v1/reviews/", params={"booking_id": bid})
    assert len(resp3.json()) == 1


def test_review_requires_auth() -> None:
    resp = client.post("/api/v1/reviews/", json={"booking_id": "00000000-0000-0000-0000-000000000000", "rating": 5})
    assert resp.status_code == 401
