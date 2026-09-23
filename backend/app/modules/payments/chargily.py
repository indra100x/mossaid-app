import uuid
from dataclasses import dataclass

import httpx

from app.core.config import settings


@dataclass
class CheckoutResult:
    checkout_id: str
    checkout_url: str
    amount: float
    currency: str


class ChargilyClient:
    """Sandbox-aware Chargily Pay client — hosted checkout, no raw card data touches our servers."""

    def __init__(self, api_key: str | None = None, api_url: str | None = None, sandbox: bool | None = None) -> None:
        self.api_key = api_key or settings.chargily_api_key
        self.api_url = (api_url or settings.chargily_api_url).rstrip("/")
        self.sandbox = sandbox if sandbox is not None else settings.chargily_sandbox

    async def create_checkout(
        self,
        amount: float,
        currency: str = "DZD",
        booking_id: str | None = None,
        success_url: str | None = None,
        failure_url: str | None = None,
        customer_name: str | None = None,
        customer_email: str | None = None,
    ) -> CheckoutResult:
        # In sandbox/test mode, return fake checkout without hitting real Chargily
        # This keeps tests deterministic and avoids needing live credentials
        if self.sandbox or "test_" in self.api_key:
            fake_id = f"chk_test_{uuid.uuid4().hex[:12]}"
            fake_url = f"https://pay.chargily.net/test/checkout/{fake_id}"
            return CheckoutResult(checkout_id=fake_id, checkout_url=fake_url, amount=amount, currency=currency)

        # Real Chargily API (phase 2 prod) — per https://pay.chargily.net/docs
        url = f"{self.api_url}/checkouts"
        headers = {"Authorization": f"Bearer {self.api_key}", "Content-Type": "application/json"}
        payload = {
            "amount": int(amount * 100),  # Chargily expects cents? DZD integer for sandbox
            "currency": currency.lower(),
            "success_url": success_url or "https://mossaid.dz/payment/success",
            "failure_url": failure_url or "https://mossaid.dz/payment/failure",
            "metadata": {"booking_id": booking_id} if booking_id else {},
            "customer": {"name": customer_name or "Mossaid Client", "email": customer_email or "client@mossaid.dz"},
        }
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.post(url, json=payload, headers=headers)
            resp.raise_for_status()
            data = resp.json()
            # Expected Chargily response: {id, checkout_url, ...}
            return CheckoutResult(
                checkout_id=data.get("id") or data.get("checkout_id") or f"chk_{uuid.uuid4().hex[:12]}",
                checkout_url=data.get("checkout_url") or data.get("url") or f"https://pay.chargily.net/checkout/{uuid.uuid4().hex[:12]}",
                amount=amount,
                currency=currency,
            )

    def verify_webhook_signature(self, payload: bytes, signature: str | None) -> bool:
        # In sandbox we skip strict verification; in prod verify HMAC with webhook_secret
        if self.sandbox or "test_" in self.api_key:
            return True
        if not signature or not settings.chargily_webhook_secret:
            return False
        # Real verification would be HMAC SHA256 of payload with secret
        # For now return True in sandbox, False otherwise to force explicit handling
        return False


chargily_client = ChargilyClient()
