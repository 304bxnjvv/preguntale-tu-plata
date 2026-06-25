"""
Flow.cl integration scaffold.

Real Flow API shape (documented for future implementation):
  Base URL: https://www.flow.cl/api
  All requests require:
    - apiKey: your Flow API key
    - params signed with HMAC-SHA256 using flow_secret, appended as 's' field
  Payment order:  POST /payment/create
    Fields: apiKey, commerceOrder, subject, currency="CLP", amount, email,
            urlConfirmation (webhook), urlReturn, s (signature)
  Response: { url, token } → redirect user to url + "?token=" + token
  Webhook (urlConfirmation): Flow POSTs { token, commerceOrder, status, ... }
    - Verify by re-signing the payload and comparing with 's' field.
    - status == 2 → paid successfully.

See https://www.flow.cl/app/web/api.php for the official reference.
"""
from __future__ import annotations

import hashlib
import hmac
from app.config import settings


class FlowNoConfigurado(Exception):
    """Raised when Flow API credentials are not set in settings."""


def crear_orden_suscripcion(
    user_id: str,
    email: str,
    monto: int = 3990,
) -> str:
    """
    Build a Flow payment URL for a subscription order.

    Returns a URL the frontend should redirect the user to.
    Raises FlowNoConfigurado if flow_api_key is empty (not configured).

    Real implementation would:
      1. Build the parameter dict (apiKey, commerceOrder, subject, etc.)
      2. Sign it with HMAC-SHA256(flow_secret, sorted_params_string)
      3. POST to https://www.flow.cl/api/payment/create
      4. Return response["url"] + "?token=" + response["token"]
    """
    if not settings.flow_api_key:
        raise FlowNoConfigurado("Flow API key no configurada")

    # --- Placeholder for real implementation ---
    # import httpx, urllib.parse
    # params = {
    #     "apiKey": settings.flow_api_key,
    #     "commerceOrder": f"sub-{user_id}",
    #     "subject": "Suscripción mensual Pregúntale a tu plata",
    #     "currency": "CLP",
    #     "amount": monto,
    #     "email": email,
    #     "urlConfirmation": "https://api.tudominio.cl/api/v1/subscription/webhook",
    #     "urlReturn": "https://tudominio.cl/suscripcion?resultado=ok",
    # }
    # sign_str = "".join(f"{k}{v}" for k, v in sorted(params.items()))
    # params["s"] = hmac.new(
    #     settings.flow_secret.encode(), sign_str.encode(), hashlib.sha256
    # ).hexdigest()
    # resp = httpx.post("https://www.flow.cl/api/payment/create", data=params)
    # resp.raise_for_status()
    # data = resp.json()
    # return data["url"] + "?token=" + data["token"]

    raise NotImplementedError("Flow real integration not yet wired")  # pragma: no cover


def verificar_webhook(payload: dict) -> bool:
    """
    Verify that a webhook payload from Flow is authentic.

    Stub: returns True.
    Real implementation:
      1. Extract 's' (signature) from payload.
      2. Rebuild the sign string from sorted remaining fields.
      3. Compare HMAC-SHA256(flow_secret, sign_str) == s.
      4. Also check payload["status"] == 2 (paid).
    """
    return True
