from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _token(phone: str, role: str = "client", name: str = "User") -> str:
    r = client.post("/api/v1/auth/request-otp", json={"phone": phone})
    otp = r.json()["otp"]
    v = client.post("/api/v1/auth/verify-otp", json={"phone": phone, "otp": otp, "name": name, "role": role})
    return v.json()["access_token"]


def _make_craftsman(phone: str, trades: list[str], lat: float | None = 36.7525, lng: float | None = 3.0420, rate: float = 1000) -> str:
    token = _token(phone, role="craftsman", name=f"Craftsman {phone[-4:]}")
    client.patch(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "craftsman_profile": {
                "trades": trades,
                "bio": "Bio " + " ".join(trades),
                "latitude": lat,
                "longitude": lng,
                "hourly_rate": rate,
                "service_radius_km": 50,
            }
        },
    )
    # set rating directly via DB not possible, keep 0 for now; rating filter will be 0
    return token


def test_search_requires_no_auth() -> None:
    resp = client.get("/api/v1/discovery/search")
    assert resp.status_code == 200


def test_search_empty() -> None:
    resp = client.get("/api/v1/discovery/search")
    assert resp.status_code == 200
    assert "items" in resp.json()


def test_search_by_trade_freeform() -> None:
    _make_craftsman("+213555200001", ["customtrade-plumbing-xyz"])
    _make_craftsman("+213555200002", ["customtrade-painting-abc"])
    resp = client.get("/api/v1/discovery/search", params={"trade": "customtrade-plumbing-xyz"})
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] >= 1
    for item in data["items"]:
        assert "customtrade-plumbing-xyz" in [t.lower() for t in item["trades"]]

    # case insensitive
    resp2 = client.get("/api/v1/discovery/search", params={"trade": "CUSTOMTRADE-PLUMBING-XYZ"})
    assert resp2.json()["total"] >= 1


def test_search_by_radius() -> None:
    # Algiers center
    _make_craftsman("+213555200003", ["radius-test-trade"], lat=36.7525, lng=3.0420)
    # Far away (approx 300km away)
    _make_craftsman("+213555200004", ["radius-test-trade"], lat=35.0, lng=1.0)
    resp = client.get(
        "/api/v1/discovery/search",
        params={"trade": "radius-test-trade", "lat": 36.7525, "lng": 3.0420, "radius_km": 10},
    )
    assert resp.status_code == 200
    data = resp.json()
    # only near one should be within 10km
    assert data["total"] >= 1
    for item in data["items"]:
        assert item["distance_km"] is not None
        assert item["distance_km"] <= 10


def test_search_price_filter() -> None:
    _make_craftsman("+213555200005", ["price-trade-a"], rate=500)
    _make_craftsman("+213555200006", ["price-trade-a"], rate=5000)
    resp = client.get("/api/v1/discovery/search", params={"trade": "price-trade-a", "min_price": 4000})
    data = resp.json()
    for item in data["items"]:
        assert item["hourly_rate"] >= 4000
    resp2 = client.get("/api/v1/discovery/search", params={"trade": "price-trade-a", "max_price": 1000})
    for item in resp2.json()["items"]:
        assert item["hourly_rate"] <= 1000


def test_search_q() -> None:
    _make_craftsman("+213555200007", ["qsearch-unique-trade-xyz"], lat=36.7, lng=3.0)
    resp = client.get("/api/v1/discovery/search", params={"q": "qsearch-unique-trade-xyz"})
    assert resp.json()["total"] >= 1


def test_search_pagination() -> None:
    for i in range(3):
        _make_craftsman(f"+21355520010{i}", ["pagination-trade"])
    resp = client.get("/api/v1/discovery/search", params={"trade": "pagination-trade", "limit": 2, "offset": 0})
    assert len(resp.json()["items"]) <= 2
    assert resp.json()["limit"] == 2


def test_search_validation() -> None:
    resp = client.get("/api/v1/discovery/search", params={"radius_km": 1000})
    assert resp.status_code == 422
    resp2 = client.get("/api/v1/discovery/search", params={"lat": 100})
    assert resp2.status_code == 422
