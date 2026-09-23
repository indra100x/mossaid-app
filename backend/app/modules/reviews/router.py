from fastapi import APIRouter

router = APIRouter(prefix="/reviews", tags=["reviews"])


@router.get("/")
async def reviews_placeholder() -> dict[str, str]:
    """reviews — rating + comment after job completion."""
    return {"module": "reviews", "status": "not_implemented"}
