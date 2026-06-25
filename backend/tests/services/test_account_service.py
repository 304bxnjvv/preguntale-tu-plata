"""Tests for account_service.delete_user_data."""
from datetime import date, datetime, timezone

from app.db.models import Transaction, ChatMessage, Upload
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

    assert result == {"transactions": 2, "chat": 2, "uploads": 1}
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

    assert result == {"transactions": 1, "chat": 1, "uploads": 1}
    # u2 rows are untouched
    assert session.query(Transaction).filter_by(user_id="u2").count() == 1
    assert session.query(ChatMessage).filter_by(user_id="u2").count() == 1
    assert session.query(Upload).filter_by(user_id="u2").count() == 1


def test_delete_empty_user_returns_zeros(session):
    result = delete_user_data(session, "nobody")
    assert result == {"transactions": 0, "chat": 0, "uploads": 0}
