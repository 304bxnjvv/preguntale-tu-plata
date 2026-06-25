"""Tests for demo_service: seed, idempotence, suscripciones detection, clear_demo."""
from datetime import date, timedelta
from collections import Counter

from app.db.models import Transaction
from app.services.demo_service import seed_demo, clear_demo


def _first_of_month(d: date) -> date:
    return d.replace(day=1)


# ── seed ─────────────────────────────────────────────────────────────────────

def test_seed_inserts_approx_18(session):
    n = seed_demo(session, "u1")
    assert n >= 18, f"Expected ≥18 inserted, got {n}"
    db_count = session.query(Transaction).filter_by(user_id="u1", fuente="demo").count()
    assert db_count == n


def test_seed_idempotent(session):
    n1 = seed_demo(session, "u1")
    assert n1 >= 18
    n2 = seed_demo(session, "u1")
    assert n2 == 0, "Second call should be idempotent (return 0)"
    # DB row count unchanged
    assert session.query(Transaction).filter_by(user_id="u1", fuente="demo").count() == n1


def test_seed_suscripciones_in_both_months(session):
    today = date.today()
    curr = _first_of_month(today)
    prev = _first_of_month(curr - timedelta(days=1))

    seed_demo(session, "u1", today=today)

    rows = (
        session.query(Transaction)
        .filter_by(user_id="u1", categoria="Suscripciones")
        .all()
    )
    # Must have at least one suscripción row in each of the two calendar months
    months = {(r.fecha.year, r.fecha.month) for r in rows}
    expected_prev = (prev.year, prev.month)
    expected_curr = (curr.year, curr.month)
    assert expected_prev in months, f"No Suscripciones in previous month {prev}"
    assert expected_curr in months, f"No Suscripciones in current month {curr}"


def test_seed_has_ingreso(session):
    seed_demo(session, "u1")
    ingresos = (
        session.query(Transaction)
        .filter(Transaction.user_id == "u1", Transaction.monto > 0)
        .all()
    )
    assert len(ingresos) >= 1, "Expected at least one ingreso (sueldo)"
    assert any(t.monto >= 1_000_000 for t in ingresos), "Sueldo should be ≥$1.200.000"


# ── clear_demo ────────────────────────────────────────────────────────────────

def test_clear_demo_removes_only_demo_rows(session):
    seed_demo(session, "u1")
    # Add a non-demo transaction for the same user
    session.add(Transaction(
        user_id="u1",
        fecha=date(2025, 1, 1),
        descripcion="PAGO CARTOLA",
        monto=-10000,
        moneda="CLP",
        tipo="cargo",
        categoria="Otros",
        banco="bci",
        fuente="cartola",
    ))
    session.commit()

    total_before = session.query(Transaction).filter_by(user_id="u1").count()
    demo_before = session.query(Transaction).filter_by(user_id="u1", fuente="demo").count()

    deleted = clear_demo(session, "u1")
    assert deleted == demo_before

    remaining = session.query(Transaction).filter_by(user_id="u1").count()
    assert remaining == total_before - demo_before
    # The non-demo row survived
    assert session.query(Transaction).filter_by(user_id="u1", fuente="cartola").count() == 1


def test_clear_demo_user_isolation(session):
    seed_demo(session, "u1")
    seed_demo(session, "u2")

    clear_demo(session, "u1")

    # u1 has no demo rows; u2 still does
    assert session.query(Transaction).filter_by(user_id="u1", fuente="demo").count() == 0
    assert session.query(Transaction).filter_by(user_id="u2", fuente="demo").count() >= 18
