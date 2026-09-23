from fastapi import APIRouter

router = APIRouter()


@router.get("/health")
async def health_check() -> dict[str, str]:
    return {"status": "ok"}


@router.get("/health/db")
async def health_db() -> dict[str, str]:
    # Skeleton: no real DB check yet, just return ok
    # Will be extended to ping Postgres/Redis in later phases
    return {"status": "ok", "db": "not_checked"}
