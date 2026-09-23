from collections.abc import AsyncGenerator

import pytest
from sqlalchemy import create_engine as create_sync_engine
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

# Import models to register metadata before create_all
import app.models  # noqa: F401
import app.modules.chat.router as chat_router
from app.core.database import Base, get_session
from app.main import app

TEST_DB_URL = "sqlite+aiosqlite:////tmp/mossaid_test.db"
SYNC_DB_URL = "sqlite:////tmp/mossaid_test.db"

engine = create_async_engine(
    TEST_DB_URL, echo=False, future=True, connect_args={"check_same_thread": False}, poolclass=NullPool
)
sync_engine = create_sync_engine(SYNC_DB_URL, connect_args={"check_same_thread": False}, poolclass=NullPool)
TestingSessionLocal = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)


@pytest.fixture(autouse=True)
def setup_db() -> None:
    Base.metadata.create_all(sync_engine)
    yield
    Base.metadata.drop_all(sync_engine)


@pytest.fixture
async def session() -> AsyncGenerator[AsyncSession, None]:
    async with TestingSessionLocal() as sess:
        yield sess


@pytest.fixture(autouse=True)
async def override_get_session() -> AsyncGenerator[None, None]:
    async def _get_session() -> AsyncGenerator[AsyncSession, None]:
        async with TestingSessionLocal() as sess:
            yield sess

    app.dependency_overrides[get_session] = _get_session
    yield
    app.dependency_overrides.pop(get_session, None)


@pytest.fixture(autouse=True)
def clear_otp_store() -> None:
    from app.modules.auth.service import otp_store

    otp_store.clear()
    yield
    otp_store.clear()


@pytest.fixture(autouse=True)
def patch_chat_session() -> None:
    # Chat websocket uses async_session_factory directly, override for SQLite tests
    original = chat_router.async_session_factory
    chat_router.async_session_factory = TestingSessionLocal  # type: ignore[assignment]
    # Disable Redis for tests
    orig_redis = chat_router.redis_pub
    chat_router.redis_pub = None
    # Clear in-memory rooms
    chat_router.manager._rooms.clear()
    yield
    chat_router.async_session_factory = original  # type: ignore[assignment]
    chat_router.redis_pub = orig_redis
    chat_router.manager._rooms.clear()
