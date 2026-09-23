from fastapi import APIRouter

router = APIRouter(prefix="/chat", tags=["chat"])


@router.get("/")
async def chat_placeholder() -> dict[str, str]:
    """chat — WebSocket 1:1 messaging."""
    return {"module": "chat", "status": "not_implemented"}
