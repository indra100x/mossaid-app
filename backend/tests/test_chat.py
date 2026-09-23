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
            "description": "Chat test booking with enough description for validation",
            "address": "Algiers",
            "scheduled_at": (datetime.now(UTC) + timedelta(days=1)).isoformat(),
        },
    )
    return resp.json()["id"]


def test_chat_history_requires_auth() -> None:
    resp = client.get("/api/v1/chat/00000000-0000-0000-0000-000000000000/messages")
    assert resp.status_code == 401


def test_chat_websocket_flow() -> None:
    # Use fresh TestClient to avoid shared portal deadlock with file DB
    with TestClient(app) as fresh:
        def _tok(phone: str, role: str = "client") -> str:
            r = fresh.post("/api/v1/auth/request-otp", json={"phone": phone})
            otp = r.json()["otp"]
            v = fresh.post("/api/v1/auth/verify-otp", json={"phone": phone, "otp": otp, "name": "User", "role": role})
            return v.json()["access_token"]

        def _uid2(token: str) -> str:
            return fresh.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"}).json()["id"]

        c_token = _tok("+213555600001")
        cr_token = _tok("+213555600002", role="craftsman")
        cr_id = _uid2(cr_token)
        # create booking via fresh client
        resp_b = fresh.post(
            "/api/v1/bookings/",
            headers={"Authorization": f"Bearer {c_token}"},
            json={
                "craftsman_id": cr_id,
                "trade": "plumber",
                "description": "Chat test booking with enough description for validation",
                "address": "Algiers",
                "scheduled_at": (datetime.now(UTC) + timedelta(days=1)).isoformat(),
            },
        )
        bid = resp_b.json()["id"]

        # history empty
        resp = fresh.get(f"/api/v1/chat/{bid}/messages", headers={"Authorization": f"Bearer {c_token}"})
        assert resp.status_code == 200
        assert resp.json() == []

        # connect both participants — use same fresh client portal
        with fresh.websocket_connect(f"/api/v1/chat/ws/{bid}?token={c_token}") as ws_client:
            with fresh.websocket_connect(f"/api/v1/chat/ws/{bid}?token={cr_token}") as ws_craftsman:
                ws_client.send_text('{"content": "Hello craftsman"}')
                data1 = ws_client.receive_text()
                data2 = ws_craftsman.receive_text()
                import json

                msg1 = json.loads(data1)
                msg2 = json.loads(data2)
                assert msg1["content"] == "Hello craftsman"
                assert msg2["content"] == "Hello craftsman"
                assert msg1["sender_id"] == _uid2(c_token)
                ws_craftsman.send_text('{"content": "Hello client"}')
                data3 = ws_client.receive_text()
                data4 = ws_craftsman.receive_text()
                assert json.loads(data3)["content"] == "Hello client"
                assert json.loads(data4)["content"] == "Hello client"

        resp2 = fresh.get(f"/api/v1/chat/{bid}/messages", headers={"Authorization": f"Bearer {c_token}"})
        assert len(resp2.json()) == 2
        resp3 = fresh.post(f"/api/v1/chat/{bid}/read", headers={"Authorization": f"Bearer {cr_token}"})
        assert resp3.status_code == 200
        msgs = fresh.get(f"/api/v1/chat/{bid}/messages", headers={"Authorization": f"Bearer {cr_token}"}).json()
        client_msgs = [m for m in msgs if m["sender_id"] == _uid2(c_token)]
        assert any(m["read_at"] is not None for m in client_msgs)


def test_chat_websocket_auth_fail() -> None:
    c_token = _token("+213555600003")
    cr_token = _token("+213555600004", role="craftsman")
    cr_id = _uid(cr_token)
    bid = _create_booking(c_token, cr_id)
    # no token
    try:
        with client.websocket_connect(f"/api/v1/chat/ws/{bid}") as ws:
            ws.receive_text()
        raise AssertionError("should have closed")
    except Exception:
        pass
    # invalid token
    try:
        with client.websocket_connect(f"/api/v1/chat/ws/{bid}?token=invalid") as ws:
            ws.receive_text()
        raise AssertionError()
    except Exception:
        pass
    # non-participant
    other = _token("+213555600005")
    try:
        with client.websocket_connect(f"/api/v1/chat/ws/{bid}?token={other}") as ws:
            ws.receive_text()
        raise AssertionError()
    except Exception:
        pass


def test_chat_websocket_invalid_booking() -> None:
    token = _token("+213555600006")
    try:
        with client.websocket_connect(f"/api/v1/chat/ws/00000000-0000-0000-0000-000000000000?token={token}") as ws:
            ws.receive_text()
        raise AssertionError()
    except Exception:
        pass


def test_chat_not_participant_history_forbidden() -> None:
    c_token = _token("+213555600007")
    cr_token = _token("+213555600008", role="craftsman")
    cr_id = _uid(cr_token)
    bid = _create_booking(c_token, cr_id)
    other = _token("+213555600009")
    resp = client.get(f"/api/v1/chat/{bid}/messages", headers={"Authorization": f"Bearer {other}"})
    assert resp.status_code == 403
    resp2 = client.post(f"/api/v1/chat/{bid}/read", headers={"Authorization": f"Bearer {other}"})
    assert resp2.status_code == 403
