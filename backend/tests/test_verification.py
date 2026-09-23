import asyncio

from fastapi.testclient import TestClient

from app.core.security import create_access_token
from app.main import app
from app.models.user import User
from tests.conftest import TestingSessionLocal

client = TestClient(app)


def _token(phone: str, role: str = "client", name: str = "User") -> str:
    r = client.post("/api/v1/auth/request-otp", json={"phone": phone})
    otp = r.json()["otp"]
    v = client.post("/api/v1/auth/verify-otp", json={"phone": phone, "otp": otp, "name": name, "role": role})
    return v.json()["access_token"]


def _get_user_id(token: str) -> str:
    me = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"}).json()
    return me["id"]


def _create_admin_token() -> str:
    # Direct DB insertion for admin (bypass OTP role restriction)
    async def _create() -> str:
        async with TestingSessionLocal() as sess:
            from sqlalchemy import select
            # check existing
            res = await sess.execute(select(User).where(User.phone == "+213555999999"))
            user = res.scalar_one_or_none()
            if user is None:
                user = User(phone="+213555999999", role="admin", name="Admin", language_pref="fr", is_verified=True)
                sess.add(user)
                await sess.commit()
                await sess.refresh(user)
            return create_access_token(subject=str(user.id))

    return asyncio.run(_create())


def test_craftsman_request_upload_success() -> None:
    craftsman_token = _token("+213555400001", role="craftsman")
    resp = client.post(
        "/api/v1/users/me/verification/request-upload",
        headers={"Authorization": f"Bearer {craftsman_token}"},
        json={"doc_type": "id", "file_name": "id_card.pdf"},
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["upload_url"].startswith("https://mossaid-s3.test/")
    assert data["file_url"].startswith("s3://mossaid/")
    assert data["document"]["doc_type"] == "id"
    assert data["document"]["status"] == "pending"


def test_client_cannot_upload_verification() -> None:
    token = _token("+213555400002", role="client")
    resp = client.post(
        "/api/v1/users/me/verification/request-upload",
        headers={"Authorization": f"Bearer {token}"},
        json={"doc_type": "id", "file_name": "id.pdf"},
    )
    assert resp.status_code == 403


def test_verification_validation() -> None:
    token = _token("+213555400003", role="craftsman")
    resp = client.post(
        "/api/v1/users/me/verification/request-upload",
        headers={"Authorization": f"Bearer {token}"},
        json={"doc_type": "invalid", "file_name": "x.pdf"},
    )
    assert resp.status_code == 422
    resp2 = client.post(
        "/api/v1/users/me/verification/request-upload",
        headers={"Authorization": f"Bearer {token}"},
        json={"doc_type": "id"},
    )
    assert resp2.status_code == 422


def test_list_my_verification() -> None:
    token = _token("+213555400004", role="craftsman")
    client.post(
        "/api/v1/users/me/verification/request-upload",
        headers={"Authorization": f"Bearer {token}"},
        json={"doc_type": "diploma", "file_name": "diploma.pdf"},
    )
    resp = client.get("/api/v1/users/me/verification", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 200
    assert len(resp.json()) >= 1


def test_admin_queue_and_approve() -> None:
    craftsman_token = _token("+213555400005", role="craftsman")
    # make craftsman profile first
    client.patch(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {craftsman_token}"},
        json={"craftsman_profile": {"trades": ["plumber"], "latitude": 36.7, "longitude": 3.0}},
    )
    upload = client.post(
        "/api/v1/users/me/verification/request-upload",
        headers={"Authorization": f"Bearer {craftsman_token}"},
        json={"doc_type": "trade_credential", "file_name": "cert.pdf"},
    ).json()
    doc_id = upload["document"]["id"]

    admin_token = _create_admin_token()
    # non-admin cannot access queue
    resp_forbidden = client.get("/api/v1/admin/verification", headers={"Authorization": f"Bearer {craftsman_token}"})
    assert resp_forbidden.status_code == 403

    # admin can list
    resp = client.get("/api/v1/admin/verification", headers={"Authorization": f"Bearer {admin_token}"})
    assert resp.status_code == 200
    assert any(d["id"] == doc_id for d in resp.json())

    # approve
    resp2 = client.post(
        f"/api/v1/admin/verification/{doc_id}/review",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={"decision": "approved"},
    )
    assert resp2.status_code == 200
    assert resp2.json()["status"] == "approved"

    # check craftsman profile now verified badge
    me = client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {craftsman_token}"}).json()
    assert me["craftsman_profile"]["verification_status"] == "verified"

    # discovery should show verified badge
    search = client.get("/api/v1/discovery/search", params={"trade": "plumber"}).json()
    # find this craftsman
    found = next((x for x in search["items"] if x["user_id"] == _get_user_id(craftsman_token)), None)
    if found:
        assert found["verification_status"] == "verified"

    # second approve fails (already reviewed)
    resp3 = client.post(
        f"/api/v1/admin/verification/{doc_id}/review",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={"decision": "approved"},
    )
    assert resp3.status_code == 400


def test_admin_reject() -> None:
    craftsman_token = _token("+213555400006", role="craftsman")
    client.patch(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {craftsman_token}"},
        json={"craftsman_profile": {"trades": ["electrician"]}},
    )
    doc_id = client.post(
        "/api/v1/users/me/verification/request-upload",
        headers={"Authorization": f"Bearer {craftsman_token}"},
        json={"doc_type": "id", "file_name": "id2.pdf"},
    ).json()["document"]["id"]
    admin_token = _create_admin_token()
    resp = client.post(
        f"/api/v1/admin/verification/{doc_id}/review",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={"decision": "rejected"},
    )
    assert resp.status_code == 200
    assert resp.json()["status"] == "rejected"
    me = client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {craftsman_token}"}).json()
    assert me["craftsman_profile"]["verification_status"] == "rejected"


def test_admin_invalid_decision() -> None:
    craftsman_token = _token("+213555400007", role="craftsman")
    doc_id = client.post(
        "/api/v1/users/me/verification/request-upload",
        headers={"Authorization": f"Bearer {craftsman_token}"},
        json={"doc_type": "id", "file_name": "id3.pdf"},
    ).json()["document"]["id"]
    admin_token = _create_admin_token()
    resp = client.post(
        f"/api/v1/admin/verification/{doc_id}/review",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={"decision": "invalid"},
    )
    assert resp.status_code == 400


def test_verification_requires_auth() -> None:
    resp = client.post("/api/v1/users/me/verification/request-upload", json={"doc_type": "id", "file_name": "x.pdf"})
    assert resp.status_code == 401
