from fastapi import APIRouter

router = APIRouter(prefix="/payments", tags=["payments"])


@router.get("/")
async def payments_placeholder() -> dict[str, str]:
    """payments — escrow gateway handling."""
    return {"module": "payments", "status": "not_implemented"}
