from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.core.deps import CurrentUser
from app.models.booking import Booking
from app.models.user import User
from app.modules.bookings.schemas import (
    ACTION_TO_STATUS,
    BookingCreateIn,
    BookingOut,
    BookingStatusUpdateIn,
)

router = APIRouter(prefix="/bookings", tags=["bookings"])


@router.post("/", response_model=BookingOut, status_code=status.HTTP_201_CREATED)
async def create_booking(
    payload: BookingCreateIn,
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> BookingOut:
    if current_user.role not in ("client", "admin"):
        # craftsmen can also request? For Phase 0 restrict to client
        # but allow any authenticated user to create as client
        pass

    # craftsman must exist and be craftsman role
    result = await session.execute(select(User).where(User.id == payload.craftsman_id))
    craftsman = result.scalar_one_or_none()
    if craftsman is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Craftsman not found")
    if craftsman.role != "craftsman":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Target user is not a craftsman")
    if craftsman.id == current_user.id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot book yourself")

    trade_norm = payload.trade.strip().lower()
    if len(trade_norm) < 2 or len(trade_norm) > 50:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid trade")

    booking = Booking(
        client_id=current_user.id,
        craftsman_id=payload.craftsman_id,
        trade=trade_norm,
        description=payload.description,
        address=payload.address,
        scheduled_at=payload.scheduled_at,
        status="requested",
    )
    session.add(booking)
    await session.commit()
    await session.refresh(booking)
    try:
        from app.modules.notifications.service import notify_booking_status_change

        await notify_booking_status_change(session, booking, "requested")
        await session.commit()
    except Exception:
        pass
    return BookingOut.model_validate(booking)


@router.get("/", response_model=list[BookingOut])
async def list_bookings(
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
    role: str | None = Query(None, description="filter: client or craftsman"),
) -> list[BookingOut]:
    if role == "client":
        stmt = select(Booking).where(Booking.client_id == current_user.id)
    elif role == "craftsman":
        stmt = select(Booking).where(Booking.craftsman_id == current_user.id)
    else:
        stmt = select(Booking).where(
            (Booking.client_id == current_user.id) | (Booking.craftsman_id == current_user.id)
        )
    stmt = stmt.order_by(Booking.created_at.desc())
    result = await session.execute(stmt)
    bookings = result.scalars().all()
    return [BookingOut.model_validate(b) for b in bookings]


@router.get("/{booking_id}", response_model=BookingOut)
async def get_booking(
    booking_id: UUID,
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> BookingOut:
    result = await session.execute(select(Booking).where(Booking.id == booking_id))
    booking = result.scalar_one_or_none()
    if booking is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking not found")
    if booking.client_id != current_user.id and booking.craftsman_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not participant")
    return BookingOut.model_validate(booking)


@router.patch("/{booking_id}/status", response_model=BookingOut)
async def update_booking_status(
    booking_id: UUID,
    payload: BookingStatusUpdateIn,
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> BookingOut:
    result = await session.execute(select(Booking).where(Booking.id == booking_id))
    booking = result.scalar_one_or_none()
    if booking is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking not found")
    if booking.client_id != current_user.id and booking.craftsman_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not participant")

    new_status = ACTION_TO_STATUS[payload.action]

    # Role guards — Phase 1 extends to start/complete
    if payload.action in ("accept", "decline"):
        if current_user.id != booking.craftsman_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only craftsman can accept/decline")
    elif payload.action == "schedule":
        if current_user.id != booking.craftsman_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only craftsman can schedule")
    elif payload.action == "start":
        if current_user.id != booking.craftsman_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only craftsman can start")
    elif payload.action == "complete":
        # either participant can mark completed after in_progress
        pass
    elif payload.action == "cancel":
        # either can cancel before scheduled
        if booking.status in ("declined", "cancelled", "completed"):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Already terminated")

    if not booking.can_transition(new_status):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot transition from {booking.status} to {new_status}",
        )

    old_status = booking.status
    booking.status = new_status
    await session.commit()
    await session.refresh(booking)
    try:
        from app.core.metrics import booking_status_changes

        booking_status_changes.labels(from_status=old_status, to_status=new_status).inc()
    except Exception:
        pass
    # Notification trigger (booking status change) — in-app + FCM fallback
    try:
        from app.modules.notifications.service import notify_booking_status_change

        await notify_booking_status_change(session, booking, new_status)
        await session.commit()
    except Exception:
        pass
    return BookingOut.model_validate(booking)
