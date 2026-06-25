"""Task B1: Tests para GET /api/v1/insights/alertas."""
import pytest
from datetime import date, timedelta
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


def test_alertas_200_y_shape(client):
    r = client.get("/api/v1/insights/alertas")
    assert r.status_code == 200
    body = r.json()
    assert "items" in body
    assert isinstance(body["items"], list)


def test_alertas_pinta_items(client):
    # Crear un presupuesto excedido para tener al menos una alerta
    from app.db.base import get_session as _gs  # noqa
    from app.services.presupuesto_service import set_tope
    from app.db.models import Transaction

    # Acceder a la sesión del override para sembrar datos
    gen = app.dependency_overrides[get_session]()
    s = next(gen)
    set_tope(s, "u1", "Compras", 10000)
    s.add(
        Transaction(
            user_id="u1",
            fecha=date.today(),
            descripcion="Compras",
            monto=-15000,
            moneda="CLP",
            tipo="gasto",
            categoria="Compras",
            banco="test",
            fuente="test",
        )
    )
    s.commit()

    r = client.get("/api/v1/insights/alertas")
    assert r.status_code == 200
    items = r.json()["items"]
    assert len(items) >= 1
    a = items[0]
    for key in ("key", "tipo", "severidad", "titulo", "detalle", "fecha"):
        assert key in a


def test_alertas_requires_auth():
    app.dependency_overrides.clear()
    c = TestClient(app)
    assert c.get("/api/v1/insights/alertas").status_code in (401, 403)
