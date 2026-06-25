"""
Servicio de presupuestos: UPSERT de topes, eliminación y estado del mes actual.
"""
from __future__ import annotations

from datetime import date
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.db.models import Presupuesto, Transaction
from app.services.categorias import CATEGORIAS


def _curr_month_range() -> tuple[date, date]:
    """Devuelve (curr_start, next_month_start) para filtrar el mes actual."""
    today = date.today()
    curr_start = date(today.year, today.month, 1)
    if today.month == 12:
        next_month_start = date(today.year + 1, 1, 1)
    else:
        next_month_start = date(today.year, today.month + 1, 1)
    return curr_start, next_month_start


def set_tope(session: Session, user_id: str, categoria: str, monto_tope: float) -> dict:
    """UPSERT del tope de presupuesto para (user_id, categoria).

    Raises ValueError si categoria ∉ CATEGORIAS.
    Devuelve el dict de estado actualizado.
    """
    if categoria not in CATEGORIAS:
        raise ValueError(f"Categoría inválida: {categoria!r}. Debe ser una de {CATEGORIAS}")

    row = session.query(Presupuesto).filter_by(user_id=user_id, categoria=categoria).first()
    if row is None:
        row = Presupuesto(user_id=user_id, categoria=categoria, monto_tope=monto_tope)
        session.add(row)
    else:
        row.monto_tope = monto_tope
    session.commit()

    # Devolver el estado actualizado de esa categoría
    estados = estado_presupuestos(session, user_id)
    return next(e for e in estados if e["categoria"] == categoria)


def delete_tope(session: Session, user_id: str, categoria: str) -> bool:
    """Elimina el tope de presupuesto para (user_id, categoria).

    Devuelve True si existía y fue eliminado, False si no existía.
    """
    row = session.query(Presupuesto).filter_by(user_id=user_id, categoria=categoria).first()
    if row is None:
        return False
    session.delete(row)
    session.commit()
    return True


def estado_presupuestos(session: Session, user_id: str) -> list[dict]:
    """Estado de todos los presupuestos del usuario para el mes actual.

    Retorna lista de dicts con shape:
        {categoria, monto_tope, gastado, pct, estado}

    donde:
    - gastado = Σ|monto| de transacciones con monto<0, en la categoría, este mes.
    - pct = gastado / monto_tope (0 si monto_tope == 0).
    - estado: 'ok' (<0.8) / 'cerca' (0.8–1.0) / 'excedido' (>1.0).
    """
    presupuestos = session.query(Presupuesto).filter_by(user_id=user_id).all()
    if not presupuestos:
        return []

    curr_start, next_month_start = _curr_month_range()

    resultado = []
    for p in presupuestos:
        gastado_raw = (
            session.query(func.sum(Transaction.monto))
            .filter(Transaction.user_id == user_id)
            .filter(Transaction.categoria == p.categoria)
            .filter(Transaction.monto < 0)
            .filter(Transaction.fecha >= curr_start)
            .filter(Transaction.fecha < next_month_start)
            .scalar()
        )
        gastado = abs(float(gastado_raw)) if gastado_raw else 0.0
        monto_tope = float(p.monto_tope)

        if monto_tope > 0:
            pct = gastado / monto_tope
        else:
            pct = 0.0

        if pct > 1.0:
            estado = "excedido"
        elif pct >= 0.8:
            estado = "cerca"
        else:
            estado = "ok"

        resultado.append({
            "categoria": p.categoria,
            "monto_tope": monto_tope,
            "gastado": gastado,
            "pct": pct,
            "estado": estado,
        })

    return resultado
