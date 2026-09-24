import logging
from typing import Any
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.booking import Booking
from app.models.device_token import DeviceToken
from app.models.notification import Notification
from app.models.payment import Payment

logger = logging.getLogger(__name__)


async def create_notification(
    session: AsyncSession,
    user_id: UUID,
    type: str,
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
) -> Notification:
    notif = Notification(user_id=user_id, type=type, title=title, body=body, data=data or {}, is_read=False)
    session.add(notif)
    await session.flush()
    # FCM push targeting stored device tokens, in-app as fallback per Phase 3 spec
    try:
        result = await session.execute(select(DeviceToken).where(DeviceToken.user_id == user_id))
        tokens = result.scalars().all()
        if tokens:
            from app.core.firebase import get_messaging, init_firebase

            if init_firebase():
                messaging = get_messaging()
                if messaging is not None:
                    # Use send_multicast for multiple tokens per user (spec: multiple tokens per user)
                    token_strs = [t.token for t in tokens]
                    # FCM data must be string values
                    data_str = {k: str(v) for k, v in (data or {}).items()}
                    try:
                        # Try multicast (firebase_admin 6.x)
                        if len(token_strs) == 1:
                            msg = messaging.Message(
                                notification=messaging.Notification(title=title, body=body),
                                data=data_str,
                                token=token_strs[0],
                            )
                            messaging.send(msg)
                            logger.info("FCM push sent to user %s type=%s title=%s", user_id, type, title)
                        else:
                            msg = messaging.MulticastMessage(
                                notification=messaging.Notification(title=title, body=body),
                                data=data_str,
                                tokens=token_strs,
                            )
                            batch = messaging.send_each_for_multicast(msg) if hasattr(messaging, "send_each_for_multicast") else messaging.send_multicast(msg)
                            # batch is BatchResponse
                            succ = getattr(batch, "success_count", len(token_strs))
                            fail = getattr(batch, "failure_count", 0)
                            logger.info("FCM multicast to user %s: %s success, %s failure type=%s", user_id, succ, fail, type)
                    except Exception as fe:
                        logger.warning("FCM send failed for user %s: %s", user_id, fe)
                else:
                    logger.info("FCM messaging unavailable, in-app only for user %s", user_id)
            else:
                logger.info("FCM not initialized, in-app fallback only for user %s type=%s", user_id, type)
        else:
            logger.info("No FCM tokens for user %s, in-app notification only type=%s", user_id, type)
    except Exception as e:
        logger.warning("FCM send failed for user %s: %s", user_id, e)
    return notif


async def notify_booking_status_change(session: AsyncSession, booking: Booking, new_status: str) -> None:
    # Notify both participants
    title = f"Booking {new_status}"
    body = f"Booking {booking.id} is now {new_status}"
    data = {"booking_id": str(booking.id), "status": new_status}
    await create_notification(session, booking.client_id, "booking_status", title, body, data)
    await create_notification(session, booking.craftsman_id, "booking_status", title, body, data)


async def notify_new_message(session: AsyncSession, booking: Booking, sender_id: UUID, content: str) -> None:
    # Notify the other participant
    recipient = booking.craftsman_id if sender_id == booking.client_id else booking.client_id
    title = "New message"
    body = content[:100]
    data = {"booking_id": str(booking.id), "sender_id": str(sender_id)}
    await create_notification(session, recipient, "new_message", title, body, data)


async def notify_payment_event(session: AsyncSession, payment: Payment, event: str) -> None:
    # Notify both
    title = f"Payment {event}"
    body = f"Payment {payment.id} is {event} for booking {payment.booking_id}"
    data = {"payment_id": str(payment.id), "booking_id": str(payment.booking_id), "status": payment.status}
    await create_notification(session, payment.client_id, "payment_event", title, body, data)
    await create_notification(session, payment.craftsman_id, "payment_event", title, body, data)
