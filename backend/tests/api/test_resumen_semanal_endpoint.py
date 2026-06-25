"""Task S2: Tests para GET /api/v1/insights/resumen-semanal."""
from datetime import date, timedelta

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.db.models  # noqa: F401
from app.main import app
from app.db.base import Base, get_session
from app.auth.jwt import get_current_user
from app.db.models import Transaction


def _make_client():
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
    return TestClient(app), TestSession


def test_resumen_semanal_200_y_shape():
    client, _ = _make_client()
    r = client.get("/api/v1/insights/resumen-semanal")
    app.dependency_overrides.clear()
    assert r.status_code == 200
    body = r.json()
    for key in ("tiene_datos", "periodo", "gasto_semana", "top_categoria", "top_monto", "delta_pct", "texto"):
        assert key in body, f"Missing key: {key}"


def test_resumen_semanal_sin_datos():
    client, _ = _make_client()
    r = client.get("/api/v1/insights/resumen-semanal")
    app.dependency_overrides.clear()
    assert r.status_code == 200
    body = r.json()
    assert body["tiene_datos"] is False
    assert body["gasto_semana"] == 0


def test_resumen_semanal_con_datos():
    client, TestSession = _make_client()
    # Sembrar transacciones en la ventana de los últimos 7 días
    hoy = date.today()
    s = TestSession()
    s.add(Transaction(
        user_id="u1",
        fecha=hoy - timedelta(days=1),
        descripcion="supermercado",
        monto=-20000,
        moneda="CLP",
        tipo="gasto",
        categoria="Comida y delivery",
        banco="b",
        fuente="test",
    ))
    s.add(Transaction(
        user_id="u1",
        fecha=hoy - timedelta(days=2),
        descripcion="metro",
        monto=-5000,
        moneda="CLP",
        tipo="gasto",
        categoria="Transporte",
        banco="b",
        fuente="test",
    ))
    s.commit()
    s.close()

    r = client.get("/api/v1/insights/resumen-semanal")
    app.dependency_overrides.clear()
    assert r.status_code == 200
    body = r.json()
    assert body["tiene_datos"] is True
    assert body["gasto_semana"] == 25000
    assert body["top_categoria"] == "Comida y delivery"
    assert body["top_monto"] == 20000
    assert isinstance(body["texto"], str) and len(body["texto"]) > 0


def test_resumen_semanal_requires_auth():
    app.dependency_overrides.clear()
    c = TestClient(app)
    r = c.get("/api/v1/insights/resumen-semanal")
    assert r.status_code in (401, 403)
