from fastapi import APIRouter

router = APIRouter(prefix="/auth", tags=["auth"])


@router.get("/")
async def auth_placeholder() -> dict[str, str]:
    """auth — phone/OTP signup & login, JWT issuance/refresh."""
    return {"module": "auth", "status": "not_implemented"}
