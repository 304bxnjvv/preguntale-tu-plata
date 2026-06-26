"""
Tests for account_service.exportar_datos and account_service.eliminar_cuenta.
No network calls are made (httpx is monkeypatched).
"""
from datetime import date, datetime, timezone

import pytest

from app.db.models import (
    CategoriaOverride,
    CategoriaUsuario,
    ChatMessage,
    Meta,
    Presupuesto,
    Subscription,
    TarjetaEstado,
    Transaction,
    Upload,
)
from app.services.account_service import eliminar_cuenta, exportar_datos


# ── helpers ──────────────────────────────────────────────────────────────────

def _tx(session, user_id="u1"):
    t = Transaction(
        user_id=user_id,
        fecha=date(2025, 6, 1),
        descripcion="LIDER",
        monto=-45000,
        moneda="CLP",
        tipo="cargo",
        categoria="Supermercado",
        banco="bci",
        fuente="cartola",
    )
    session.add(t)
    return t


def _chat(session, user_id="u1", role="user", content="hola"):
    c = ChatMessage(user_id=user_id, role=role, content=content)
    session.add(c)
    return c


def _upload(session, user_id="u1", filename="f.csv", n=1):
    u = Upload(user_id=user_id, filename=filename, n_transacciones=n)
    session.add(u)
    return u


def _presupuesto(session, user_id="u1", categoria="Supermercado", tope=100000):
    p = Presupuesto(user_id=user_id, categoria=categoria, monto_tope=tope)
    session.add(p)
    return p


def _meta(session, user_id="u1", nombre="Viaje", objetivo=500000, actual=0):
    m = Meta(user_id=user_id, nombre=nombre, monto_objetivo=objetivo, monto_actual=actual)
    session.add(m)
    return m


def _override(session, user_id="u1", clave="LIDER", cat="Supermercado"):
    o = CategoriaOverride(user_id=user_id, comercio_key=clave, categoria=cat)
    session.add(o)
    return o


def _categoria_usuario(session, user_id="u1", nombre="Mascotas"):
    c = CategoriaUsuario(user_id=user_id, nombre=nombre)
    session.add(c)
    return c


def _subscription(session, user_id="u1", estado="trial"):
    s = Subscription(
        user_id=user_id,
        estado=estado,
        trial_ends_at=datetime(2026, 12, 31, tzinfo=timezone.utc),
    )
    session.add(s)
    return s


# ── exportar_datos ────────────────────────────────────────────────────────────

class TestExportarDatos:
    def test_returns_expected_top_level_keys(self, session):
        result = exportar_datos(session, "u1", exportado_at="2026-01-01T00:00:00+00:00")
        expected_keys = {
            "exportado_at", "user_id", "transactions", "chat_messages",
            "presupuestos", "metas", "tarjeta_estado", "categoria_overrides",
            "categorias_usuario", "uploads", "subscription",
        }
        assert set(result.keys()) == expected_keys

    def test_exportado_at_passthrough(self, session):
        ts = "2026-06-24T12:00:00+00:00"
        result = exportar_datos(session, "u1", exportado_at=ts)
        assert result["exportado_at"] == ts

    def test_empty_user_returns_empty_lists(self, session):
        result = exportar_datos(session, "unknown", exportado_at="2026-01-01T00:00:00+00:00")
        assert result["transactions"] == []
        assert result["chat_messages"] == []
        assert result["presupuestos"] == []
        assert result["metas"] == []
        assert result["categoria_overrides"] == []
        assert result["categorias_usuario"] == []
        assert result["uploads"] == []
        assert result["subscription"] is None

    def test_transactions_shape_and_count(self, session):
        _tx(session)
        _tx(session)
        session.commit()

        result = exportar_datos(session, "u1", exportado_at="2026-01-01T00:00:00+00:00")
        txs = result["transactions"]
        assert len(txs) == 2
        tx = txs[0]
        assert tx["fecha"] == "2025-06-01"
        assert tx["descripcion"] == "LIDER"
        assert tx["monto"] == -45000.0
        assert tx["moneda"] == "CLP"
        assert tx["tipo"] == "cargo"
        assert tx["categoria"] == "Supermercado"
        assert tx["banco"] == "bci"
        assert tx["fuente"] == "cartola"

    def test_chat_messages_shape(self, session):
        _chat(session, role="user", content="pregunta")
        _chat(session, role="assistant", content="respuesta")
        session.commit()

        result = exportar_datos(session, "u1", exportado_at="2026-01-01T00:00:00+00:00")
        chats = result["chat_messages"]
        assert len(chats) == 2
        roles = {c["role"] for c in chats}
        assert roles == {"user", "assistant"}
        assert "content" in chats[0]
        assert "created_at" in chats[0]

    def test_presupuestos_exported(self, session):
        _presupuesto(session, categoria="Supermercado", tope=100000)
        _presupuesto(session, categoria="Transporte", tope=50000)
        session.commit()

        result = exportar_datos(session, "u1", exportado_at="2026-01-01T00:00:00+00:00")
        cats = {p["categoria"] for p in result["presupuestos"]}
        assert cats == {"Supermercado", "Transporte"}

    def test_metas_exported(self, session):
        _meta(session, nombre="Viaje", objetivo=500000, actual=100000)
        session.commit()

        result = exportar_datos(session, "u1", exportado_at="2026-01-01T00:00:00+00:00")
        assert len(result["metas"]) == 1
        m = result["metas"][0]
        assert m["nombre"] == "Viaje"
        assert m["monto_objetivo"] == 500000.0
        assert m["monto_actual"] == 100000.0

    def test_categoria_overrides_exported(self, session):
        _override(session, clave="LIDER", cat="Supermercado")
        session.commit()

        result = exportar_datos(session, "u1", exportado_at="2026-01-01T00:00:00+00:00")
        assert len(result["categoria_overrides"]) == 1
        assert result["categoria_overrides"][0]["comercio_key"] == "LIDER"

    def test_categorias_usuario_exported(self, session):
        _categoria_usuario(session, nombre="Mascotas")
        session.commit()

        result = exportar_datos(session, "u1", exportado_at="2026-01-01T00:00:00+00:00")
        nombres = [c["nombre"] for c in result["categorias_usuario"]]
        assert "Mascotas" in nombres

    def test_uploads_shape(self, session):
        _upload(session, filename="cartola.csv", n=10)
        session.commit()

        result = exportar_datos(session, "u1", exportado_at="2026-01-01T00:00:00+00:00")
        assert len(result["uploads"]) == 1
        u = result["uploads"][0]
        assert u["filename"] == "cartola.csv"
        assert u["n_transacciones"] == 10
        assert "created_at" in u

    def test_subscription_exported(self, session):
        _subscription(session, estado="trial")
        session.commit()

        result = exportar_datos(session, "u1", exportado_at="2026-01-01T00:00:00+00:00")
        sub = result["subscription"]
        assert sub is not None
        assert sub["estado"] == "trial"
        assert "trial_ends_at" in sub

    def test_tarjeta_estado_included(self, session):
        result = exportar_datos(session, "u1", exportado_at="2026-01-01T00:00:00+00:00")
        te = result["tarjeta_estado"]
        # Without data, get_estado returns tiene_datos=False
        assert "tiene_datos" in te

    def test_isolation_by_user(self, session):
        _tx(session, user_id="u1")
        _tx(session, user_id="u2")
        _chat(session, user_id="u1", content="solo u1")
        _chat(session, user_id="u2", content="solo u2")
        session.commit()

        result = exportar_datos(session, "u1", exportado_at="2026-01-01T00:00:00+00:00")
        assert len(result["transactions"]) == 1
        assert len(result["chat_messages"]) == 1
        assert result["chat_messages"][0]["content"] == "solo u1"


