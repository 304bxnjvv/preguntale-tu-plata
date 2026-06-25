"""Tests for GET /api/v1/insights/suscripciones and /insights/comparativo."""
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.db.models  # noqa: F401
from app.main import app
from app.db.base import Base, get_session
from app.auth.jwt import get_current_user


@pytest.fixture
def client():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    TestSession = sessionmaker(bind=engine)

    def _override_session():
        s = TestSession()
        try:
            yield s
        finally:
            s.close()

    app.dependency_overrides[get_session] = _override_session
    app.dependency_overrides[get_current_user] = lambda: "u1"
    yield TestClient(app)
    app.dependency_overrides.clear()


def test_suscripciones_returns_200(client):
    r = client.get("/api/v1/insights/suscripciones")
    assert r.status_code == 200
    body = r.json()
    assert "total_mensual" in body
    assert "items" in body


def test_suscripciones_empty_when_no_data(client):
    r = client.get("/api/v1/insights/suscripciones")
    assert r.status_code == 200
    body = r.json()
    assert body["total_mensual"] == 0.0
    assert body["items"] == []


def test_comparativo_returns_200(client):
    r = client.get("/api/v1/insights/comparativo")
    assert r.status_code == 200
    body = r.json()
    for key in ("mes_actual", "mes_anterior", "gastos_actual", "gastos_anterior", "delta", "top_cambios"):
        assert key in body


def test_suscripciones_requires_auth():
    app.dependency_overrides.clear()
    c = TestClient(app)
    r = c.get("/api/v1/insights/suscripciones")
    assert r.status_code in (401, 403)


def test_comparativo_requires_auth():
    app.dependency_overrides.clear()
    c = TestClient(app)
    r = c.get("/api/v1/insights/comparativo")
    assert r.status_code in (401, 403)
