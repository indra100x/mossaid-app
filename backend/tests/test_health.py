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


def test_placeholder_modules_still_not_implemented() -> None:
    # Phase 0 implements auth, users, discovery, bookings — these no longer return placeholder
    # Remaining Phase 1-3 modules should still be placeholders
    for mod in ["chat", "payments", "reviews", "notifications", "admin"]:
        resp = client.get(f"/api/v1/{mod}/")
        assert resp.status_code == 200, f"{mod} failed: {resp.text}"
        assert resp.json()["module"] == mod


def test_implemented_modules_require_auth_or_search() -> None:
    # bookings now requires auth (401 without token)
    resp = client.get("/api/v1/bookings/")
    assert resp.status_code == 401
    # discovery search is public
    resp2 = client.get("/api/v1/discovery/search")
    assert resp2.status_code == 200
    # users/me requires auth
    resp3 = client.get("/api/v1/users/me")
    assert resp3.status_code == 401
