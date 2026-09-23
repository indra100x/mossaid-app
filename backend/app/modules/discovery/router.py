from fastapi import APIRouter

router = APIRouter(prefix="/discovery", tags=["discovery"])


@router.get("/")
async def discovery_placeholder() -> dict[str, str]:
    """discovery — search & filter craftsmen."""
    return {"module": "discovery", "status": "not_implemented"}
