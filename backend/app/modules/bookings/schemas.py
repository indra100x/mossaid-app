from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field


class BookingCreateIn(BaseModel):
    craftsman_id: UUID
    trade: str = Field(..., min_length=2, max_length=50, description="Free-form trade")
    description: str = Field(..., min_length=10, max_length=2000)
    address: str = Field(..., min_length=5, max_length=500)
    scheduled_at: datetime


class BookingOut(BaseModel):
    id: UUID
    client_id: UUID
    craftsman_id: UUID
    trade: str
    description: str
    address: str
    scheduled_at: datetime
    status: str
    price_agreed: float | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class BookingStatusUpdateIn(BaseModel):
    action: Literal["accept", "decline", "schedule", "start", "complete", "cancel"]


ACTION_TO_STATUS = {
    "accept": "accepted",
    "decline": "declined",
    "schedule": "scheduled",
    "start": "in_progress",
    "complete": "completed",
    "cancel": "cancelled",
}
