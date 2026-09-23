from typing import Annotated

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


@router.get("/")
async def notifications_placeholder() -> dict[str, str]:
    """notifications — push (FCM) + in-app."""
    return {"module": "notifications", "status": "not_implemented"}
