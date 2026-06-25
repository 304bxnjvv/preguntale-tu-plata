"""
Tests for subscription_service: get_or_create, estado_actual, dias_restantes, cancelar.

Note: SQLite (used in tests via sqlite:///:memory:) strips timezone info from DateTime(timezone=True)
columns on read-back. We normalise with .replace(tzinfo=utc) where needed in comparisons.
"""
from datetime import datetime, timezone, timedelta

import pytest

from app.db.models import Subscription
from app.services import subscription_service


def _utc(dt: datetime) -> datetime:
    """Attach UTC if naive (SQLite strips tz on read-back)."""
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


# ── get_or_create ─────────────────────────────────────────────────────────────

def test_get_or_create_creates_trial(session):
    sub = subscription_service.get_or_create(session, "u1")
    assert sub.user_id == "u1"
    assert sub.estado == "trial"
    assert sub.trial_ends_at is not None
    # Should be roughly 7 days from now (within a 60-second window)
    delta = _utc(sub.trial_ends_at) - datetime.now(timezone.utc)
    assert timedelta(days=6, hours=23) < delta < timedelta(days=7, seconds=5)


def test_get_or_create_idempotent(session):
    sub1 = subscription_service.get_or_create(session, "u1")
    sub2 = subscription_service.get_or_create(session, "u1")
    assert sub1.id == sub2.id


def test_get_or_create_uses_custom_trial_dias(session):
    sub = subscription_service.get_or_create(session, "u1", trial_dias=14)
    delta = _utc(sub.trial_ends_at) - datetime.now(timezone.utc)
    assert timedelta(days=13, hours=23) < delta < timedelta(days=14, seconds=5)


# ── estado_actual ─────────────────────────────────────────────────────────────

def test_estado_actual_trial_active(session):
    sub = subscription_service.get_or_create(session, "u1")
    assert subscription_service.estado_actual(sub) == "trial"


def test_estado_actual_vencida_when_trial_ends_at_in_past(session):
    sub = subscription_service.get_or_create(session, "u1")
    # Backdate trial_ends_at to yesterday
    sub.trial_ends_at = datetime.now(timezone.utc) - timedelta(days=1)
    session.commit()
    assert subscription_service.estado_actual(sub) == "vencida"


def test_estado_actual_activa(session):
    sub = subscription_service.get_or_create(session, "u1")
    sub.estado = "activa"
    session.commit()
    assert subscription_service.estado_actual(sub) == "activa"


def test_estado_actual_cancelada(session):
    sub = subscription_service.get_or_create(session, "u1")
    sub.estado = "cancelada"
    session.commit()
    assert subscription_service.estado_actual(sub) == "cancelada"


# ── dias_restantes ────────────────────────────────────────────────────────────

def test_dias_restantes_trial_7_days(session):
    sub = subscription_service.get_or_create(session, "u1")
    dias = subscription_service.dias_restantes(sub)
    assert dias == 7


def test_dias_restantes_zero_when_vencida(session):
    sub = subscription_service.get_or_create(session, "u1")
    sub.trial_ends_at = datetime.now(timezone.utc) - timedelta(days=1)
    session.commit()
    assert subscription_service.dias_restantes(sub) == 0


def test_dias_restantes_zero_when_activa(session):
    sub = subscription_service.get_or_create(session, "u1")
    sub.estado = "activa"
    session.commit()
    assert subscription_service.dias_restantes(sub) == 0


def test_dias_restantes_zero_when_cancelada(session):
    sub = subscription_service.get_or_create(session, "u1")
    sub.estado = "cancelada"
    session.commit()
    assert subscription_service.dias_restantes(sub) == 0


# ── cancelar ─────────────────────────────────────────────────────────────────

def test_cancelar_sets_estado(session):
    subscription_service.get_or_create(session, "u1")
    sub = subscription_service.cancelar(session, "u1")
    assert sub.estado == "cancelada"
    assert subscription_service.estado_actual(sub) == "cancelada"


def test_cancelar_creates_and_cancels_in_one_step(session):
    # cancelar on a non-existing user should still work (get_or_create + cancel)
    sub = subscription_service.cancelar(session, "new_user")
    assert sub.estado == "cancelada"
