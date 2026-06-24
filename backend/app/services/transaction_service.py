from sqlalchemy.orm import Session
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
