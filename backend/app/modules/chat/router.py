import json
from typing import Annotated, Any
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect, status
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import async_session_factory
from app.core.database import get_session as _get_session
from app.core.deps import CurrentUser
from app.core.security import decode_token
from app.models.booking import Booking
from app.models.message import Message
from app.models.user import User
from app.modules.chat.schemas import MessageOut

router = APIRouter(prefix="/chat", tags=["chat"])

# In-memory connection manager for Phase 1; Redis pub/sub layer added where available
class ConnectionManager:
    def __init__(self) -> None:
        self._rooms: dict[str, set[WebSocket]] = {}

    async def connect(self, booking_id: str, ws: WebSocket) -> None:
        self._rooms.setdefault(booking_id, set()).add(ws)

    async def disconnect(self, booking_id: str, ws: WebSocket) -> None:
        conns = self._rooms.get(booking_id)
        if conns and ws in conns:
            conns.remove(ws)
            if not conns:
                self._rooms.pop(booking_id, None)

    async def broadcast(self, booking_id: str, data: dict[str, Any]) -> None:
        text = json.dumps(data)
        conns = list(self._rooms.get(booking_id, set()))
        for ws in conns:
            try:
                await ws.send_text(text)
            except Exception:
                pass

manager = ConnectionManager()

# Redis pub/sub (optional, for multi-instance scaling per system-architecture.md:60)
redis_pub = None
try:
    import redis.asyncio as redis_async

    redis_pub = redis_async.from_url(settings.redis_url, decode_responses=True)
except Exception:
    redis_pub = None


async def _publish(booking_id: str, data: dict[str, Any]) -> None:
    # in-memory broadcast first
    await manager.broadcast(booking_id, data)
    # Redis publish for other pods
    if redis_pub is not None:
        try:
            await redis_pub.publish(f"chat:{booking_id}", json.dumps(data))
        except Exception:
            pass


async def _get_user_from_token(token: str | None, session: AsyncSession) -> User | None:
    if not token:
        return None
    try:
        payload = decode_token(token)
    except ValueError:
        return None
    if payload.get("type") != "access":
        return None
    sub = payload.get("sub")
    if not isinstance(sub, str):
        return None
    try:
        uid = UUID(sub)
    except ValueError:
        return None
    result = await session.execute(select(User).where(User.id == uid))
    return result.scalar_one_or_none()


@router.get("/{booking_id}/messages", response_model=list[MessageOut])
async def list_messages(
    booking_id: UUID,
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(_get_session)],
) -> list[MessageOut]:
    result = await session.execute(select(Booking).where(Booking.id == booking_id))
    booking = result.scalar_one_or_none()
    if booking is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking not found")
    if booking.client_id != current_user.id and booking.craftsman_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not participant")
    res = await session.execute(select(Message).where(Message.booking_id == booking_id).order_by(Message.sent_at))
    msgs = res.scalars().all()
    return [MessageOut.model_validate(m) for m in msgs]


@router.post("/{booking_id}/read", response_model=dict[str, Any])
async def mark_read(
    booking_id: UUID,
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(_get_session)],
) -> dict[str, Any]:
    result = await session.execute(select(Booking).where(Booking.id == booking_id))
    booking = result.scalar_one_or_none()
    if booking is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking not found")
    if booking.client_id != current_user.id and booking.craftsman_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not participant")
    # mark messages where sender != current_user and read_at is null
    from datetime import UTC, datetime

    now = datetime.now(UTC)
    await session.execute(
        update(Message)
        .where(Message.booking_id == booking_id, Message.sender_id != current_user.id, Message.read_at.is_(None))
        .values(read_at=now)
    )
    await session.commit()
    return {"status": "ok"}


@router.websocket("/ws/{booking_id}")
async def websocket_endpoint(websocket: WebSocket, booking_id: str) -> None:
    token = websocket.query_params.get("token")
    # validate uuid
    try:
        bid = UUID(booking_id)
    except ValueError:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    # auth via token query param (Flutter secure storage)
    # create a session for auth check
    async with async_session_factory() as session:
        user = await _get_user_from_token(token, session)
        if user is None:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return
        result = await session.execute(select(Booking).where(Booking.id == bid))
        booking = result.scalar_one_or_none()
        if booking is None:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return
        if booking.client_id != user.id and booking.craftsman_id != user.id:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return

    await websocket.accept()
    await manager.connect(booking_id, websocket)
    try:
        while True:
            data = await websocket.receive_text()
            # parse
            try:
                payload = json.loads(data)
                content = payload.get("content") if isinstance(payload, dict) else data
                if not isinstance(content, str):
                    content = str(content)
            except Exception:
                content = data
            content = content.strip()
            if not content:
                continue
            if len(content) > 2000:
                await websocket.send_text(json.dumps({"error": "Message too long"}))
                continue
            # persist
            async with async_session_factory() as session:
                # re-validate booking still exists
                result = await session.execute(select(Booking).where(Booking.id == bid))
                booking = result.scalar_one_or_none()
                if booking is None:
                    await websocket.send_text(json.dumps({"error": "Booking not found"}))
                    continue
                # we have user from earlier; fetch again to ensure session
                result2 = await session.execute(select(User).where(User.id == user.id))
                db_user = result2.scalar_one_or_none()
                if db_user is None:
                    continue
                msg = Message(booking_id=bid, sender_id=db_user.id, content=content)
                session.add(msg)
                await session.commit()
                await session.refresh(msg)
                out = {
                    "id": str(msg.id),
                    "booking_id": str(msg.booking_id),
                    "sender_id": str(msg.sender_id),
                    "content": msg.content,
                    "sent_at": msg.sent_at.isoformat(),
                    "read_at": None,
                }
                await _publish(booking_id, out)
                # Phase 3: push + in-app notification to the other participant.
                # Flutter-side FCM permission/token/handlers already exist;
                # backend targets stored device tokens via firebase-admin.
                try:
                    from app.modules.notifications.service import notify_new_message

                    await notify_new_message(session, booking, db_user.id, content)
                    await session.commit()
                except Exception:
                    pass
    except WebSocketDisconnect:
        pass
    except Exception:
        pass
    finally:
        await manager.disconnect(booking_id, websocket)


@router.get("/")
async def chat_placeholder() -> dict[str, str]:
    """chat — WebSocket 1:1 messaging."""
    return {"module": "chat", "status": "not_implemented"}
