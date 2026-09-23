from collections.abc import AsyncGenerator

import pytest
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

# Import models to register metadata before create_all
import app.models  # noqa: F401
from app.core.database import Base, get_session
from app.main import app

TEST_DB_URL = "sqlite+aiosqlite:///:memory:"

engine = create_async_engine(TEST_DB_URL, echo=False, future=True)
TestingSessionLocal = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)


@pytest.fixture(autouse=True)
async def setup_db() -> AsyncGenerator[None, None]:
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


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
