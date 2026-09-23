import logging
from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.booking import Booking
from app.models.payment import Dispute, Payment

logger = logging.getLogger(__name__)


async def auto_release_expired_payments(session: AsyncSession) -> list[str]:
    """
    Auto-release escrow if booking is completed and client neither releases nor disputes within 7 days.
    Returns list of payment ids released. Logs clearly as money-moving side effect.
    """
    cutoff = datetime.now(UTC) - timedelta(days=settings.auto_release_days)
    # Find payments held where booking completed and held_at older than cutoff and no dispute
    result = await session.execute(
        select(Payment, Booking)
        .join(Booking, Payment.booking_id == Booking.id)
        .where(Payment.status == "held")
        .where(Booking.status == "completed")
        .where(Payment.held_at.is_not(None))
        .where(Payment.held_at < cutoff)
    )
    rows = result.all()
    released: list[str] = []
    for payment, booking in rows:
        # Check no dispute
        d_res = await session.execute(select(Dispute).where(Dispute.payment_id == payment.id))
        if d_res.scalar_one_or_none() is not None:
            continue
        # Check not already released (should be held)
        if payment.status != "held":
            continue
        payment.status = "released"
        payment.released_at = datetime.now(UTC)
        released.append(str(payment.id))
        logger.info(
            "AUTO-RELEASE Payment %s for booking %s (held since %s, cutoff %s) to craftsman %s — no dispute/release within %s days",
            payment.id,
            booking.id,
            payment.held_at,
            cutoff,
            payment.craftsman_id,
            settings.auto_release_days,
        )
    if released:
        await session.commit()
    else:
        logger.info("AUTO-RELEASE check at %s — no payments to release", datetime.now(UTC))
    return released


# Celery task wrapper (if Celery is configured)
try:
    from celery import shared_task

    @shared_task(name="payments.auto_release")  # type: ignore[untyped-decorator]
    def celery_auto_release() -> None:
        import asyncio

        from app.core.database import async_session_factory

        async def _run() -> None:
            async with async_session_factory() as sess:
                await auto_release_expired_payments(sess)

        asyncio.run(_run())

except Exception:
    # Celery not required for tests
    celery_auto_release = None
