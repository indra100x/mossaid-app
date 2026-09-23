from typing import Annotated, Any
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.core.deps import CurrentUser
from app.models.craftsman_profile import CraftsmanProfile
from app.models.verification_document import VerificationDocument

router = APIRouter(prefix="/admin", tags=["admin"])


class ReviewDecisionIn(BaseModel):
    decision: str  # approved or rejected


def require_admin(current_user: CurrentUser) -> None:
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin only")


@router.get("/verification", response_model=list[dict[str, Any]])
async def list_verification_queue(
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
    status_filter: str | None = None,
) -> list[dict[str, Any]]:
    require_admin(current_user)
    stmt = select(VerificationDocument).order_by(VerificationDocument.created_at.desc())
    if status_filter:
        stmt = stmt.where(VerificationDocument.status == status_filter)
    result = await session.execute(stmt)
    docs = result.scalars().all()
    return [
        {
            "id": str(d.id),
            "user_id": str(d.user_id),
            "doc_type": d.doc_type,
            "file_url": d.file_url,
            "status": d.status,
            "reviewed_by": str(d.reviewed_by) if d.reviewed_by else None,
            "created_at": d.created_at.isoformat(),
        }
        for d in docs
    ]


@router.post("/verification/{doc_id}/review", response_model=dict[str, Any])
async def review_verification(
    doc_id: UUID,
    payload: ReviewDecisionIn,
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> dict[str, Any]:
    require_admin(current_user)
    if payload.decision not in ("approved", "rejected"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Decision must be approved or rejected")

    result = await session.execute(select(VerificationDocument).where(VerificationDocument.id == doc_id))
    doc = result.scalar_one_or_none()
    if doc is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found")
    if doc.status != "pending":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Already reviewed")

    doc.status = payload.decision
    doc.reviewed_by = current_user.id
    # update craftsman profile verification_status
    prof_res = await session.execute(select(CraftsmanProfile).where(CraftsmanProfile.user_id == doc.user_id))
    prof = prof_res.scalar_one_or_none()
    if prof is not None:
        if payload.decision == "approved":
            prof.verification_status = "verified"
        else:
            prof.verification_status = "rejected"

    await session.commit()
    await session.refresh(doc)
    return {
        "id": str(doc.id),
        "status": doc.status,
        "reviewed_by": str(doc.reviewed_by) if doc.reviewed_by else None,
    }


@router.get("/")
async def admin_placeholder() -> dict[str, str]:
    """admin — verification queue, dispute resolution."""
    return {"module": "admin", "status": "not_implemented"}
