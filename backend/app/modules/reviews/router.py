from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.core.deps import CurrentUser
from app.models.booking import Booking
from app.models.craftsman_profile import CraftsmanProfile
from app.models.review import Review
from app.modules.reviews.schemas import ReviewCreateIn, ReviewOut

router = APIRouter(prefix="/reviews", tags=["reviews"])


@router.post("/", response_model=ReviewOut, status_code=status.HTTP_201_CREATED)
async def create_review(
    payload: ReviewCreateIn,
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> ReviewOut:
    # booking must exist
    result = await session.execute(select(Booking).where(Booking.id == payload.booking_id))
    booking = result.scalar_one_or_none()
    if booking is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking not found")
    # only client who owns booking can review
    if booking.client_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only booking client can review")
    # booking must be completed
    if booking.status != "completed":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Booking not completed")
    # check existing review for this booking
    existing = await session.execute(select(Review).where(Review.booking_id == payload.booking_id))
    if existing.scalar_one_or_none() is not None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Review already exists")

    review = Review(
        booking_id=booking.id,
        client_id=current_user.id,
        craftsman_id=booking.craftsman_id,
        rating=payload.rating,
        comment=payload.comment,
    )
    session.add(review)
    await session.flush()

    # aggregate rating_avg for craftsman
    avg_res = await session.execute(
        select(func.avg(Review.rating)).where(Review.craftsman_id == booking.craftsman_id)
    )
    avg = avg_res.scalar_one()
    # update profile
    prof_res = await session.execute(select(CraftsmanProfile).where(CraftsmanProfile.user_id == booking.craftsman_id))
    prof = prof_res.scalar_one_or_none()
    if prof is not None:
        prof.rating_avg = float(avg) if avg is not None else float(payload.rating)

    await session.commit()
    await session.refresh(review)
    return ReviewOut.model_validate(review)


@router.get("/", response_model=list[ReviewOut])
async def list_reviews(
    session: Annotated[AsyncSession, Depends(get_session)],
    craftsman_id: Annotated[UUID | None, Query()] = None,
    booking_id: Annotated[UUID | None, Query()] = None,
) -> list[ReviewOut]:
    stmt = select(Review)
    if craftsman_id is not None:
        stmt = stmt.where(Review.craftsman_id == craftsman_id)
    if booking_id is not None:
        stmt = stmt.where(Review.booking_id == booking_id)
    stmt = stmt.order_by(Review.created_at.desc())
    result = await session.execute(stmt)
    reviews = result.scalars().all()
    return [ReviewOut.model_validate(r) for r in reviews]


@router.get("/booking/{booking_id}", response_model=ReviewOut)
async def get_review_for_booking(
    booking_id: UUID,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> ReviewOut:
    result = await session.execute(select(Review).where(Review.booking_id == booking_id))
    review = result.scalar_one_or_none()
    if review is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Review not found")
    return ReviewOut.model_validate(review)