# ── eliminar_cuenta ────────────────────────────────────────────────────────────

class TestEliminarCuenta:
    def test_key_vacia_no_llama_red_y_retorna_auth_false(self, session):
        """Con key vacía: borra datos, NO llama a la red, auth_eliminada=False."""
        _tx(session)
        _chat(session)
        session.commit()

        result = eliminar_cuenta(session, "u1", token_service_role="", supabase_url="https://x.supabase.co")
        assert result["datos_eliminados"] is True
        assert result["auth_eliminada"] is False

        # Los datos deben haberse borrado
        from app.db.models import Transaction, ChatMessage
        assert session.query(Transaction).filter_by(user_id="u1").count() == 0
        assert session.query(ChatMessage).filter_by(user_id="u1").count() == 0

    def test_key_seteada_mock_204_retorna_auth_true(self, session, monkeypatch):
        """Con key seteada y mock 204: auth_eliminada=True."""
        _tx(session)
        session.commit()

        class FakeResponse:
            status_code = 204

        class FakeClient:
            def delete(self, url, headers=None, timeout=None):
                return FakeResponse()

        import app.services.account_service as svc_mod
        monkeypatch.setattr(svc_mod.httpx, "delete", lambda *a, **kw: FakeResponse())

        result = eliminar_cuenta(
            session, "u1",
            token_service_role="fake-service-key",
            supabase_url="https://x.supabase.co",
        )
        assert result["datos_eliminados"] is True
        assert result["auth_eliminada"] is True

    def test_key_seteada_mock_200_retorna_auth_true(self, session, monkeypatch):
        """Con key seteada y mock 200: auth_eliminada=True."""
        _tx(session)
        session.commit()

        class FakeResponse:
            status_code = 200

        import app.services.account_service as svc_mod
        monkeypatch.setattr(svc_mod.httpx, "delete", lambda *a, **kw: FakeResponse())

        result = eliminar_cuenta(
            session, "u1",
            token_service_role="key",
            supabase_url="https://x.supabase.co",
        )
        assert result["auth_eliminada"] is True

    def test_key_seteada_error_red_retorna_auth_false(self, session, monkeypatch):
        """Error de red no rompe: auth_eliminada=False."""
        _tx(session)
        session.commit()

        import app.services.account_service as svc_mod

        def raise_error(*a, **kw):
            raise ConnectionError("no internet")

        monkeypatch.setattr(svc_mod.httpx, "delete", raise_error)

        result = eliminar_cuenta(
            session, "u1",
            token_service_role="key",
            supabase_url="https://x.supabase.co",
        )
        assert result["datos_eliminados"] is True
        assert result["auth_eliminada"] is False

    def test_key_seteada_mock_llama_url_correcta(self, session, monkeypatch):
        """Verifica que la URL de la Admin API sea correcta."""
        _tx(session)
        session.commit()

        calls = []

        class FakeResponse:
            status_code = 204

        import app.services.account_service as svc_mod

        def fake_delete(url, headers=None, timeout=None):
            calls.append({"url": url, "headers": headers})
            return FakeResponse()

        monkeypatch.setattr(svc_mod.httpx, "delete", fake_delete)

        eliminar_cuenta(
            session, "u1",
            token_service_role="my-service-role-key",
            supabase_url="https://abc.supabase.co",
        )
        assert len(calls) == 1
        assert calls[0]["url"] == "https://abc.supabase.co/auth/v1/admin/users/u1"
        assert calls[0]["headers"]["Authorization"] == "Bearer my-service-role-key"
        assert calls[0]["headers"]["apikey"] == "my-service-role-key"
