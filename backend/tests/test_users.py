from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _otp_and_token(phone: str, name: str = "Test", role: str = "client") -> str:
    r = client.post("/api/v1/auth/request-otp", json={"phone": phone})
    otp = r.json()["otp"]
    v = client.post("/api/v1/auth/verify-otp", json={"phone": phone, "otp": otp, "name": name, "role": role})
    return v.json()["access_token"]


def test_get_me_requires_auth() -> None:
    resp = client.get("/api/v1/users/me")
    assert resp.status_code == 401


def test_get_me_success() -> None:
    token = _otp_and_token("+213555100001", "Client A")
    resp = client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 200
    assert resp.json()["phone"] == "+213555100001"
    assert resp.json()["role"] == "client"


def test_patch_me_update_name_and_lang() -> None:
    token = _otp_and_token("+213555100002")
    resp = client.patch(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {token}"},
        json={"name": "Updated Name", "language_pref": "ar"},
    )
    assert resp.status_code == 200
    assert resp.json()["name"] == "Updated Name"
    assert resp.json()["language_pref"] == "ar"


def test_patch_me_craftsman_profile_success() -> None:
    token = _otp_and_token("+213555100003", role="craftsman")
    # first set trades via patch with role already craftsman
    resp = client.patch(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "craftsman_profile": {
                "trades": ["Plumber", "  Electrician  ", "plumber"],
                "bio": "Experienced craftsman",
                "service_radius_km": 20,
                "latitude": 36.7525,
                "longitude": 3.0420,
                "hourly_rate": 1500,
            }
        },
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["role"] == "craftsman"
    assert data["craftsman_profile"] is not None
    # trades lowercased, deduped, free-form not fixed enum
    assert data["craftsman_profile"]["trades"] == ["plumber", "electrician"]
    assert data["craftsman_profile"]["bio"] == "Experienced craftsman"
    assert data["craftsman_profile"]["latitude"] == 36.7525


def test_patch_craftsman_profile_without_craftsman_role_fails() -> None:
    token = _otp_and_token("+213555100004", role="client")
    resp = client.patch(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {token}"},
        json={"craftsman_profile": {"trades": ["painter"]}},
    )
    assert resp.status_code == 400
    assert "Craftsman" in resp.json()["detail"]


def test_patch_validation_errors() -> None:
    token = _otp_and_token("+213555100005", role="craftsman")
    # invalid latitude
    resp = client.patch(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {token}"},
        json={"craftsman_profile": {"latitude": 1000}},
    )
    assert resp.status_code == 422
    # invalid language
    resp2 = client.patch(
        "/api/v1/users/me", headers={"Authorization": f"Bearer {token}"}, json={"language_pref": "en"}
    )
    assert resp2.status_code == 422


def test_get_user_by_id() -> None:
    token = _otp_and_token("+213555100006")
    me = client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token}"}).json()
    uid = me["id"]
    resp = client.get(f"/api/v1/users/{uid}", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 200
    assert resp.json()["id"] == uid


def test_get_user_not_found() -> None:
    token = _otp_and_token("+213555100007")
    resp = client.get("/api/v1/users/00000000-0000-0000-0000-000000000000", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 404


def test_role_switch_client_to_craftsman() -> None:
    token = _otp_and_token("+213555100008", role="client")
    resp = client.patch(
        "/api/v1/users/me", headers={"Authorization": f"Bearer {token}"}, json={"role": "craftsman"}
    )
    assert resp.status_code == 200
    assert resp.json()["role"] == "craftsman"
