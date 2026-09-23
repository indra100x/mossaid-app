from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _token(phone: str, role: str = "client") -> str:
    r = client.post("/api/v1/auth/request-otp", json={"phone": phone})
    otp = r.json()["otp"]
    v = client.post("/api/v1/auth/verify-otp", json={"phone": phone, "otp": otp, "name": "User", "role": role})
    return v.json()["access_token"]


def test_fcm_token_register_and_multiple() -> None:
    t1 = _token("+213555800001")
    t2 = _token("+213555800002")
    # t1 registers token A
    r1 = client.post("/api/v1/notifications/tokens", headers={"Authorization": f"Bearer {t1}"}, json={"token": "fcm_token_A_android", "platform": "android"})
    assert r1.status_code == 201
    # same user registers token B (second device) — should keep both
    r2 = client.post("/api/v1/notifications/tokens", headers={"Authorization": f"Bearer {t1}"}, json={"token": "fcm_token_B_android", "platform": "android"})
    assert r2.status_code == 201
    # list should have 2
    lst = client.get("/api/v1/notifications/tokens", headers={"Authorization": f"Bearer {t1}"}).json()
    assert len(lst) == 2
    assert any(x["token"] == "fcm_token_A_android" for x in lst)
    assert any(x["token"] == "fcm_token_B_android" for x in lst)
    # same token registered by different user should move ownership
    r3 = client.post("/api/v1/notifications/tokens", headers={"Authorization": f"Bearer {t2}"}, json={"token": "fcm_token_A_android", "platform": "android"})
    assert r3.status_code == 201
    lst1 = client.get("/api/v1/notifications/tokens", headers={"Authorization": f"Bearer {t1}"}).json()
    assert not any(x["token"] == "fcm_token_A_android" for x in lst1)
    lst2 = client.get("/api/v1/notifications/tokens", headers={"Authorization": f"Bearer {t2}"}).json()
    assert any(x["token"] == "fcm_token_A_android" for x in lst2)
    # delete
    del_resp = client.delete("/api/v1/notifications/tokens/fcm_token_B_android", headers={"Authorization": f"Bearer {t1}"})
    assert del_resp.status_code == 204
    lst3 = client.get("/api/v1/notifications/tokens", headers={"Authorization": f"Bearer {t1}"}).json()
    assert len(lst3) == 0
    # alias via users/me/fcm-token
    r4 = client.post("/api/v1/users/me/fcm-token", headers={"Authorization": f"Bearer {t1}"}, json={"token": "fcm_token_C_android", "platform": "android"})
    assert r4.status_code == 201
    assert r4.json()["token"] == "fcm_token_C_android"


def test_fcm_token_requires_auth() -> None:
    r = client.post("/api/v1/notifications/tokens", json={"token": "x", "platform": "android"})
    assert r.status_code == 401
    r2 = client.get("/api/v1/notifications/tokens")
    assert r2.status_code == 401
