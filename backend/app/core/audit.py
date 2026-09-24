import logging
from typing import Any
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.audit_log import AuditLog

logger = logging.getLogger(__name__)


async def log_audit(
    session: AsyncSession,
    actor_id: UUID | None,
    action: str,
    target_type: str | None = None,
    target_id: str | None = None,
    details: dict[str, Any] | None = None,
) -> AuditLog:
    entry = AuditLog(actor_id=actor_id, action=action, target_type=target_type, target_id=target_id, details=details)
    session.add(entry)
    await session.flush()
    logger.info("AUDIT actor=%s action=%s target=%s/%s", actor_id, action, target_type, target_id)
    return entry
