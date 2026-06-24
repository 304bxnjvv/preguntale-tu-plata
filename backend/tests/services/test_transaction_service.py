from datetime import date
from app.models.schemas import Transaccion
from app.services.transaction_service import insert_transactions
from app.db.models import Transaction


def _txn(desc="LIDER", monto=-45000.0, tarjeta=None):
    return Transaccion(
        fecha=date(2025, 6, 1),
        descripcion=desc,
        monto=monto,
        tipo="cargo",
        banco="bci",
        tarjeta=tarjeta,
    )


def test_insert_returns_count(session):
    n = insert_transactions(session, "u1", [_txn(), _txn("UBER", -12500)])
    assert len(n) == 2
    assert session.query(Transaction).filter_by(user_id="u1").count() == 2


def test_insert_dedups_repeated(session):
    txns = [_txn()]
    assert len(insert_transactions(session, "u1", txns)) == 1
    assert len(insert_transactions(session, "u1", txns)) == 0  # duplicado, no inserta
    assert session.query(Transaction).filter_by(user_id="u1").count() == 1


def test_same_desc_distinct_card_not_dedup(session):
    assert len(insert_transactions(session, "u1", [_txn(tarjeta="4521")])) == 1
    assert len(insert_transactions(session, "u1", [_txn(tarjeta="9988")])) == 1
    assert session.query(Transaction).filter_by(user_id="u1").count() == 2


def test_isolation_between_users(session):
    insert_transactions(session, "u1", [_txn()])
    insert_transactions(session, "u2", [_txn()])
    assert session.query(Transaction).filter_by(user_id="u1").count() == 1
    assert session.query(Transaction).filter_by(user_id="u2").count() == 1
