from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_request_otp_success() -> None:
    resp = client.post("/api/v1/auth/request-otp", json={"phone": "+213555123456"})
    assert resp.status_code == 200
    data = resp.json()
    assert data["phone"] == "+213555123456"
    assert data["expires_in"] == 300
    # In local/debug mode, otp returned
    assert "otp" in data and data["otp"] is not None
    assert len(data["otp"]) == 6


def test_request_otp_invalid_phone() -> None:
    resp = client.post("/api/v1/auth/request-otp", json={"phone": "not-a-phone"})
    assert resp.status_code == 422  # validation via our handler returns 422

    resp2 = client.post("/api/v1/auth/request-otp", json={"phone": "+213123"})
    assert resp2.status_code == 422


def test_request_otp_missing_phone() -> None:
    resp = client.post("/api/v1/auth/request-otp", json={})
    assert resp.status_code == 422


def test_verify_otp_success_creates_user() -> None:
    # request otp
    r = client.post("/api/v1/auth/request-otp", json={"phone": "+213555000001"})
    otp = r.json()["otp"]
    resp = client.post(
        "/api/v1/auth/verify-otp",
        json={"phone": "+213555000001", "otp": otp, "name": "Alice", "role": "client", "language_pref": "fr"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["user"]["phone"] == "+213555000001"
    assert data["user"]["name"] == "Alice"
    assert data["user"]["role"] == "client"
    assert data["user"]["is_verified"] is True

    # me with token
    access = data["access_token"]
    me = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {access}"})
    assert me.status_code == 200
    assert me.json()["phone"] == "+213555000001"


def test_verify_otp_invalid_otp() -> None:
    client.post("/api/v1/auth/request-otp", json={"phone": "+213555000002"})
    resp = client.post("/api/v1/auth/verify-otp", json={"phone": "+213555000002", "otp": "000000"})
    assert resp.status_code == 401


def test_verify_otp_validation() -> None:
    r = client.post("/api/v1/auth/request-otp", json={"phone": "+213555000003"})
    otp = r.json()["otp"]
    # missing otp field
    resp = client.post("/api/v1/auth/verify-otp", json={"phone": "+213555000003"})
    assert resp.status_code == 422
    # short otp
    resp2 = client.post("/api/v1/auth/verify-otp", json={"phone": "+213555000003", "otp": "123"})
    assert resp2.status_code == 422
    # wrong phone format
    resp3 = client.post("/api/v1/auth/verify-otp", json={"phone": "bad", "otp": otp})
    assert resp3.status_code == 422


def test_verify_otp_replay_fails() -> None:
    r = client.post("/api/v1/auth/request-otp", json={"phone": "+213555000004"})
    otp = r.json()["otp"]
    resp1 = client.post("/api/v1/auth/verify-otp", json={"phone": "+213555000004", "otp": otp})
    assert resp1.status_code == 200
    # replay same otp should fail (consumed)
    resp2 = client.post("/api/v1/auth/verify-otp", json={"phone": "+213555000004", "otp": otp})
    assert resp2.status_code == 401


def test_refresh_success_and_invalid() -> None:
    r = client.post("/api/v1/auth/request-otp", json={"phone": "+213555000005"})
    otp = r.json()["otp"]
    v = client.post("/api/v1/auth/verify-otp", json={"phone": "+213555000005", "otp": otp})
    refresh = v.json()["refresh_token"]
    access = v.json()["access_token"]

    # refresh with refresh token
    resp = client.post("/api/v1/auth/refresh", json={"refresh_token": refresh})
    assert resp.status_code == 200
    assert "access_token" in resp.json()

    # refresh with access token should fail (wrong type)
    resp2 = client.post("/api/v1/auth/refresh", json={"refresh_token": access})
    assert resp2.status_code == 401

    # invalid token
    resp3 = client.post("/api/v1/auth/refresh", json={"refresh_token": "invalid"})
    assert resp3.status_code == 401


def test_me_unauthenticated() -> None:
    resp = client.get("/api/v1/auth/me")
    assert resp.status_code == 401
    resp2 = client.get("/api/v1/auth/me", headers={"Authorization": "Bearer invalid"})
    assert resp2.status_code == 401


def test_second_verify_preserves_user() -> None:
    r = client.post("/api/v1/auth/request-otp", json={"phone": "+213555000006"})
    otp = r.json()["otp"]
    v1 = client.post("/api/v1/auth/verify-otp", json={"phone": "+213555000006", "otp": otp, "name": "Bob"})
    uid1 = v1.json()["user"]["id"]
    # request again
    r2 = client.post("/api/v1/auth/request-otp", json={"phone": "+213555000006"})
    otp2 = r2.json()["otp"]
    v2 = client.post("/api/v1/auth/verify-otp", json={"phone": "+213555000006", "otp": otp2})
    assert v2.json()["user"]["id"] == uid1
