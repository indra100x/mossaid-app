from fastapi import APIRouter

router = APIRouter(prefix="/bookings", tags=["bookings"])


@router.get("/")
async def bookings_placeholder() -> dict[str, str]:
    """bookings — booking state machine."""
    return {"module": "bookings", "status": "not_implemented"}
