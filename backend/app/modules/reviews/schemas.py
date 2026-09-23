from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


class ReviewCreateIn(BaseModel):
    booking_id: UUID
    rating: int = Field(..., ge=1, le=5)
    comment: str | None = Field(None, max_length=1000)


class ReviewOut(BaseModel):
    id: UUID
    booking_id: UUID
    client_id: UUID
    craftsman_id: UUID
    rating: int
    comment: str | None
    created_at: datetime

    model_config = {"from_attributes": True}
