from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


class CheckoutCreateIn(BaseModel):
    booking_id: UUID
    amount: float = Field(..., gt=0, le=1000000, description="Amount in DZD")
    currency: str = Field(default="DZD", max_length=10)


class CheckoutOut(BaseModel):
    payment_id: UUID
    checkout_id: str
    checkout_url: str
    amount: float
    currency: str
    status: str


class PaymentOut(BaseModel):
    id: UUID
    booking_id: UUID
    client_id: UUID
    craftsman_id: UUID
    amount: float
    currency: str
    status: str
    gateway_checkout_id: str | None
    held_at: datetime | None
    released_at: datetime | None
    refunded_at: datetime | None
    disputed_at: datetime | None
    created_at: datetime

    model_config = {"from_attributes": True}


class WebhookIn(BaseModel):
    event_id: str = Field(..., description="Chargily event ID for idempotency")
    type: str = Field(..., description="Event type e.g. checkout.paid, checkout.failed, payment.refunded")
    data: dict[str, object] = Field(default_factory=dict)


class ReleaseIn(BaseModel):
    confirm: bool = Field(default=True)


class DisputeIn(BaseModel):
    reason: str | None = Field(None, max_length=1000)


class PayoutViewOut(BaseModel):
    pending_amount: float
    released_amount: float
    history: list[PaymentOut]
