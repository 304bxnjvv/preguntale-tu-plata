from datetime import date
from app.models.schemas import Transaccion
from app.services.transaction_service import insert_transactions, get_summary, list_transactions


def _seed(session):
    txns = [
        Transaccion(fecha=date(2025, 6, 1), descripcion="LIDER", monto=-45000,
                    tipo="cargo", banco="bci", categoria="supermercado"),
        Transaccion(fecha=date(2025, 6, 5), descripcion="UBER", monto=-12500,
                    tipo="cargo", banco="bci", categoria="transporte"),
        Transaccion(fecha=date(2025, 6, 10), descripcion="SUELDO", monto=2500000,
                    tipo="abono", banco="bci", categoria=None),
    ]
    insert_transactions(session, "u1", txns)


def test_summary_groups_by_moneda(session):
    _seed(session)
    s = get_summary(session, "u1")
    assert s["por_moneda"]["CLP"]["ingresos"] == 2500000.0
    assert s["por_moneda"]["CLP"]["gastos"] == -57500.0


def test_summary_gastos_por_categoria(session):
    _seed(session)
    s = get_summary(session, "u1")
    cats = {c["categoria"]: c["total"] for c in s["gastos_por_categoria"]}
    assert cats["supermercado"] == -45000.0
    assert cats["transporte"] == -12500.0


def test_summary_isolated_per_user(session):
    _seed(session)
    s = get_summary(session, "u2")
    assert s["por_moneda"] == {}
    assert s["gastos_por_categoria"] == []


# --- NEW: date-range filter tests ---

def test_summary_desde_excludes_older_txns(session):
    """get_summary(desde=...) should only aggregate txns on or after that date."""
    _seed(session)
    # desde=2025-06-05 excludes LIDER (2025-06-01)
    s = get_summary(session, "u1", desde=date(2025, 6, 5))
    # only UBER (-12500) and SUELDO (2500000) remain
    assert s["por_moneda"]["CLP"]["gastos"] == -12500.0
    assert s["por_moneda"]["CLP"]["ingresos"] == 2500000.0
    cats = {c["categoria"]: c["total"] for c in s["gastos_por_categoria"]}
    assert "supermercado" not in cats
    assert cats["transporte"] == -12500.0


def test_summary_desde_no_results(session):
    """desde after all txns should return empty aggregates."""
    _seed(session)
    s = get_summary(session, "u1", desde=date(2025, 12, 31))
    assert s["por_moneda"] == {}
    assert s["gastos_por_categoria"] == []
    assert s["gastos_por_banco"] == []


# --- NEW: tipo filter tests ---

def test_list_transactions_tipo_ingreso(session):
    """list_transactions(tipo='ingreso') returns only monto >= 0."""
    _seed(session)
    txns = list_transactions(session, "u1", tipo="ingreso")
    assert len(txns) == 1
    assert txns[0].monto == 2500000.0


def test_list_transactions_tipo_gasto(session):
    """list_transactions(tipo='gasto') returns only monto < 0."""
    _seed(session)
    txns = list_transactions(session, "u1", tipo="gasto")
    assert len(txns) == 2
    assert all(t.monto < 0 for t in txns)


def test_list_transactions_no_tipo_returns_all(session):
    """Backward compat: no tipo param returns all transactions."""
    _seed(session)
    txns = list_transactions(session, "u1")
    assert len(txns) == 3


def test_summary_tipo_ingreso_aggregates_income_side(session):
    """tipo='ingreso' → gastos_por_banco and gastos_por_categoria aggregate monto>=0."""
    _seed(session)
    s = get_summary(session, "u1", tipo="ingreso")
    # gastos_por_banco should aggregate the income side (SUELDO 2500000 at bci)
    bancos = {b["banco"]: b["total"] for b in s["gastos_por_banco"]}
    assert bancos["bci"] == 2500000.0
    # gastos_por_categoria: SUELDO has categoria=None, so no category rows
    assert s["gastos_por_categoria"] == []


def test_summary_tipo_gasto_aggregates_expense_side(session):
    """tipo='gasto' (explicit) → same as default behaviour for per-banco/categoria."""
    _seed(session)
    s = get_summary(session, "u1", tipo="gasto")
    bancos = {b["banco"]: b["total"] for b in s["gastos_por_banco"]}
    assert bancos["bci"] == -57500.0


def test_summary_no_params_backward_compat(session):
    """No-param call aggregates expense side exactly as before."""
    _seed(session)
    s = get_summary(session, "u1")
    bancos = {b["banco"]: b["total"] for b in s["gastos_por_banco"]}
    assert bancos["bci"] == -57500.0
    assert s["por_moneda"]["CLP"]["ingresos"] == 2500000.0
