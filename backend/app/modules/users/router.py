from fastapi import APIRouter

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/")
async def users_placeholder() -> dict[str, str]:
    """users — profile CRUD, craftsman trade categories."""
    return {"module": "users", "status": "not_implemented"}
