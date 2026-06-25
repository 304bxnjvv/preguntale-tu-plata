"""Task F2: Tests para GET /api/v1/insights/forecast."""
from datetime import date

import pytest
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


def test_forecast_returns_200():
    client, _ = _make_client()
    r = client.get("/api/v1/insights/forecast")
    app.dependency_overrides.clear()
    assert r.status_code == 200


def test_forecast_shape():
    """Verifica que la respuesta contiene todos los campos requeridos."""
    client, _ = _make_client()
    r = client.get("/api/v1/insights/forecast")
    app.dependency_overrides.clear()
    assert r.status_code == 200
    body = r.json()
    for key in (
        "tiene_datos",
        "dias_restantes",
        "dia_del_mes",
        "gasto_actual",
        "gasto_proyectado",
        "ingresos_mes",
        "neto_proyectado",
        "categorias_en_riesgo",
        "confianza",
        "caveat",
    ):
        assert key in body, f"Missing key: {key}"


def test_forecast_sin_datos():
    """Sin transacciones → tiene_datos=False."""
    client, _ = _make_client()
    r = client.get("/api/v1/insights/forecast")
    app.dependency_overrides.clear()
    assert r.status_code == 200
    body = r.json()
    assert body["tiene_datos"] is False
    assert body["gasto_actual"] == 0
    assert body["categorias_en_riesgo"] == []


def test_forecast_con_gastos():
    """Con gastos → tiene_datos=True, gasto_actual correcto."""
    client, TestSession = _make_client()
    hoy = date.today()
    s = TestSession()
    s.add(Transaction(
        user_id="u1",
        fecha=date(hoy.year, hoy.month, 1),
        descripcion="supermercado",
        monto=-50000,
        moneda="CLP",
        tipo="gasto",
        categoria="Comida y delivery",
        banco="b",
        fuente="test",
    ))
    s.commit()
    s.close()

    r = client.get("/api/v1/insights/forecast")
    app.dependency_overrides.clear()
    assert r.status_code == 200
    body = r.json()
    assert body["tiene_datos"] is True
    assert body["gasto_actual"] == 50000
    assert body["gasto_proyectado"] >= 50000
    assert isinstance(body["categorias_en_riesgo"], list)
    assert body["confianza"] in ("baja", "media", "alta")


def test_forecast_requires_auth():
    app.dependency_overrides.clear()
    c = TestClient(app)
    r = c.get("/api/v1/insights/forecast")
    assert r.status_code in (401, 403)


def test_forecast_categorias_en_riesgo_shape():
    """Si hay categorías en riesgo, cada elemento tiene los campos correctos."""
    client, TestSession = _make_client()
    hoy = date.today()
    s = TestSession()
    # Agregar gasto y presupuesto para que haya riesgo
    s.add(Transaction(
        user_id="u1",
        fecha=date(hoy.year, hoy.month, 1),
        descripcion="comida",
        monto=-50000,
        moneda="CLP",
        tipo="gasto",
        categoria="Comida y delivery",
        banco="b",
        fuente="test",
    ))
    from app.db.models import Presupuesto
    s.add(Presupuesto(
        user_id="u1",
        categoria="Comida y delivery",
        monto_tope=30000,
    ))
    s.commit()
    s.close()

    r = client.get("/api/v1/insights/forecast")
    app.dependency_overrides.clear()
    assert r.status_code == 200
    body = r.json()
    # If there are categories en riesgo, check shape
    for item in body["categorias_en_riesgo"]:
        assert "categoria" in item
        assert "tope" in item
        assert "proyectado" in item
        assert "pct" in item
