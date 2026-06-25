"""Tests for /api/v1/presupuestos and /api/v1/metas endpoints."""
from datetime import date, timedelta

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


@pytest.fixture
def ctx():
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
    yield TestSession
    app.dependency_overrides.clear()


@pytest.fixture
def client(ctx):
    return TestClient(app)


def _mk_gasto(session, categoria, monto):
    t = Transaction(
        user_id="u1",
        fecha=date.today(),
        descripcion=categoria,
        monto=monto,
        moneda="CLP",
        tipo="gasto",
        categoria=categoria,
        banco="x",
        fuente="test",
    )
    session.add(t)
    session.commit()


# ---------------------------------------------------------------------------
# Presupuestos
# ---------------------------------------------------------------------------

def test_post_presupuesto_200_y_shape(client):
    r = client.post(
        "/api/v1/presupuestos",
        json={"categoria": "Comida y delivery", "monto_tope": 100000},
    )
    assert r.status_code == 200
    body = r.json()
    for key in ("categoria", "monto_tope", "gastado", "pct", "estado"):
        assert key in body
    assert body["categoria"] == "Comida y delivery"
    assert body["monto_tope"] == 100000
    assert body["estado"] == "ok"


def test_post_presupuesto_categoria_invalida_422(client):
    r = client.post(
        "/api/v1/presupuestos",
        json={"categoria": "NoExiste", "monto_tope": 1000},
    )
    assert r.status_code == 422


def test_get_presupuestos_lista(ctx, client):
    s = ctx()
    client.post(
        "/api/v1/presupuestos",
        json={"categoria": "Compras", "monto_tope": 10000},
    )
    _mk_gasto(s, "Compras", -15000)
    r = client.get("/api/v1/presupuestos")
    assert r.status_code == 200
    body = r.json()
    assert "items" in body
    assert len(body["items"]) == 1
    assert body["items"][0]["categoria"] == "Compras"
    assert body["items"][0]["estado"] == "excedido"


def test_delete_presupuesto_200(client):
    client.post(
        "/api/v1/presupuestos",
        json={"categoria": "Salud", "monto_tope": 5000},
    )
    r = client.delete("/api/v1/presupuestos/Salud")
    assert r.status_code == 200
    assert r.json()["ok"] is True
    r2 = client.get("/api/v1/presupuestos")
    assert r2.json()["items"] == []


def test_get_presupuestos_requires_auth():
    app.dependency_overrides.clear()
    c = TestClient(app)
    assert c.get("/api/v1/presupuestos").status_code in (401, 403)


# ---------------------------------------------------------------------------
# Metas
# ---------------------------------------------------------------------------

def test_post_meta_y_get_metas_con_progreso(client):
    r = client.post(
        "/api/v1/metas",
        json={"nombre": "Viaje", "monto_objetivo": 100000},
    )
    assert r.status_code == 200
    body = r.json()
    for key in (
        "id",
        "nombre",
        "monto_objetivo",
        "monto_actual",
        "fecha_objetivo",
        "progreso",
        "aporte_mensual_necesario",
    ):
        assert key in body
    assert body["nombre"] == "Viaje"
    assert body["progreso"] == 0.0

    r2 = client.get("/api/v1/metas")
    assert r2.status_code == 200
    items = r2.json()["items"]
    assert len(items) == 1
    assert items[0]["nombre"] == "Viaje"


def test_post_meta_con_fecha_aporte(client):
    fecha = (date.today() + timedelta(days=60)).isoformat()
    r = client.post(
        "/api/v1/metas",
        json={"nombre": "Notebook", "monto_objetivo": 200000, "fecha_objetivo": fecha},
    )
    assert r.status_code == 200
    body = r.json()
    assert body["fecha_objetivo"] == fecha
    assert body["aporte_mensual_necesario"] is not None
    assert body["aporte_mensual_necesario"] > 0


def test_patch_meta_monto_actual(client):
    r = client.post(
        "/api/v1/metas",
        json={"nombre": "Viaje", "monto_objetivo": 100000},
    )
    meta_id = r.json()["id"]
    r2 = client.patch(f"/api/v1/metas/{meta_id}", json={"monto_actual": 50000})
    assert r2.status_code == 200
    body = r2.json()
    assert body["monto_actual"] == 50000
    assert body["progreso"] == 0.5


def test_patch_meta_inexistente_404(client):
    r = client.patch("/api/v1/metas/no-existe", json={"monto_actual": 1})
    assert r.status_code == 404


def test_delete_meta_200(client):
    r = client.post(
        "/api/v1/metas",
        json={"nombre": "Viaje", "monto_objetivo": 100000},
    )
    meta_id = r.json()["id"]
    r2 = client.delete(f"/api/v1/metas/{meta_id}")
    assert r2.status_code == 200
    assert r2.json()["ok"] is True
    assert client.get("/api/v1/metas").json()["items"] == []


def test_get_metas_requires_auth():
    app.dependency_overrides.clear()
    c = TestClient(app)
    assert c.get("/api/v1/metas").status_code in (401, 403)
