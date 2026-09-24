import logging
from datetime import UTC, datetime
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.core.deps import CurrentUser
from app.core.rbac import is_admin_tier, require_permission
from app.models.booking import Booking
from app.models.payment import Dispute, Payment, WebhookEvent
from app.modules.payments.chargily import chargily_client
from app.modules.payments.schemas import (
    CheckoutCreateIn,
    CheckoutOut,
    DisputeIn,
    PaymentOut,
    PayoutViewOut,
    WebhookIn,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/payments", tags=["payments"])


def _require_client(current_user: CurrentUser, booking: Booking) -> None:
    if booking.client_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only client can perform this action")


@router.post("/checkouts", response_model=CheckoutOut, status_code=status.HTTP_201_CREATED)
async def create_checkout(
    payload: CheckoutCreateIn,
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> CheckoutOut:
    # Validate booking
    result = await session.execute(select(Booking).where(Booking.id == payload.booking_id))
    booking = result.scalar_one_or_none()
    if booking is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking not found")
    if booking.client_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only client can create checkout")
    # Booking must be at least accepted/scheduled/in_progress — not requested/declined/cancelled
    if booking.status in ("requested", "declined", "cancelled"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Booking status {booking.status} not ready for payment")
    # Check existing payment for booking
    existing = await session.execute(select(Payment).where(Payment.booking_id == booking.id))
    if existing.scalar_one_or_none() is not None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Payment already exists for booking")

    # Create Chargily checkout (sandbox)
    checkout = await chargily_client.create_checkout(
        amount=payload.amount, currency=payload.currency, booking_id=str(booking.id)
    )

    payment = Payment(
        booking_id=booking.id,
        client_id=booking.client_id,
        craftsman_id=booking.craftsman_id,
        amount=payload.amount,
        currency=payload.currency,
        status="pending",
        gateway="chargily",
        gateway_checkout_id=checkout.checkout_id,
    )
    session.add(payment)
    await session.commit()
    await session.refresh(payment)
    logger.info("Payment %s created pending for booking %s amount %s via Chargily %s", payment.id, booking.id, payload.amount, checkout.checkout_id)
    return CheckoutOut(
        payment_id=payment.id,
        checkout_id=checkout.checkout_id,
        checkout_url=checkout.checkout_url,
        amount=payment.amount,
        currency=payment.currency,
        status=payment.status,
    )


@router.post("/webhook/chargily", status_code=status.HTTP_200_OK)
async def chargily_webhook(
    payload: WebhookIn,
    request: Request,
    session: Annotated[AsyncSession, Depends(get_session)],
    x_chargily_signature: str | None = Header(None),
) -> dict[str, str]:
    # Verify signature (sandbox bypass)
    body = await request.body()
    if not chargily_client.verify_webhook_signature(body, x_chargily_signature):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid webhook signature")

    # Idempotency: if event already processed, return ok without re-processing
    existing_event = await session.execute(select(WebhookEvent).where(WebhookEvent.event_id == payload.event_id))
    if existing_event.scalar_one_or_none() is not None:
        logger.info("Webhook %s already processed (idempotent)", payload.event_id)
        return {"status": "already_processed"}

    # Find payment by checkout_id
    checkout_id = payload.data.get("checkout_id") or payload.data.get("id")
    if not checkout_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Missing checkout_id in webhook data")

    result = await session.execute(select(Payment).where(Payment.gateway_checkout_id == checkout_id))
    payment = result.scalar_one_or_none()
    if payment is None:
        # Still record event to avoid replay storm, but return
        logger.warning("Webhook for unknown checkout %s event %s", checkout_id, payload.event_id)
        # Do not raise 404, return ok to stop retries, but log
        # Still record event as processed
        ev = WebhookEvent(event_id=payload.event_id, payment_id=None, type=payload.type)
        session.add(ev)
        await session.commit()
        return {"status": "unknown_checkout"}

    # Record event first for idempotency
    ev = WebhookEvent(event_id=payload.event_id, payment_id=payment.id, type=payload.type)
    session.add(ev)

    # Handle event types
    # Chargily pay-and-collect: checkout.paid -> funds collected, we mark held (escrow)
    # For Phase 2, our "held" is internal escrow, not Chargily's
    now = datetime.now(UTC)
    notify_event: str | None = None
    if payload.type in ("checkout.paid", "payment.succeeded", "checkout.success", "paid"):
        if payment.status == "pending":
            payment.status = "held"
            payment.held_at = now
            payment.last_event_id = payload.event_id
            pm_id = payload.data.get("payment_id") or payload.data.get("transaction_id")
            payment.gateway_payment_id = pm_id if isinstance(pm_id, str) else None
            logger.info("Payment %s held via webhook %s (Chargily paid)", payment.id, payload.event_id)
            notify_event = "held"
            try:
                from app.core.metrics import payment_held_total

                payment_held_total.inc()
            except Exception:
                pass
        else:
            logger.info("Webhook %s for payment %s status %s not pending, no transition", payload.event_id, payment.id, payment.status)
    elif payload.type in ("checkout.failed", "payment.failed", "failed"):
        if payment.status == "pending":
            payment.status = "refunded"
            payment.refunded_at = now
            payment.last_event_id = payload.event_id
            logger.info("Payment %s refunded via webhook failed %s", payment.id, payload.event_id)
            notify_event = "refunded"
    elif payload.type in ("refund", "payment.refunded", "checkout.refunded"):
        if payment.status in ("pending", "held", "disputed"):
            payment.status = "refunded"
            payment.refunded_at = now
            payment.last_event_id = payload.event_id
            logger.info("Payment %s refunded via webhook %s", payment.id, payload.event_id)
            notify_event = "refunded"
    else:
        logger.info("Unhandled webhook type %s for event %s", payload.type, payload.event_id)

    # Phase 3: push + in-app notification on escrow events (held/refunded).
    if notify_event is not None:
        try:
            from app.modules.notifications.service import notify_payment_event

            await notify_payment_event(session, payment, notify_event)
        except Exception as e:
            logger.warning("Payment notify failed for %s: %s", payment.id, e)

    await session.commit()
    return {"status": "processed"}


@router.post("/{payment_id}/release", response_model=PaymentOut)
async def release_payment(
    payment_id: UUID,
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> PaymentOut:
    result = await session.execute(select(Payment).where(Payment.id == payment_id))
    payment = result.scalar_one_or_none()
    if payment is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment not found")
    # Only client can release
    if payment.client_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only client can release")
    if payment.status != "held":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Payment not held (status={payment.status})")
    # Booking must be completed (per spec: after job completion)
    b_res = await session.execute(select(Booking).where(Booking.id == payment.booking_id))
    booking = b_res.scalar_one_or_none()
    if booking is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking not found")
    if booking.status != "completed":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Booking not completed")
    # Check dispute
    d_res = await session.execute(select(Dispute).where(Dispute.payment_id == payment.id))
    if d_res.scalar_one_or_none() is not None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Payment disputed, cannot release")

    payment.status = "released"
    payment.released_at = datetime.now(UTC)
    await session.commit()
    await session.refresh(payment)
    logger.info("Payment %s released by client %s to craftsman %s", payment.id, current_user.id, payment.craftsman_id)
    try:
        from app.core.metrics import payment_released_total
        from app.modules.notifications.service import notify_payment_event

        payment_released_total.inc()
        await notify_payment_event(session, payment, "released")
        await session.commit()
    except Exception as e:
        logger.warning("Payment release notify failed for %s: %s", payment.id, e)
    return PaymentOut.model_validate(payment)


@router.post("/{payment_id}/dispute", response_model=dict[str, object])
async def dispute_payment(
    payment_id: UUID,
    payload: DisputeIn,
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> dict[str, object]:
    result = await session.execute(select(Payment).where(Payment.id == payment_id))
    payment = result.scalar_one_or_none()
    if payment is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment not found")
    if payment.client_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only client can dispute")
    if payment.status != "held":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Payment not held (status={payment.status})")
    b_res = await session.execute(select(Booking).where(Booking.id == payment.booking_id))
    booking = b_res.scalar_one_or_none()
    if booking is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking not found")
    if booking.status != "completed":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Booking not completed")
    # Check already disputed
    existing = await session.execute(select(Dispute).where(Dispute.payment_id == payment.id))
    if existing.scalar_one_or_none() is not None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Already disputed")

    dispute = Dispute(payment_id=payment.id, booking_id=payment.booking_id, raised_by=current_user.id, reason=payload.reason, status="open")
    session.add(dispute)
    payment.status = "disputed"
    payment.disputed_at = datetime.now(UTC)
    await session.commit()
    await session.refresh(dispute)
    logger.warning("Payment %s disputed by client %s, frozen for admin review", payment.id, current_user.id)
    try:
        from app.core.metrics import payment_disputed_total
        from app.modules.notifications.service import notify_payment_event

        payment_disputed_total.inc()
        await notify_payment_event(session, payment, "disputed")
        await session.commit()
    except Exception as e:
        logger.warning("Payment dispute notify failed for %s: %s", payment.id, e)
    return {"status": "disputed", "dispute_id": str(dispute.id)}


@router.get("/me", response_model=list[PaymentOut])
async def list_my_payments(
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> list[PaymentOut]:
    result = await session.execute(
        select(Payment).where((Payment.client_id == current_user.id) | (Payment.craftsman_id == current_user.id)).order_by(Payment.created_at.desc())
    )
    payments = result.scalars().all()
    return [PaymentOut.model_validate(p) for p in payments]


@router.get("/payouts/me", response_model=PayoutViewOut)
async def craftsman_payouts(
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> PayoutViewOut:
    if current_user.role not in ("craftsman", "admin"):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only craftsman can view payouts")
    result = await session.execute(select(Payment).where(Payment.craftsman_id == current_user.id).order_by(Payment.created_at.desc()))
    payments = result.scalars().all()
    pending = sum(p.amount for p in payments if p.status in ("held", "released"))
    # released_amount = sum of released that are considered pending payout (not yet manually disbursed)
    # For v1, released == pending payout, history includes all
    released = sum(p.amount for p in payments if p.status == "released")
    history = [PaymentOut.model_validate(p) for p in payments]
    return PayoutViewOut(pending_amount=pending, released_amount=released, history=history)


@router.post("/{payment_id}/refund", response_model=PaymentOut)
async def refund_payment(
    payment_id: UUID,
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> PaymentOut:
    require_permission(current_user, "payments.refund")
    result = await session.execute(select(Payment).where(Payment.id == payment_id))
    payment = result.scalar_one_or_none()
    if payment is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment not found")
    if payment.status not in ("pending", "held", "disputed"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Cannot refund status {payment.status}")
    payment.status = "refunded"
    payment.refunded_at = datetime.now(UTC)
    # also resolve dispute if exists
    d_res = await session.execute(select(Dispute).where(Dispute.payment_id == payment.id))
    dispute = d_res.scalar_one_or_none()
    if dispute and dispute.status == "open":
        dispute.status = "resolved"
        dispute.resolved_at = datetime.now(UTC)
        dispute.resolved_by = current_user.id
    from app.core.audit import log_audit

    await log_audit(
        session,
        current_user.id,
        "payment.refund",
        "payment",
        str(payment.id),
        {"booking_id": str(payment.booking_id), "amount": payment.amount},
    )
    await session.commit()
    await session.refresh(payment)
    logger.info("Payment %s refunded by admin %s", payment.id, current_user.id)
    try:
        from app.modules.notifications.service import notify_payment_event

        await notify_payment_event(session, payment, "refunded")
        await session.commit()
    except Exception as e:
        logger.warning("Payment refund notify failed for %s: %s", payment.id, e)
    return PaymentOut.model_validate(payment)


@router.get("/{payment_id}", response_model=PaymentOut)
async def get_payment(
    payment_id: UUID,
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> PaymentOut:
    result = await session.execute(select(Payment).where(Payment.id == payment_id))
    payment = result.scalar_one_or_none()
    if payment is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment not found")
    if payment.client_id != current_user.id and payment.craftsman_id != current_user.id:
        # admin tiers can view too
        if not is_admin_tier(current_user):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not participant")
    return PaymentOut.model_validate(payment)


@router.get("/")
async def payments_placeholder() -> dict[str, str]:
    """payments — escrow gateway handling."""
    return {"module": "payments", "status": "not_implemented"}
