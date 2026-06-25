"""
Subscription routes: trial status, Flow checkout, webhook, cancel.
"""
from __future__ import annotations

from datetime import datetime, timezone, timedelta

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app.auth.jwt import get_current_user
from app.db.base import get_session
from app.models.schemas import SubscriptionOut, CheckoutOut, WebhookOut, CancelOut
from app.services import subscription_service
from app.services.flow_service import FlowNoConfigurado, crear_orden_suscripcion, verificar_webhook

router = APIRouter(tags=["subscription"])


@router.get("/subscription", response_model=SubscriptionOut)
def get_subscription(
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    sub = subscription_service.get_or_create(session, user_id)
    return SubscriptionOut(
        estado=subscription_service.estado_actual(sub),
        dias_restantes=subscription_service.dias_restantes(sub),
        trial_ends_at=sub.trial_ends_at,
        precio_clp=3990,
    )


@router.post("/subscription/checkout", response_model=CheckoutOut)
def checkout(
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    """Initiate a Flow payment. Returns the redirect URL."""
    # We need the user's email; for now we accept a placeholder and let the
    # real implementation source it from the JWT / Supabase profile.
    email = f"{user_id}@placeholder.local"
    try:
        url = crear_orden_suscripcion(user_id=user_id, email=email)
    except FlowNoConfigurado:
        raise HTTPException(status_code=503, detail="pago no configurado")
    return CheckoutOut(url=url)


@router.post("/subscription/webhook", response_model=WebhookOut)
async def webhook(request: Request, session: Session = Depends(get_session)):
    """
    Flow webhook — no auth header (Flow signs the payload instead).
    If verified, marks the subscription activa and sets periodo_fin (+30 days).
    """
    payload = await request.json()
    if not verificar_webhook(payload):
        raise HTTPException(status_code=400, detail="firma inválida")

    # Extract user_id from commerceOrder field (format: "sub-<user_id>")
    commerce_order: str = payload.get("commerceOrder", "")
    user_id = commerce_order.removeprefix("sub-")

    if user_id:
        sub = subscription_service.get_or_create(session, user_id)
        sub.estado = "activa"
        sub.periodo_fin = datetime.now(timezone.utc) + timedelta(days=30)
        session.commit()

    return WebhookOut(ok=True)


@router.post("/subscription/cancel", response_model=CancelOut)
def cancel(
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    sub = subscription_service.cancelar(session, user_id)
    return CancelOut(estado=subscription_service.estado_actual(sub))
