from sqlalchemy.orm import Session
from sqlalchemy import func
from app.db.models import Transaction
from app.models.schemas import Transaccion


def _dedup_key(
    user_id: str, fecha, monto, descripcion: str, tarjeta: str | None
) -> tuple:
    return (
        user_id,
        str(fecha),
        float(monto),
        descripcion.strip().lower(),
        tarjeta or "",
    )


def insert_transactions(
    session: Session,
    user_id: str,
    transacciones: list[Transaccion],
    fuente: str = "cartola",
) -> int:
    existing = (
        session.query(
            Transaction.fecha,
            Transaction.monto,
            Transaction.descripcion,
            Transaction.tarjeta,
        )
        .filter(Transaction.user_id == user_id)
        .all()
    )
    seen = {
        _dedup_key(user_id, fecha, monto, descripcion, tarjeta)
        for (fecha, monto, descripcion, tarjeta) in existing
    }

    inserted = 0
    for t in transacciones:
        key = _dedup_key(user_id, t.fecha, t.monto, t.descripcion, t.tarjeta)
        if key in seen:
            continue
        seen.add(key)
        session.add(
            Transaction(
                user_id=user_id,
                fecha=t.fecha,
                descripcion=t.descripcion,
                monto=t.monto,
                moneda=t.moneda,
                tarjeta=t.tarjeta,
                tipo=t.tipo,
                categoria=t.categoria,
                banco=t.banco,
                fuente=fuente,
            )
        )
        inserted += 1

    session.commit()
    return inserted


def get_summary(session: Session, user_id: str) -> dict:
    rows = (
        session.query(
            Transaction.moneda,
            func.sum(Transaction.monto),
        )
        .filter(Transaction.user_id == user_id)
        .filter(Transaction.monto < 0)
        .group_by(Transaction.moneda)
        .all()
    )
    ingresos_rows = (
        session.query(Transaction.moneda, func.sum(Transaction.monto))
        .filter(Transaction.user_id == user_id)
        .filter(Transaction.monto >= 0)
        .group_by(Transaction.moneda)
        .all()
    )

    por_moneda: dict = {}
    for moneda, total in rows:
        por_moneda.setdefault(moneda, {"ingresos": 0.0, "gastos": 0.0})
        por_moneda[moneda]["gastos"] = float(total)
    for moneda, total in ingresos_rows:
        por_moneda.setdefault(moneda, {"ingresos": 0.0, "gastos": 0.0})
        por_moneda[moneda]["ingresos"] = float(total)

    cat_rows = (
        session.query(Transaction.categoria, func.sum(Transaction.monto))
        .filter(Transaction.user_id == user_id)
        .filter(Transaction.monto < 0)
        .filter(Transaction.categoria.isnot(None))
        .group_by(Transaction.categoria)
        .all()
    )
    gastos_por_categoria = [
        {"categoria": c, "total": float(t)} for c, t in cat_rows
    ]

    banco_rows = (
        session.query(Transaction.banco, func.sum(Transaction.monto))
        .filter(Transaction.user_id == user_id)
        .filter(Transaction.monto < 0)
        .group_by(Transaction.banco)
        .all()
    )
    gastos_por_banco = [{"banco": b, "total": float(t)} for b, t in banco_rows]

    return {
        "por_moneda": por_moneda,
        "gastos_por_categoria": gastos_por_categoria,
        "gastos_por_banco": gastos_por_banco,
    }
