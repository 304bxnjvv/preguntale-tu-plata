"""Tests para los endpoints de categorías personalizadas."""
import pytest
from datetime import date
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.db.models  # noqa
from app.main import app
from app.db.base import Base, get_session
from app.auth.jwt import get_current_user
from app.db.models import Transaction


@pytest.fixture
def ctx():
    eng = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(eng)
    TS = sessionmaker(bind=eng)

    def _ov():
        s = TS()
        try:
            yield s
        finally:
            s.close()

    app.dependency_overrides[get_session] = _ov
    app.dependency_overrides[get_current_user] = lambda: "u1"
    yield TS
    app.dependency_overrides.clear()


@pytest.fixture
def client(ctx):
    return TestClient(app)


# ---------------------------------------------------------------------------
# GET /categorias
# ---------------------------------------------------------------------------

def test_get_categorias_shape(client):
    r = client.get("/api/v1/categorias")
    assert r.status_code == 200
    body = r.json()
    assert "base" in body
    assert "personalizadas" in body
    assert "todas" in body
    assert len(body["base"]) == 11
    assert body["personalizadas"] == []
    assert body["todas"] == body["base"]


def test_get_categorias_includes_custom(client):
    client.post("/api/v1/categorias", json={"nombre": "Mascotas"})
    r = client.get("/api/v1/categorias")
    assert r.status_code == 200
    body = r.json()
    assert "Mascotas" in body["personalizadas"]
    assert "Mascotas" in body["todas"]
    assert len(body["todas"]) == 12


# ---------------------------------------------------------------------------
# POST /categorias
# ---------------------------------------------------------------------------

def test_post_categoria_crea(client):
    r = client.post("/api/v1/categorias", json={"nombre": "Mascotas"})
    assert r.status_code == 200
    assert r.json()["nombre"] == "Mascotas"


def test_post_categoria_trim(client):
    r = client.post("/api/v1/categorias", json={"nombre": "  Viajes  "})
    assert r.status_code == 200
    assert r.json()["nombre"] == "Viajes"


def test_post_categoria_duplicada_422(client):
    client.post("/api/v1/categorias", json={"nombre": "Mascotas"})
    r = client.post("/api/v1/categorias", json={"nombre": "Mascotas"})
    assert r.status_code == 422


def test_post_categoria_choque_base_422(client):
    r = client.post("/api/v1/categorias", json={"nombre": "Salud"})
    assert r.status_code == 422


def test_post_categoria_vacia_422(client):
    r = client.post("/api/v1/categorias", json={"nombre": "   "})
    assert r.status_code == 422


def test_post_categoria_demasiado_larga_422(client):
    r = client.post("/api/v1/categorias", json={"nombre": "A" * 31})
    assert r.status_code == 422


# ---------------------------------------------------------------------------
# DELETE /categorias/{nombre}
# ---------------------------------------------------------------------------

def test_delete_categoria_existente(client):
    client.post("/api/v1/categorias", json={"nombre": "Mascotas"})
    r = client.delete("/api/v1/categorias/Mascotas")
    assert r.status_code == 200
    assert r.json()["ok"] is True
    body = client.get("/api/v1/categorias").json()
    assert "Mascotas" not in body["personalizadas"]


def test_delete_categoria_inexistente(client):
    r = client.delete("/api/v1/categorias/NoExiste")
    assert r.status_code == 200
    assert r.json()["ok"] is False


# ---------------------------------------------------------------------------
# Auth tests
# ---------------------------------------------------------------------------

def test_get_categorias_requires_auth():
    app.dependency_overrides.clear()
    c = TestClient(app)
    r = c.get("/api/v1/categorias")
    assert r.status_code in (401, 403)


def test_post_categoria_requires_auth():
    app.dependency_overrides.clear()
    c = TestClient(app)
    r = c.post("/api/v1/categorias", json={"nombre": "Test"})
    assert r.status_code in (401, 403)


def test_delete_categoria_requires_auth():
    app.dependency_overrides.clear()
    c = TestClient(app)
    r = c.delete("/api/v1/categorias/Test")
    assert r.status_code in (401, 403)


# ---------------------------------------------------------------------------
# PATCH /transactions acepta categoría custom
# ---------------------------------------------------------------------------

def _mk_txn(session, desc="COMERCIO TEST", cat="Otros"):
    t = Transaction(
        user_id="u1",
        fecha=date(2026, 6, 1),
        descripcion=desc,
        monto=-1000,
        moneda="CLP",
        tipo="gasto",
        categoria=cat,
        banco="x",
        fuente="test",
    )
    session.add(t)
    session.commit()
    session.refresh(t)
    return t.id


def test_patch_transaction_acepta_categoria_custom(ctx):
    s = ctx()
    txn_id = _mk_txn(s)
    c = TestClient(app)
    # Crear la categoría custom
    c.post("/api/v1/categorias", json={"nombre": "Mascotas"})
    # PATCH a esa categoría custom
    r = c.patch(f"/api/v1/transactions/{txn_id}", json={"categoria": "Mascotas"})
    assert r.status_code == 200
    # Verificar que se guardó
    updated = s.query(Transaction).filter_by(id=txn_id).first()
    assert updated.categoria == "Mascotas"


def test_patch_transaction_rechaza_categoria_inexistente(ctx):
    s = ctx()
    txn_id = _mk_txn(s)
    c = TestClient(app)
    r = c.patch(f"/api/v1/transactions/{txn_id}", json={"categoria": "CategoriaQueNoExiste"})
    assert r.status_code == 422


# ---------------------------------------------------------------------------
# Presupuesto acepta categoría custom
# ---------------------------------------------------------------------------

def test_presupuesto_set_tope_acepta_categoria_custom(client):
    # Crear categoría custom
    client.post("/api/v1/categorias", json={"nombre": "Mascotas"})
    # Crear presupuesto con esa categoría
    r = client.post("/api/v1/presupuestos", json={"categoria": "Mascotas", "monto_tope": 50000})
    assert r.status_code == 200
    body = r.json()
    assert body["categoria"] == "Mascotas"
    assert body["monto_tope"] == 50000


def test_presupuesto_categoria_base_sigue_funcionando(client):
    r = client.post("/api/v1/presupuestos", json={"categoria": "Salud", "monto_tope": 30000})
    assert r.status_code == 200
    assert r.json()["categoria"] == "Salud"


def test_presupuesto_categoria_invalida_sigue_422(client):
    r = client.post("/api/v1/presupuestos", json={"categoria": "NoExiste", "monto_tope": 1000})
    assert r.status_code == 422
