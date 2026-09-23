from datetime import UTC, datetime, timedelta
from uuid import UUID

from jose import JWTError, jwt

from app.core.config import settings


def create_access_token(*, subject: str, expires_minutes: int | None = None) -> str:
    expire = datetime.now(UTC) + timedelta(
        minutes=expires_minutes or settings.jwt_access_token_expire_minutes
    )
    to_encode: dict[str, object] = {"sub": subject, "exp": expire, "type": "access"}
    return str(jwt.encode(to_encode, settings.jwt_secret_key, algorithm=settings.jwt_algorithm))


def create_refresh_token(*, subject: str) -> str:
    expire = datetime.now(UTC) + timedelta(days=settings.jwt_refresh_token_expire_days)
    to_encode: dict[str, object] = {"sub": subject, "exp": expire, "type": "refresh"}
    return str(jwt.encode(to_encode, settings.jwt_secret_key, algorithm=settings.jwt_algorithm))


def decode_token(token: str) -> dict[str, object]:
    try:
        payload: dict[str, object] = jwt.decode(
            token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm]
        )
        return payload
    except JWTError as exc:
        raise ValueError(str(exc)) from exc


def get_subject_from_payload(payload: dict[str, object]) -> UUID:
    sub = payload.get("sub")
    if not isinstance(sub, str):
        raise ValueError("Invalid subject")
    return UUID(sub)
