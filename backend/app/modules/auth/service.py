import random
import time
from abc import ABC, abstractmethod
from dataclasses import dataclass


class SmsProvider(ABC):
    @abstractmethod
    async def send_otp(self, phone: str, otp: str) -> None:
        pass


class ConsoleSmsProvider(SmsProvider):
    async def send_otp(self, phone: str, otp: str) -> None:
        # Stub — swap for Algerian SMS gateway in production
        print(f"[SMS] OTP for {phone}: {otp}")


@dataclass
class OtpEntry:
    otp: str
    expires_at: float


class OtpStore:
    def __init__(self, ttl_seconds: int = 300) -> None:
        self._ttl = ttl_seconds
        self._store: dict[str, OtpEntry] = {}

    def generate(self, phone: str) -> str:
        # 6-digit, deterministic in tests via phone last digits? Use random for prod
        otp = f"{random.randint(100000, 999999)}"
        self._store[phone] = OtpEntry(otp=otp, expires_at=time.time() + self._ttl)
        return otp

    def verify(self, phone: str, otp: str) -> bool:
        entry = self._store.get(phone)
        if entry is None:
            return False
        if time.time() > entry.expires_at:
            self._store.pop(phone, None)
            return False
        if entry.otp != otp:
            return False
        # consume on success
        self._store.pop(phone, None)
        return True

    def get_current(self, phone: str) -> str | None:
        entry = self._store.get(phone)
        if entry is None or time.time() > entry.expires_at:
            return None
        return entry.otp

    def clear(self) -> None:
        self._store.clear()


otp_store = OtpStore()
sms_provider: SmsProvider = ConsoleSmsProvider()
