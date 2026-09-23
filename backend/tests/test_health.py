from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health_check() -> None:
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}


def test_health_db() -> None:
    resp = client.get("/health/db")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


def test_module_placeholders() -> None:
    modules = [
        "auth",
        "users",
        "discovery",
        "bookings",
        "chat",
        "payments",
        "reviews",
        "notifications",
        "admin",
    ]
    for mod in modules:
        resp = client.get(f"/api/v1/{mod}/")
        assert resp.status_code == 200, f"{mod} failed: {resp.text}"
        assert resp.json()["module"] == mod
