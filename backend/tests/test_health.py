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
    # Phase 3: notifications in-app center is implemented (GET / requires auth),
    # payments root is still a placeholder. Chat/admin roots remain placeholders.
    resp = client.get("/api/v1/payments/")
    assert resp.status_code == 200, f"payments failed: {resp.text}"
    assert resp.json()["module"] == "payments"
    # notifications center requires auth (401 without token)
    resp_n = client.get("/api/v1/notifications/")
    assert resp_n.status_code == 401
    # chat and admin root still placeholder (even though they have sub-routes)
    for mod in ["chat", "admin"]:
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
