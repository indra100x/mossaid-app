from uuid import UUID

from pydantic import BaseModel, Field


class CraftsmanSearchOut(BaseModel):
    user_id: UUID
    name: str | None
    phone: str
    trades: list[str]
    bio: str | None
    hourly_rate: float | None
    rating_avg: float
    latitude: float | None
    longitude: float | None
    service_radius_km: int
    distance_km: float | None = None
    verification_status: str = "pending"

    model_config = {"from_attributes": True}


class SearchResponse(BaseModel):
    items: list[CraftsmanSearchOut]
    total: int
    limit: int
    offset: int


class SearchParams(BaseModel):
    trade: str | None = Field(None, description="Free-form trade, case-insensitive")
    lat: float | None = Field(None, ge=-90, le=90)
    lng: float | None = Field(None, ge=-180, le=180)
    radius_km: float | None = Field(None, ge=0.1, le=200, description="Search radius")
    min_rating: float | None = Field(None, ge=0, le=5)
    min_price: float | None = Field(None, ge=0)
    max_price: float | None = Field(None, ge=0)
    q: str | None = Field(None, max_length=100)
    limit: int = Field(20, ge=1, le=50)
    offset: int = Field(0, ge=0)
