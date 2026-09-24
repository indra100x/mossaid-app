from datetime import UTC, datetime
from typing import Annotated, Any
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.audit import log_audit
from app.core.database import get_session
from app.core.deps import CurrentUser
from app.core.rbac import require_permission
from app.models.audit_log import AuditLog
from app.models.booking import Booking
from app.models.craftsman_profile import CraftsmanProfile
from app.models.payment import Dispute, Payment
from app.models.user import User
from app.models.verification_document import VerificationDocument

router = APIRouter(prefix="/admin", tags=["admin"])


class ReviewDecisionIn(BaseModel):
    decision: str  # approved or rejected


class SuspendIn(BaseModel):
    reason: str | None = None


# Verification queue
@router.get("/verification", response_model=list[dict[str, Any]])
async def list_verification_queue(
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
    status_filter: str | None = None,
) -> list[dict[str, Any]]:
    require_permission(current_user, "verification.review")
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
    require_permission(current_user, "verification.review")
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
    prof_res = await session.execute(select(CraftsmanProfile).where(CraftsmanProfile.user_id == doc.user_id))
    prof = prof_res.scalar_one_or_none()
    if prof is not None:
        prof.verification_status = "verified" if payload.decision == "approved" else "rejected"
    await log_audit(session, current_user.id, f"verification.{payload.decision}", "verification_document", str(doc.id), {"doc_type": doc.doc_type})
    await session.commit()
    await session.refresh(doc)
    return {"id": str(doc.id), "status": doc.status, "reviewed_by": str(doc.reviewed_by) if doc.reviewed_by else None}


