from fastapi import APIRouter

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/")
async def admin_placeholder() -> dict[str, str]:
    """admin — verification queue, dispute resolution."""
    return {"module": "admin", "status": "not_implemented"}
