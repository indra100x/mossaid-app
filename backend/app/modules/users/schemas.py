from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field


class CraftsmanProfileOut(BaseModel):
    trades: list[str] = Field(default_factory=list)
    bio: str | None = None
    service_radius_km: int = 10
    latitude: float | None = None
    longitude: float | None = None
    hourly_rate: float | None = None
    rating_avg: float = 0.0
    verification_status: str = "pending"

    model_config = {"from_attributes": True}


class UserOut(BaseModel):
    id: UUID
    phone: str
    role: str
    name: str | None
    language_pref: str
    is_verified: bool
    created_at: datetime
    craftsman_profile: CraftsmanProfileOut | None = None

    model_config = {"from_attributes": True}


class CraftsmanProfileIn(BaseModel):
    trades: list[str] | None = Field(None, description="Free-form trade names")
    bio: str | None = Field(None, max_length=2000)
    service_radius_km: int | None = Field(None, ge=1, le=200)
    latitude: float | None = Field(None, ge=-90, le=90)
    longitude: float | None = Field(None, ge=-180, le=180)
    hourly_rate: float | None = Field(None, ge=0, le=100000)

    def normalized_trades(self) -> list[str] | None:
        if self.trades is None:
            return None
        # free-form, lowercased, deduped, 2-50 chars, not fixed enum
        out: list[str] = []
        seen: set[str] = set()
        for t in self.trades:
            if not isinstance(t, str):
                continue
            tt = t.strip().lower()
            if len(tt) < 2 or len(tt) > 50:
                continue
            if tt in seen:
                continue
            seen.add(tt)
            out.append(tt)
        return out


class UserUpdateIn(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=100)
    language_pref: Literal["ar", "fr"] | None = None
    role: Literal["client", "craftsman"] | None = None
    craftsman_profile: CraftsmanProfileIn | None = None


class VerificationRequestIn(BaseModel):
    doc_type: Literal["id", "diploma", "trade_credential"] = Field(..., description="Document type")
    file_name: str = Field(..., min_length=1, max_length=255, description="Original file name with extension")


class VerificationOut(BaseModel):
    id: UUID
    user_id: UUID
    doc_type: str
    file_url: str
    status: str
    reviewed_by: UUID | None = None
    created_at: datetime

    model_config = {"from_attributes": True}


class RequestUploadOut(BaseModel):
    document: VerificationOut
    upload_url: str
    file_url: str
