import re
import secrets
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_session
from app.core.deps import CurrentUser
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    verify_password,
)
from app.models.user import User
from app.modules.auth.schemas import (
    AdminLoginIn,
    RefreshIn,
    RefreshOut,
    RequestOtpIn,
    RequestOtpOut,
    TokenOut,
    UserOut,
    VerifyOtpIn,
)
from app.modules.auth.service import otp_store, sms_provider

router = APIRouter(prefix="/auth", tags=["auth"])

PHONE_RE = re.compile(r"^\+\d{8,15}$")


def validate_phone(phone: str) -> str:
    phone = phone.strip()
    if not PHONE_RE.match(phone):
        raise HTTPException(status_code=422, detail="Invalid phone format, expected E.164 like +213555123456")
    return phone


@router.post("/request-otp", response_model=RequestOtpOut, status_code=status.HTTP_200_OK)
async def request_otp(payload: RequestOtpIn) -> RequestOtpOut:
    phone = validate_phone(payload.phone)
    otp = otp_store.generate(phone)
    await sms_provider.send_otp(phone, otp)
    out = RequestOtpOut(phone=phone, expires_in=300)
    if settings.debug or settings.app_env == "local":
        out.otp = otp
    return out


@router.post("/verify-otp", response_model=TokenOut, status_code=status.HTTP_200_OK)
async def verify_otp(
    payload: VerifyOtpIn,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> TokenOut:
    phone = validate_phone(payload.phone)
    if not otp_store.verify(phone, payload.otp):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired OTP")

    result = await session.execute(select(User).where(User.phone == phone))
    user = result.scalar_one_or_none()

    if user is None:
        role = payload.role or "client"
        if role not in ("client", "craftsman"):
            role = "client"
        user = User(
            phone=phone,
            role=role,
            name=payload.name,
            language_pref=payload.language_pref or "fr",
            is_verified=True,
        )
        session.add(user)
        await session.commit()
        await session.refresh(user)
    else:
        updated = False
        if not user.is_verified:
            user.is_verified = True
            updated = True
        if payload.name and not user.name:
            user.name = payload.name
            updated = True
        if payload.language_pref:
            user.language_pref = payload.language_pref
            updated = True
        if updated:
            await session.commit()
            await session.refresh(user)

    access = create_access_token(subject=str(user.id))
    refresh = create_refresh_token(subject=str(user.id))
    return TokenOut(access_token=access, refresh_token=refresh, user=UserOut.from_user(user))


@router.post("/refresh", response_model=RefreshOut, status_code=status.HTTP_200_OK)
async def refresh_token(payload: RefreshIn) -> RefreshOut:
    try:
        data = decode_token(payload.refresh_token)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token") from None
    if data.get("type") != "refresh":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token type")
    sub = data.get("sub")
    if not isinstance(sub, str):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    access = create_access_token(subject=sub)
    return RefreshOut(access_token=access)


@router.get("/me", response_model=UserOut)
async def get_me(current_user: CurrentUser) -> UserOut:
    return UserOut.from_user(current_user)


@router.post("/admin-login", response_model=TokenOut, status_code=status.HTTP_200_OK)
async def admin_login(
    payload: AdminLoginIn,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> TokenOut:
    """Password login for the admin dashboard (non-technical admins).

    Credentials come from ADMIN_USERNAME / ADMIN_PASSWORD_HASH env (bcrypt hash,
    never plaintext). Empty hash disables the endpoint. Issues a super_admin
    JWT, so all dashboard tabs work with no manual token handling.
    """
    if not settings.admin_password_hash:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Admin password login is not configured")
    username_ok = secrets.compare_digest(payload.username.strip(), settings.admin_username)
    password_ok = verify_password(payload.password, settings.admin_password_hash)
    if not (username_ok and password_ok):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    phone = f"admin:{settings.admin_username}"
    result = await session.execute(select(User).where(User.phone == phone))
    user = result.scalar_one_or_none()
    if user is None:
        user = User(phone=phone, role="super_admin", name="Admin", language_pref="fr", is_verified=True)
        session.add(user)
        await session.commit()
        await session.refresh(user)
    elif user.is_suspended:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="User suspended")

    from app.core.audit import log_audit

    await log_audit(session, user.id, "admin.login", "user", str(user.id))
    await session.commit()

    access = create_access_token(subject=str(user.id))
    refresh = create_refresh_token(subject=str(user.id))
    return TokenOut(access_token=access, refresh_token=refresh, user=UserOut.from_user(user))


@router.get("/")
async def auth_placeholder() -> dict[str, str]:
    """auth — phone/OTP signup & login, JWT issuance/refresh."""
    return {"module": "auth", "status": "not_implemented"}
