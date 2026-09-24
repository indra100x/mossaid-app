from typing import Annotated, Any

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.core.deps import CurrentUser
from app.models.device_token import DeviceToken

router = APIRouter(prefix="/notifications", tags=["notifications"])


class FcmTokenIn(BaseModel):
    token: str
    platform: str = "android"


class FcmTokenOut(BaseModel):
    id: str
    token: str
    platform: str

    model_config = {"from_attributes": True}


@router.post("/tokens", response_model=FcmTokenOut, status_code=status.HTTP_201_CREATED)
async def register_fcm_token(
    payload: FcmTokenIn,
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> FcmTokenOut:
    # Upsert: token unique, if exists update user_id (device switched user)
    result = await session.execute(select(DeviceToken).where(DeviceToken.token == payload.token))
    existing = result.scalar_one_or_none()
    if existing:
        existing.user_id = current_user.id
        existing.platform = payload.platform
        await session.commit()
        await session.refresh(existing)
        return FcmTokenOut(id=str(existing.id), token=existing.token, platform=existing.platform)
    token = DeviceToken(user_id=current_user.id, token=payload.token, platform=payload.platform)
    session.add(token)
    await session.commit()
    await session.refresh(token)
    return FcmTokenOut(id=str(token.id), token=token.token, platform=token.platform)


@router.get("/tokens", response_model=list[FcmTokenOut])
async def list_fcm_tokens(
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> list[FcmTokenOut]:
    result = await session.execute(select(DeviceToken).where(DeviceToken.user_id == current_user.id))
    tokens = result.scalars().all()
    return [FcmTokenOut(id=str(t.id), token=t.token, platform=t.platform) for t in tokens]


@router.delete("/tokens/{token}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_fcm_token(
    token: str,
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> None:
    result = await session.execute(select(DeviceToken).where(DeviceToken.token == token, DeviceToken.user_id == current_user.id))
    existing = result.scalar_one_or_none()
    if not existing:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Token not found")
    await session.delete(existing)
    await session.commit()


class NotificationOut(BaseModel):
    id: str
    type: str
    title: str
    body: str
    data: dict[str, Any]
    is_read: bool
    created_at: str

    model_config = {"from_attributes": True}


@router.get("/", response_model=list[NotificationOut])
async def list_notifications(
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> list[NotificationOut]:
    from app.models.notification import Notification

    result = await session.execute(
        select(Notification).where(Notification.user_id == current_user.id).order_by(Notification.created_at.desc())
    )
    notifs = result.scalars().all()
    return [
        NotificationOut(
            id=str(n.id),
            type=n.type,
            title=n.title,
            body=n.body,
            data=n.data,
            is_read=n.is_read,
            created_at=n.created_at.isoformat(),
        )
        for n in notifs
    ]


@router.post("/{notif_id}/read", status_code=status.HTTP_200_OK)
async def mark_notification_read(
    notif_id: str,
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> dict[str, str]:
    from uuid import UUID

    from app.models.notification import Notification

    try:
        nid = UUID(notif_id)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found") from None
    result = await session.execute(select(Notification).where(Notification.id == nid, Notification.user_id == current_user.id))
    notif = result.scalar_one_or_none()
    if notif is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")
    notif.is_read = True
    await session.commit()
    return {"status": "ok"}


@router.get("/unread-count", response_model=dict[str, int])
async def unread_count(
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> dict[str, int]:
    from sqlalchemy import func

    from app.models.notification import Notification

    result = await session.execute(select(func.count()).select_from(Notification).where(Notification.user_id == current_user.id, Notification.is_read == False))  # noqa: E712
    count = result.scalar_one()
    return {"count": count}
