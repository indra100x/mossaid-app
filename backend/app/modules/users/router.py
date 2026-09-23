from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.database import get_session
from app.core.deps import CurrentUser
from app.core.storage import generate_presigned_url
from app.models.craftsman_profile import CraftsmanProfile
from app.models.user import User
from app.models.verification_document import VerificationDocument
from app.modules.users.schemas import (
    CraftsmanProfileOut,
    RequestUploadOut,
    UserOut,
    UserUpdateIn,
    VerificationOut,
    VerificationRequestIn,
)

router = APIRouter(prefix="/users", tags=["users"])


def _to_user_out(user: User) -> UserOut:
    prof = None
    if user.craftsman_profile:
        p = user.craftsman_profile
        prof = CraftsmanProfileOut(
            trades=p.trades,
            bio=p.bio,
            service_radius_km=p.service_radius_km,
            latitude=p.latitude,
            longitude=p.longitude,
            hourly_rate=p.hourly_rate,
            rating_avg=p.rating_avg,
            verification_status=p.verification_status,
        )
    return UserOut(
        id=user.id,
        phone=user.phone,
        role=user.role,
        name=user.name,
        language_pref=user.language_pref,
        is_verified=user.is_verified,
        created_at=user.created_at,
        craftsman_profile=prof,
    )


@router.get("/me", response_model=UserOut)
async def get_me(
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> UserOut:
    result = await session.execute(
        select(User).options(selectinload(User.craftsman_profile)).where(User.id == current_user.id)
    )
    user = result.scalar_one()
    return _to_user_out(user)


@router.patch("/me", response_model=UserOut)
async def update_me(
    payload: UserUpdateIn,
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> UserOut:
    result = await session.execute(
        select(User).options(selectinload(User.craftsman_profile)).where(User.id == current_user.id)
    )
    user = result.scalar_one()

    if payload.name is not None:
        user.name = payload.name.strip()
    if payload.language_pref is not None:
        user.language_pref = payload.language_pref
    if payload.role is not None and payload.role != user.role:
        # allow client <-> craftsman switch in Phase 0; admin locked
        if user.role != "admin":
            user.role = payload.role

    # Determine target role after potential change
    target_role = user.role

    if payload.craftsman_profile is not None:
        if target_role != "craftsman":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Craftsman profile only for craftsman role",
            )
        prof_data = payload.craftsman_profile
        profile = user.craftsman_profile
        if profile is None:
            profile = CraftsmanProfile(user_id=user.id)
            session.add(profile)
            user.craftsman_profile = profile

        trades = prof_data.normalized_trades()
        if trades is not None:
            profile.trades = trades
        if prof_data.bio is not None:
            profile.bio = prof_data.bio
        if prof_data.service_radius_km is not None:
            profile.service_radius_km = prof_data.service_radius_km
        if prof_data.latitude is not None:
            profile.latitude = prof_data.latitude
        if prof_data.longitude is not None:
            profile.longitude = prof_data.longitude
        if prof_data.hourly_rate is not None:
            profile.hourly_rate = prof_data.hourly_rate

    await session.commit()
    await session.refresh(user)
    # reload with profile
    result2 = await session.execute(
        select(User).options(selectinload(User.craftsman_profile)).where(User.id == user.id)
    )
    user2 = result2.scalar_one()
    return _to_user_out(user2)


@router.post("/me/verification/request-upload", response_model=RequestUploadOut, status_code=status.HTTP_201_CREATED)
async def request_verification_upload(
    payload: VerificationRequestIn,
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> RequestUploadOut:
    if current_user.role != "craftsman":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only craftsmen can upload verification")
    upload_url, file_url = generate_presigned_url(str(current_user.id), payload.doc_type, payload.file_name)
    doc = VerificationDocument(user_id=current_user.id, doc_type=payload.doc_type, file_url=file_url, status="pending")
    session.add(doc)
    await session.commit()
    await session.refresh(doc)
    return RequestUploadOut(document=VerificationOut.model_validate(doc), upload_url=upload_url, file_url=file_url)


@router.get("/me/verification", response_model=list[VerificationOut])
async def list_my_verification(
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> list[VerificationOut]:
    result = await session.execute(select(VerificationDocument).where(VerificationDocument.user_id == current_user.id).order_by(VerificationDocument.created_at.desc()))
    docs = result.scalars().all()
    return [VerificationOut.model_validate(d) for d in docs]


@router.get("/{user_id}", response_model=UserOut)
async def get_user_by_id(
    user_id: UUID,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> UserOut:
    result = await session.execute(
        select(User).options(selectinload(User.craftsman_profile)).where(User.id == user_id)
    )
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return _to_user_out(user)


@router.get("/")
async def users_placeholder() -> dict[str, str]:
    """users — profile CRUD, craftsman trade categories."""
    return {"module": "users", "status": "not_implemented"}
