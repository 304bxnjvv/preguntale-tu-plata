"""Tests for account_service.delete_user_data."""
from datetime import date, datetime, timezone

from app.db.models import Transaction, ChatMessage, Upload, TarjetaEstado, Presupuesto, Meta, CategoriaOverride
from app.services.account_service import delete_user_data


def _tx(session, user_id, fuente="cartola"):
    session.add(Transaction(
        user_id=user_id,
        fecha=date(2025, 6, 1),
        descripcion="LIDER",
        monto=-45000,
        moneda="CLP",
        tipo="cargo",
        categoria="Supermercado",
        banco="bci",
        fuente=fuente,
    ))


def _chat(session, user_id, role="user"):
    session.add(ChatMessage(user_id=user_id, role=role, content="hola"))


def _upload(session, user_id):
    session.add(Upload(user_id=user_id, filename="test.csv", n_transacciones=2))


def test_delete_clears_all_three_tables(session):
    _tx(session, "u1")
    _tx(session, "u1", fuente="demo")
    _chat(session, "u1")
    _chat(session, "u1", role="assistant")
    _upload(session, "u1")
    session.commit()

    result = delete_user_data(session, "u1")

    assert result["transactions"] == 2
    assert result["chat"] == 2
    assert result["uploads"] == 1
    assert result["tarjeta"] == 0
    assert result["presupuestos"] == 0
    assert result["metas"] == 0
    assert result["overrides"] == 0
    assert session.query(Transaction).filter_by(user_id="u1").count() == 0
    assert session.query(ChatMessage).filter_by(user_id="u1").count() == 0
    assert session.query(Upload).filter_by(user_id="u1").count() == 0


def test_delete_isolates_by_user(session):
    # Add rows for u1 and u2
    _tx(session, "u1")
    _tx(session, "u2")
    _chat(session, "u1")
    _chat(session, "u2")
    _upload(session, "u1")
    _upload(session, "u2")
    session.commit()

    result = delete_user_data(session, "u1")

    assert result["transactions"] == 1
    assert result["chat"] == 1
    assert result["uploads"] == 1
    # u2 rows are untouched
    assert session.query(Transaction).filter_by(user_id="u2").count() == 1
    assert session.query(ChatMessage).filter_by(user_id="u2").count() == 1
    assert session.query(Upload).filter_by(user_id="u2").count() == 1


def test_delete_empty_user_returns_zeros(session):
    result = delete_user_data(session, "nobody")
    assert result == {"transactions": 0, "chat": 0, "uploads": 0, "tarjeta": 0, "presupuestos": 0, "metas": 0, "overrides": 0}


def _tarjeta(session, user_id):
    session.add(TarjetaEstado(
        user_id=user_id,
        total_a_pagar=10000,
        monto_minimo=5000,
        cupo_total=500000,
        cupo_utilizado=10000,
    ))


def _presupuesto(session, user_id, categoria="Supermercado"):
    session.add(Presupuesto(user_id=user_id, categoria=categoria, monto_tope=100000))


def _meta(session, user_id):
    session.add(Meta(user_id=user_id, nombre="Viaje", monto_objetivo=500000))


def _override(session, user_id, comercio_key="LIDER"):
    session.add(CategoriaOverride(user_id=user_id, comercio_key=comercio_key, categoria="Supermercado"))


def test_delete_clears_financial_data_tables(session):
    """Bug A: delete_user_data debe borrar TarjetaEstado, Presupuesto, Meta, CategoriaOverride."""
    _tx(session, "u1")
    _chat(session, "u1")
    _upload(session, "u1")
    _tarjeta(session, "u1")
    _presupuesto(session, "u1", "Supermercado")
    _presupuesto(session, "u1", "Transporte")
    _meta(session, "u1")
    _meta(session, "u1")
    _override(session, "u1", "LIDER")
    _override(session, "u1", "FARMACIAS")
    session.commit()

    result = delete_user_data(session, "u1")

    assert result["tarjeta"] == 1
    assert result["presupuestos"] == 2
    assert result["metas"] == 2
    assert result["overrides"] == 2
    assert session.query(TarjetaEstado).filter_by(user_id="u1").count() == 0
    assert session.query(Presupuesto).filter_by(user_id="u1").count() == 0
    assert session.query(Meta).filter_by(user_id="u1").count() == 0
    assert session.query(CategoriaOverride).filter_by(user_id="u1").count() == 0


def test_delete_financial_data_isolates_by_user(session):
    """Bug A: borrar datos de u1 NO debe tocar los datos financieros de u2."""
    _tarjeta(session, "u1")
    _tarjeta(session, "u2")
    _presupuesto(session, "u1")
    _presupuesto(session, "u2")
    _meta(session, "u1")
    _meta(session, "u2")
    _override(session, "u1", "LIDER")
    _override(session, "u2", "LIDER")
    session.commit()

    delete_user_data(session, "u1")

    assert session.query(TarjetaEstado).filter_by(user_id="u2").count() == 1
    assert session.query(Presupuesto).filter_by(user_id="u2").count() == 1
    assert session.query(Meta).filter_by(user_id="u2").count() == 1
    assert session.query(CategoriaOverride).filter_by(user_id="u2").count() == 1
