from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field

from app.models.user import User


class RequestOtpIn(BaseModel):
    phone: str = Field(..., description="E.164 format, e.g. +213555123456")
    # optional for compatibility
    channel: str | None = None


class RequestOtpOut(BaseModel):
    phone: str
    expires_in: int = 300
    # Only returned in DEBUG/local
    otp: str | None = None


class VerifyOtpIn(BaseModel):
    phone: str
    otp: str = Field(..., min_length=6, max_length=6, description="6-digit OTP")
    name: str | None = Field(None, max_length=100)
    role: Literal["client", "craftsman"] | None = None
    language_pref: Literal["ar", "fr"] | None = None


class TokenOut(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: "UserOut"


class RefreshIn(BaseModel):
    refresh_token: str


class RefreshOut(BaseModel):
    access_token: str
    token_type: str = "bearer"


class AdminLoginIn(BaseModel):
    username: str = Field(..., min_length=1, max_length=100)
    password: str = Field(..., min_length=1, max_length=200)


class UserOut(BaseModel):
    id: UUID
    phone: str
    role: str
    name: str | None
    language_pref: str
    is_verified: bool
    created_at: datetime

    model_config = {"from_attributes": True}

    @classmethod
    def from_user(cls, user: User) -> "UserOut":
        return cls(
            id=user.id,
            phone=user.phone,
            role=user.role,
            name=user.name,
            language_pref=user.language_pref,
            is_verified=user.is_verified,
            created_at=user.created_at,
        )