# Disputes
@router.get("/disputes", response_model=list[dict[str, Any]])
async def list_disputes(
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> list[dict[str, Any]]:
    require_permission(current_user, "disputes.list")
    result = await session.execute(select(Dispute).order_by(Dispute.created_at.desc()))
    disputes = result.scalars().all()
    return [
        {"id": str(d.id), "payment_id": str(d.payment_id), "booking_id": str(d.booking_id), "raised_by": str(d.raised_by), "reason": d.reason, "status": d.status, "created_at": d.created_at.isoformat()}
        for d in disputes
    ]


@router.post("/disputes/{dispute_id}/resolve", response_model=dict[str, Any])
async def resolve_dispute(
    dispute_id: UUID,
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
    decision: str = "refund",  # refund or release
) -> dict[str, Any]:
    require_permission(current_user, "disputes.resolve")
    result = await session.execute(select(Dispute).where(Dispute.id == dispute_id))
    dispute = result.scalar_one_or_none()
    if dispute is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Dispute not found")
    if dispute.status != "open":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Already resolved")
    pay_res = await session.execute(select(Payment).where(Payment.id == dispute.payment_id))
    payment = pay_res.scalar_one_or_none()
    if payment is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment not found")
    if decision == "refund":
        payment.status = "refunded"
        payment.refunded_at = datetime.now(UTC)
    elif decision == "release":
        payment.status = "released"
        payment.released_at = datetime.now(UTC)
    else:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Decision must be refund or release")
    dispute.status = "resolved"
    dispute.resolved_at = datetime.now(UTC)
    dispute.resolved_by = current_user.id
    await log_audit(session, current_user.id, f"dispute.resolve.{decision}", "dispute", str(dispute.id), {"payment_id": str(payment.id)})
    await session.commit()
    return {"id": str(dispute.id), "status": dispute.status, "payment_status": payment.status}


# Users
@router.get("/users", response_model=list[dict[str, Any]])
async def list_users(
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> list[dict[str, Any]]:
    require_permission(current_user, "users.list")
    result = await session.execute(select(User).order_by(User.created_at.desc()))
    users = result.scalars().all()
    return [{"id": str(u.id), "phone": u.phone, "role": u.role, "name": u.name, "is_verified": u.is_verified, "is_suspended": u.is_suspended, "created_at": u.created_at.isoformat()} for u in users]


@router.post("/users/{user_id}/suspend", response_model=dict[str, Any])
async def suspend_user(
    user_id: UUID,
    payload: SuspendIn,
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> dict[str, Any]:
    require_permission(current_user, "users.suspend")
    result = await session.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    if user.id == current_user.id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot suspend yourself")
    user.is_suspended = True
    user.suspended_at = datetime.now(UTC)
    user.suspended_by = current_user.id
    user.suspension_reason = payload.reason
    await log_audit(session, current_user.id, "user.suspend", "user", str(user.id), {"reason": payload.reason})
    await session.commit()
    return {"id": str(user.id), "is_suspended": True}


@router.post("/users/{user_id}/reinstate", response_model=dict[str, Any])
async def reinstate_user(
    user_id: UUID,
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> dict[str, Any]:
    require_permission(current_user, "users.suspend")
    result = await session.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    user.is_suspended = False
    user.suspended_at = None
    user.suspended_by = None
    user.suspension_reason = None
    await log_audit(session, current_user.id, "user.reinstate", "user", str(user.id))
    await session.commit()
    return {"id": str(user.id), "is_suspended": False}


# Payments / Payouts
@router.get("/payments", response_model=list[dict[str, Any]])
async def list_payments_admin(
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> list[dict[str, Any]]:
    require_permission(current_user, "payments.list")
    result = await session.execute(select(Payment).order_by(Payment.created_at.desc()))
    payments = result.scalars().all()
    return [{"id": str(p.id), "booking_id": str(p.booking_id), "amount": p.amount, "status": p.status, "gateway_checkout_id": p.gateway_checkout_id, "created_at": p.created_at.isoformat()} for p in payments]


@router.get("/payouts", response_model=list[dict[str, Any]])
async def payout_reconciliation(
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> list[dict[str, Any]]:
    require_permission(current_user, "payouts.view")
    result = await session.execute(select(Payment).where(Payment.status == "released").order_by(Payment.created_at.desc()))
    payments = result.scalars().all()
    # For v1, payout disbursement is manual admin-triggered; we list pending payouts
    return [{"id": str(p.id), "craftsman_id": str(p.craftsman_id), "amount": p.amount, "status": p.status, "released_at": p.released_at.isoformat() if p.released_at else None} for p in payments]


@router.post("/payouts/{payment_id}/disburse", response_model=dict[str, Any])
async def disburse_payout(
    payment_id: UUID,
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> dict[str, Any]:
    require_permission(current_user, "payouts.view")
    result = await session.execute(select(Payment).where(Payment.id == payment_id))
    payment = result.scalar_one_or_none()
    if payment is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment not found")
    if payment.status != "released":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Only released payments can be disbursed")
    # In v1, we mark as disbursed by setting a flag in audit; for simplicity, keep status released and log
    await log_audit(session, current_user.id, "payout.disburse", "payment", str(payment.id), {"amount": payment.amount, "craftsman_id": str(payment.craftsman_id)})
    await session.commit()
    return {"id": str(payment.id), "status": "disbursed", "amount": payment.amount}


# Analytics per product-evaluation.md:6
@router.get("/analytics", response_model=dict[str, Any])
async def analytics(
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> dict[str, Any]:
    require_permission(current_user, "analytics.view")
    total_users = (await session.execute(select(func.count()).select_from(User))).scalar_one()
    total_craftsmen = (await session.execute(select(func.count()).select_from(User).where(User.role == "craftsman"))).scalar_one()
    verified_craftsmen = (await session.execute(select(func.count()).select_from(CraftsmanProfile).where(CraftsmanProfile.verification_status == "verified"))).scalar_one()
    total_bookings = (await session.execute(select(func.count()).select_from(Booking))).scalar_one()
    completed_bookings = (await session.execute(select(func.count()).select_from(Booking).where(Booking.status == "completed"))).scalar_one()
    total_gmv = (await session.execute(select(func.coalesce(func.sum(Payment.amount), 0)).select_from(Payment).where(Payment.status.in_(["held", "released", "refunded"])))).scalar_one()
    total_disputes = (await session.execute(select(func.count()).select_from(Dispute))).scalar_one()
    completion_rate = (completed_bookings / total_bookings * 100) if total_bookings else 0
    verification_rate = (verified_craftsmen / total_craftsmen * 100) if total_craftsmen else 0
    dispute_rate = (total_disputes / total_bookings * 100) if total_bookings else 0
    return {
        "total_users": total_users,
        "total_craftsmen": total_craftsmen,
        "verified_craftsmen": verified_craftsmen,
        "verification_rate": round(verification_rate, 2),
        "total_bookings": total_bookings,
        "completed_bookings": completed_bookings,
        "completion_rate": round(completion_rate, 2),
        "total_gmv": float(total_gmv),
        "total_disputes": total_disputes,
        "dispute_rate": round(dispute_rate, 2),
    }


# Audit log
@router.get("/audit-logs", response_model=list[dict[str, Any]])
async def list_audit_logs(
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> list[dict[str, Any]]:
    require_permission(current_user, "analytics.view")
    result = await session.execute(select(AuditLog).order_by(AuditLog.created_at.desc()).limit(100))
    logs = result.scalars().all()
    return [{"id": str(entry.id), "actor_id": str(entry.actor_id) if entry.actor_id else None, "action": entry.action, "target_type": entry.target_type, "target_id": entry.target_id, "details": entry.details, "created_at": entry.created_at.isoformat()} for entry in logs]


@router.get("/")
async def admin_placeholder() -> dict[str, str]:
    """admin — verification queue, dispute resolution."""
    return {"module": "admin", "status": "not_implemented"}
