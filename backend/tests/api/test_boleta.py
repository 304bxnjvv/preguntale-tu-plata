"""Task V2: Tests para POST /transactions/boleta y POST /transactions/manual."""
import io
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
def client(monkeypatch):
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

    # Evita llamar a pgvector/red en el test
    monkeypatch.setattr(
        "app.api.routes.upload.indexar_transacciones", lambda txns, user_id: len(txns)
    )

    app.dependency_overrides[get_session] = _override_session
    app.dependency_overrides[get_current_user] = lambda: "u1"
    yield TestClient(app)
    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# POST /transactions/boleta
# ---------------------------------------------------------------------------

def _fake_boleta_ok(monkeypatch):
    """Monkeypatch extraer_boleta para devolver draft válido."""
    monkeypatch.setattr(
        "app.api.routes.upload.extraer_boleta",
        lambda content, ext: {
            "comercio": "LIDER",
            "monto": -12990.0,
            "fecha": "2026-06-20",
            "categoria": "Supermercado",
        },
    )


def _fake_boleta_none(monkeypatch):
    """Monkeypatch extraer_boleta para devolver None (imagen no legible)."""
    monkeypatch.setattr(
        "app.api.routes.upload.extraer_boleta",
        lambda content, ext: None,
    )


def test_boleta_draft_200(client, monkeypatch):
    _fake_boleta_ok(monkeypatch)
    r = client.post(
        "/api/v1/transactions/boleta",
        files={"file": ("boleta.jpg", io.BytesIO(b"fake"), "image/jpeg")},
    )
    assert r.status_code == 200
    body = r.json()
    assert body["comercio"] == "LIDER"
    assert body["monto"] == -12990.0
    assert body["fecha"] == "2026-06-20"
    assert body["categoria"] == "Supermercado"


def test_boleta_draft_no_boleta_422(client, monkeypatch):
    _fake_boleta_none(monkeypatch)
    r = client.post(
        "/api/v1/transactions/boleta",
        files={"file": ("foto.jpg", io.BytesIO(b"notaboleta"), "image/jpeg")},
    )
    assert r.status_code == 422
    assert "boleta" in r.json()["detail"].lower()


def test_boleta_requires_auth():
    app.dependency_overrides.clear()
    c = TestClient(app)
    r = c.post(
        "/api/v1/transactions/boleta",
        files={"file": ("b.jpg", io.BytesIO(b"x"), "image/jpeg")},
    )
    assert r.status_code in (401, 403)


# ---------------------------------------------------------------------------
# POST /transactions/manual
# ---------------------------------------------------------------------------

def test_manual_guarda_y_aparece_en_get(client):
    r = client.post(
        "/api/v1/transactions/manual",
        json={
            "comercio": "LIDER",
            "monto": -12990.0,
            "fecha": "2026-06-20",
            "categoria": "Supermercado",
        },
    )
    assert r.status_code in (200, 201)
    body = r.json()
    assert body.get("ok") is True

    # Aparece en GET /transactions
    r2 = client.get("/api/v1/transactions")
    assert r2.status_code == 200
    txns = r2.json()
    assert len(txns) == 1
    t = txns[0]
    assert t["descripcion"] == "LIDER"
    assert float(t["monto"]) == -12990.0
    assert t["fuente"] == "boleta"
    assert t["banco"] == "efectivo"


def test_manual_categoria_invalida_422(client):
    r = client.post(
        "/api/v1/transactions/manual",
        json={
            "comercio": "LIDER",
            "monto": -5000.0,
            "fecha": "2026-06-20",
            "categoria": "CategoriaInventada",
        },
    )
    assert r.status_code == 422


def test_manual_requires_auth():
    app.dependency_overrides.clear()
    c = TestClient(app)
    r = c.post(
        "/api/v1/transactions/manual",
        json={
            "comercio": "x",
            "monto": -100.0,
            "fecha": "2026-06-20",
            "categoria": "Otros",
        },
    )
    assert r.status_code in (401, 403)
