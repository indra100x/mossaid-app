import pytest
from fastapi.testclient import TestClient

from app.core.config import settings
from app.core.security import hash_password
from app.main import app

client = TestClient(app)

USERNAME = "testadmin"
PASSWORD = "testpass-123"


@pytest.fixture
def admin_creds(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "admin_username", USERNAME)
    monkeypatch.setattr(settings, "admin_password_hash", hash_password(PASSWORD))


def test_admin_login_success(admin_creds: None) -> None:
    r = client.post("/api/v1/auth/admin-login", json={"username": USERNAME, "password": PASSWORD})
    assert r.status_code == 200
    body = r.json()
    assert body["user"]["role"] == "super_admin"
    # Issued JWT unlocks admin routes with no manual token handling.
    token = body["access_token"]
    assert body["refresh_token"]
    analytics = client.get("/api/v1/admin/analytics", headers={"Authorization": f"Bearer {token}"})
    assert analytics.status_code == 200
    assert "total_gmv" in analytics.json()
    # Login was audit-logged.
    logs = client.get("/api/v1/admin/audit-logs", headers={"Authorization": f"Bearer {token}"}).json()
    assert any(entry["action"] == "admin.login" for entry in logs)


def test_admin_login_wrong_password(admin_creds: None) -> None:
    r = client.post("/api/v1/auth/admin-login", json={"username": USERNAME, "password": "nope"})
    assert r.status_code == 401
    r2 = client.post("/api/v1/auth/admin-login", json={"username": "someone-else", "password": PASSWORD})
    assert r2.status_code == 401


def test_admin_login_disabled_without_hash(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "admin_password_hash", "")
    r = client.post("/api/v1/auth/admin-login", json={"username": "admin", "password": "anything"})
    assert r.status_code == 503
