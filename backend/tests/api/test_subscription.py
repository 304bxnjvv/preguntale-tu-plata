"""
Integration tests for /api/v1/subscription routes.
"""
from datetime import date

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.db.models  # noqa: F401 — registers all models on Base.metadata
import app.api.routes.subscription as sub_mod
from app.main import app
from app.db.base import Base, get_session
from app.auth.jwt import get_current_user
from app.db.models import Transaction
from app.models.schemas import Transaccion


@pytest.fixture
def client(monkeypatch):
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    TestSession = sessionmaker(bind=engine)
    shared_session = TestSession()

    def _override_session():
        yield shared_session

    app.dependency_overrides[get_session] = _override_session
    app.dependency_overrides[get_current_user] = lambda: "u1"
    yield TestClient(app), shared_session
    app.dependency_overrides.clear()
    shared_session.close()


# ── GET /subscription ─────────────────────────────────────────────────────────

def test_get_subscription_returns_trial(client):
    c, _ = client
    r = c.get("/api/v1/subscription")
    assert r.status_code == 200
    data = r.json()
    assert data["estado"] == "trial"
    assert data["dias_restantes"] == 7
    assert data["trial_ends_at"] is not None
    assert data["precio_clp"] == 3990


def test_get_subscription_idempotent(client):
    c, _ = client
    r1 = c.get("/api/v1/subscription")
    r2 = c.get("/api/v1/subscription")
    assert r1.json()["estado"] == r2.json()["estado"] == "trial"


# ── POST /subscription/checkout ───────────────────────────────────────────────

def test_checkout_503_when_no_flow_keys(client, monkeypatch):
    """Flow keys are empty by default in test env → expect 503."""
    c, _ = client
    r = c.post("/api/v1/subscription/checkout")
    assert r.status_code == 503
    assert r.json()["detail"] == "pago no configurado"


def test_checkout_returns_url_when_flow_configured(client, monkeypatch):
    """If Flow key present, crear_orden_suscripcion is called (mocked)."""
    c, _ = client
    monkeypatch.setattr(sub_mod, "crear_orden_suscripcion", lambda **kwargs: "https://flow.cl/pay/tok123")
    r = c.post("/api/v1/subscription/checkout")
    assert r.status_code == 200
    assert r.json()["url"] == "https://flow.cl/pay/tok123"


# ── POST /subscription/cancel ─────────────────────────────────────────────────

def test_cancel_returns_cancelada(client):
    c, _ = client
    r = c.post("/api/v1/subscription/cancel")
    assert r.status_code == 200
    assert r.json()["estado"] == "cancelada"


# ── POST /subscription/webhook ────────────────────────────────────────────────

def test_webhook_activates_subscription(client):
    c, session = client
    # Ensure subscription exists
    c.get("/api/v1/subscription")
    # Simulate Flow webhook
    r = c.post("/api/v1/subscription/webhook", json={"commerceOrder": "sub-u1", "status": 2})
    assert r.status_code == 200
    assert r.json()["ok"] is True
    # Check DB state
    from app.db.models import Subscription
    sub = session.query(Subscription).filter_by(user_id="u1").first()
    assert sub is not None
    assert sub.estado == "activa"
    assert sub.periodo_fin is not None
