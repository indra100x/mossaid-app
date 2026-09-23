import uuid
from datetime import UTC, datetime
from typing import TYPE_CHECKING

from sqlalchemy import JSON, DateTime, Float, ForeignKey, Integer, String
from sqlalchemy import UUID as SA_UUID
from sqlalchemy import Text as SA_Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.user import User  # noqa: F401


class CraftsmanProfile(Base):
    __tablename__ = "craftsman_profiles"

    user_id: Mapped[uuid.UUID] = mapped_column(
        SA_UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    # free-form trades, lowercased on write, not fixed enum; JSON for DB-agnostic (array on PG)
    trades: Mapped[list[str]] = mapped_column(JSON, nullable=False, default=list)
    bio: Mapped[str | None] = mapped_column(SA_Text, nullable=True)
    service_radius_km: Mapped[int] = mapped_column(Integer, nullable=False, default=10)
    latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    longitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    hourly_rate: Mapped[float | None] = mapped_column(Float, nullable=True)
    rating_avg: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    verification_status: Mapped[str] = mapped_column(String(20), nullable=False, default="pending")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=lambda: datetime.now(UTC)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )

    user: Mapped["User"] = relationship("User", back_populates="craftsman_profile")
