from fastapi import APIRouter

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("/")
async def notifications_placeholder() -> dict[str, str]:
    """notifications — push (FCM) + in-app."""
    return {"module": "notifications", "status": "not_implemented"}
