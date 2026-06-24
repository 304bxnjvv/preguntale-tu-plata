from datetime import date
from app.models.schemas import Transaccion
from app.services.transaction_service import insert_transactions, get_summary


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
