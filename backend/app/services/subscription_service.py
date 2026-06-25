"""
Subscription service: trial creation, state resolution, and lifecycle management.
"""
from __future__ import annotations

import math
from datetime import datetime, timezone, timedelta

from sqlalchemy.orm import Session

from app.db.models import Subscription


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _ensure_aware(dt: datetime) -> datetime:
    """
    Ensure dt is timezone-aware (UTC).
    SQLite returns naive datetimes even for DateTime(timezone=True) columns;
    this helper attaches UTC in that case so comparisons always work.
    """
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


def get_or_create(session: Session, user_id: str, trial_dias: int = 7) -> Subscription:
    """Return existing Subscription or create a new trial for user_id."""
    sub = session.query(Subscription).filter(Subscription.user_id == user_id).first()
    if sub is None:
        sub = Subscription(
            user_id=user_id,
            estado="trial",
            trial_ends_at=_now() + timedelta(days=trial_dias),
        )
        session.add(sub)
        session.commit()
        session.refresh(sub)
    return sub


def estado_actual(sub: Subscription) -> str:
    """
    Resolve the effective subscription state:
      - "activa"    → paid and active
      - "cancelada" → user cancelled
      - "vencida"   → trial expired (trial_ends_at < now)
      - "trial"     → still within the trial window
    """
    if sub.estado == "activa":
        return "activa"
    if sub.estado == "cancelada":
        return "cancelada"
    # estado == "trial" (or any unrecognised value) → check expiry
    if sub.trial_ends_at is not None and _ensure_aware(sub.trial_ends_at) < _now():
        return "vencida"
    return "trial"


def dias_restantes(sub: Subscription) -> int:
    """
    Days left in the trial window (ceiling, minimum 0).
    Returns 0 for activa/cancelada/vencida states where a countdown is meaningless.
    """
    estado = estado_actual(sub)
    if estado in ("activa", "cancelada", "vencida"):
        return 0
    # estado == "trial" with a future trial_ends_at
    if sub.trial_ends_at is None:
        return 0
    delta = _ensure_aware(sub.trial_ends_at) - _now()
    return max(0, math.ceil(delta.total_seconds() / 86400))


def cancelar(session: Session, user_id: str) -> Subscription:
    """Set estado='cancelada' for the user's subscription. Creates it first if missing."""
    sub = get_or_create(session, user_id)
    sub.estado = "cancelada"
    session.commit()
    session.refresh(sub)
    return sub
