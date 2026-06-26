"""
Integration tests for:
  GET  /api/v1/account/export   — exportar datos (Ley 21.719)
  DELETE /api/v1/account        — borrar cuenta completa (gateado por service-role key)
"""
import json

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.db.models  # noqa: F401
from app.main import app
from app.auth.jwt import get_current_user
from app.db.base import Base, get_session
from app.db.models import (
    ChatMessage,
    CategoriaOverride,
    Meta,
    Presupuesto,
    Subscription,
    Transaction,
    Upload,
)


# ── fixture ───────────────────────────────────────────────────────────────────

@pytest.fixture
def client(monkeypatch):
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    TestSession = sessionmaker(bind=engine)
    _shared_session = TestSession()

    def _override_session():
        yield _shared_session

    app.dependency_overrides[get_session] = _override_session
    app.dependency_overrides[get_current_user] = lambda: "u1"
    yield TestClient(app), _shared_session
    app.dependency_overrides.clear()
    _shared_session.close()


@pytest.fixture
def client_no_auth(monkeypatch):
    """Client that does NOT override get_current_user (returns 401/403)."""
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    TestSession = sessionmaker(bind=engine)
    _shared_session = TestSession()

    def _override_session():
        yield _shared_session

    app.dependency_overrides[get_session] = _override_session
    # Intentionally NOT overriding get_current_user
    yield TestClient(app, raise_server_exceptions=False), _shared_session
    app.dependency_overrides.clear()
    _shared_session.close()


# ── helpers ───────────────────────────────────────────────────────────────────

def _seed(session):
    from datetime import date
    session.add(Transaction(
        user_id="u1", fecha=date(2025, 6, 1), descripcion="LIDER",
        monto=-45000, moneda="CLP", tipo="cargo",
        categoria="Supermercado", banco="bci", fuente="cartola",
    ))
    session.add(ChatMessage(user_id="u1", role="user", content="hola"))
    session.add(Upload(user_id="u1", filename="cartola.csv", n_transacciones=1))
    session.add(Presupuesto(user_id="u1", categoria="Supermercado", monto_tope=100000))
    session.add(Meta(user_id="u1", nombre="Viaje", monto_objetivo=500000))
    session.add(CategoriaOverride(user_id="u1", comercio_key="LIDER", categoria="Supermercado"))
    session.commit()


# ── GET /account/export ───────────────────────────────────────────────────────

class TestAccountExport:
    def test_returns_200_with_application_json(self, client):
        c, session = client
        _seed(session)
        r = c.get("/api/v1/account/export")
        assert r.status_code == 200
        assert "application/json" in r.headers["content-type"]

    def test_content_disposition_attachment(self, client):
        c, session = client
        r = c.get("/api/v1/account/export")
        cd = r.headers.get("content-disposition", "")
        assert "attachment" in cd
        assert "mis-datos-preguntale.json" in cd

    def test_body_is_valid_json(self, client):
        c, session = client
        _seed(session)
        r = c.get("/api/v1/account/export")
        data = r.json()
        assert isinstance(data, dict)

    def test_contains_expected_top_level_keys(self, client):
        c, session = client
        _seed(session)
        r = c.get("/api/v1/account/export")
        data = r.json()
        for key in ("exportado_at", "user_id", "transactions", "chat_messages",
                    "presupuestos", "metas", "tarjeta_estado",
                    "categoria_overrides", "uploads", "subscription"):
            assert key in data, f"Missing key: {key}"

    def test_transactions_present_in_export(self, client):
        c, session = client
        _seed(session)
        r = c.get("/api/v1/account/export")
        data = r.json()
        assert len(data["transactions"]) == 1
        assert data["transactions"][0]["descripcion"] == "LIDER"

    def test_chat_messages_present_in_export(self, client):
        c, session = client
        _seed(session)
        r = c.get("/api/v1/account/export")
        data = r.json()
        assert len(data["chat_messages"]) == 1
        assert data["chat_messages"][0]["role"] == "user"

    def test_exportado_at_present_and_string(self, client):
        c, session = client
        r = c.get("/api/v1/account/export")
        data = r.json()
        assert isinstance(data["exportado_at"], str)
        assert len(data["exportado_at"]) > 10  # ISO datetime is at least 10 chars

    def test_empty_user_still_returns_200(self, client):
        c, _session = client
        r = c.get("/api/v1/account/export")
        assert r.status_code == 200
        data = r.json()
        assert data["transactions"] == []

    def test_no_auth_returns_401_or_403(self, client_no_auth):
        c, _ = client_no_auth
        r = c.get("/api/v1/account/export")
        assert r.status_code in (401, 403, 422)


# ── DELETE /account ───────────────────────────────────────────────────────────

class TestAccountDeleteFull:
    def test_key_vacia_returns_200_datos_eliminados_auth_false(self, client, monkeypatch):
        """Con SUPABASE_SERVICE_ROLE_KEY vacía: datos_eliminados=True, auth_eliminada=False."""
        c, session = client
        _seed(session)

        import app.config as cfg_mod
        monkeypatch.setattr(cfg_mod.settings, "supabase_service_role_key", "")

        r = c.delete("/api/v1/account")
        assert r.status_code == 200
        data = r.json()
        assert data["datos_eliminados"] is True
        assert data["auth_eliminada"] is False

    def test_key_vacia_borra_datos_de_bd(self, client, monkeypatch):
        """Con key vacía se borran los datos de la BD."""
        c, session = client
        _seed(session)

        import app.config as cfg_mod
        monkeypatch.setattr(cfg_mod.settings, "supabase_service_role_key", "")

        c.delete("/api/v1/account")
        assert session.query(Transaction).filter_by(user_id="u1").count() == 0
        assert session.query(ChatMessage).filter_by(user_id="u1").count() == 0

    def test_key_seteada_mock_204_auth_true(self, client, monkeypatch):
        """Con key seteada y Supabase respondiendo 204: auth_eliminada=True."""
        c, session = client
        _seed(session)

        import app.config as cfg_mod
        monkeypatch.setattr(cfg_mod.settings, "supabase_service_role_key", "fake-service-key")
        monkeypatch.setattr(cfg_mod.settings, "supabase_url", "https://fake.supabase.co")

        class FakeResponse:
            status_code = 204

        import app.services.account_service as svc_mod
        monkeypatch.setattr(svc_mod.httpx, "delete", lambda *a, **kw: FakeResponse())

        r = c.delete("/api/v1/account")
        assert r.status_code == 200
        data = r.json()
        assert data["datos_eliminados"] is True
        assert data["auth_eliminada"] is True

    def test_key_seteada_no_llama_red_cuando_vacia(self, client, monkeypatch):
        """Cuando la key está vacía, no se realiza ninguna llamada de red."""
        c, session = client

        import app.config as cfg_mod
        monkeypatch.setattr(cfg_mod.settings, "supabase_service_role_key", "")

        calls = []

        import app.services.account_service as svc_mod

        def spy(*a, **kw):
            calls.append(1)
            raise AssertionError("Should not call httpx.delete with empty key")

        monkeypatch.setattr(svc_mod.httpx, "delete", spy)

        r = c.delete("/api/v1/account")
        assert r.status_code == 200
        assert calls == []

    def test_no_auth_returns_401_or_403(self, client_no_auth):
        c, _ = client_no_auth
        r = c.delete("/api/v1/account")
        assert r.status_code in (401, 403, 422)
