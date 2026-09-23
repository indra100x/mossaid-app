from datetime import datetime
from uuid import UUID

from pydantic import BaseModel


class MessageOut(BaseModel):
    id: UUID
    booking_id: UUID
    sender_id: UUID
    content: str
    sent_at: datetime
    read_at: datetime | None = None

    model_config = {"from_attributes": True}


class SendMessageIn(BaseModel):
    content: str
