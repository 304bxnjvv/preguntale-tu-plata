from datetime import date
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.db.models import Transaction
from app.models.schemas import Transaccion
from app.services.categoria_override_service import get_override


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
) -> list[Transaccion]:
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

    nuevas: list[Transaccion] = []
    for t in transacciones:
        key = _dedup_key(user_id, t.fecha, t.monto, t.descripcion, t.tarjeta)
        if key in seen:
            continue
        seen.add(key)
        categoria = t.categoria
        ov = get_override(session, user_id, t.descripcion)
        if ov is not None:
            categoria = ov
        session.add(
            Transaction(
                user_id=user_id,
                fecha=t.fecha,
                descripcion=t.descripcion,
                monto=t.monto,
                moneda=t.moneda,
                tarjeta=t.tarjeta,
                tipo=t.tipo,
                categoria=categoria,
                banco=t.banco,
                fuente=fuente,
            )
        )
        nuevas.append(t)

    session.commit()
    return nuevas


def list_transactions(
    session: Session,
    user_id: str,
    banco: str | None = None,
    limit: int = 100,
    offset: int = 0,
    desde: date | None = None,
    tipo: str | None = None,
) -> list[Transaction]:
    q = session.query(Transaction).filter(Transaction.user_id == user_id)
    if banco:
        q = q.filter(Transaction.banco == banco)
    if desde is not None:
        q = q.filter(Transaction.fecha >= desde)
    if tipo == "ingreso":
        q = q.filter(Transaction.monto >= 0)
    elif tipo == "gasto":
        q = q.filter(Transaction.monto < 0)
    return q.order_by(Transaction.fecha.desc()).limit(limit).offset(offset).all()


def get_summary(
    session: Session,
    user_id: str,
    desde: date | None = None,
    tipo: str | None = None,
) -> dict:
    def _base(extra_filter=None):
        q = (
            session.query(Transaction.moneda, func.sum(Transaction.monto))
            .filter(Transaction.user_id == user_id)
        )
        if desde is not None:
            q = q.filter(Transaction.fecha >= desde)
        if extra_filter is not None:
            q = q.filter(extra_filter)
        return q

    # por_moneda always splits both sides (gastos + ingresos), date-filtered
    gastos_rows = (
        _base(Transaction.monto < 0)
        .group_by(Transaction.moneda)
        .all()
    )
    ingresos_rows = (
        _base(Transaction.monto >= 0)
        .group_by(Transaction.moneda)
        .all()
    )

    por_moneda: dict = {}
    for moneda, total in gastos_rows:
        por_moneda.setdefault(moneda, {"ingresos": 0.0, "gastos": 0.0})
        por_moneda[moneda]["gastos"] = float(total)
    for moneda, total in ingresos_rows:
        por_moneda.setdefault(moneda, {"ingresos": 0.0, "gastos": 0.0})
        por_moneda[moneda]["ingresos"] = float(total)

    # per-banco and per-categoria: aggregate income side when tipo='ingreso',
    # otherwise aggregate expense side (default behaviour).
    if tipo == "ingreso":
        side_filter = Transaction.monto >= 0
    else:
        side_filter = Transaction.monto < 0

    def _base_side():
        q = (
            session.query(Transaction)
            .filter(Transaction.user_id == user_id)
            .filter(side_filter)
        )
        if desde is not None:
            q = q.filter(Transaction.fecha >= desde)
        return q

    cat_rows = (
        session.query(Transaction.categoria, func.sum(Transaction.monto))
        .filter(Transaction.user_id == user_id)
        .filter(side_filter)
        .filter(Transaction.categoria.isnot(None))
        .filter(Transaction.fecha >= desde if desde is not None else True)
        .group_by(Transaction.categoria)
        .all()
    )
    gastos_por_categoria = [
        {"categoria": c, "total": float(t)} for c, t in cat_rows
    ]

    banco_rows = (
        session.query(Transaction.banco, func.sum(Transaction.monto))
        .filter(Transaction.user_id == user_id)
        .filter(side_filter)
        .filter(Transaction.banco.isnot(None))
        .filter(Transaction.fecha >= desde if desde is not None else True)
        .group_by(Transaction.banco)
        .all()
    )
    gastos_por_banco = [{"banco": b, "total": float(t)} for b, t in banco_rows]

    return {
        "por_moneda": por_moneda,
        "gastos_por_categoria": gastos_por_categoria,
        "gastos_por_banco": gastos_por_banco,
    }
