"""Service for persisting and retrieving credit-card statement state (TarjetaEstado)."""
from __future__ import annotations

import json
from datetime import date

from sqlalchemy.orm import Session

from app.db.models import TarjetaEstado


def guardar_estado(session: Session, user_id: str, datos: dict) -> TarjetaEstado:
    """UPSERT the card state for user_id.

    Computes comprometido_proximo_mes = sum of valor_cuota for all cuotas_pendientes.
    Stores cuotas_pendientes as a JSON string in the `cuotas` column.
    """
    cuotas_pendientes: list[dict] = datos.get("cuotas_pendientes", [])
    comprometido = sum(float(c["valor_cuota"]) for c in cuotas_pendientes)

    # Parse fecha_vencimiento from string → date object (or None)
    fv_raw = datos.get("fecha_vencimiento")
    if isinstance(fv_raw, str):
        try:
            fv = date.fromisoformat(fv_raw)
        except ValueError:
            fv = None
    elif isinstance(fv_raw, date):
        fv = fv_raw
    else:
        fv = None

    # Delete existing row for this user (upsert by delete+insert)
    existing = session.query(TarjetaEstado).filter_by(user_id=user_id).first()
    if existing is not None:
        session.delete(existing)
        session.flush()

    row = TarjetaEstado(
        user_id=user_id,
        total_a_pagar=float(datos.get("total_a_pagar", 0)),
        monto_minimo=float(datos.get("monto_minimo", 0)),
        fecha_vencimiento=fv,
        cupo_total=float(datos.get("cupo_total", 0)),
        cupo_utilizado=float(datos.get("cupo_utilizado", 0)),
        cuotas=json.dumps(cuotas_pendientes, ensure_ascii=False),
        comprometido_proximo_mes=comprometido,
    )
    session.add(row)
    session.commit()
    session.refresh(row)
    return row


def get_estado(session: Session, user_id: str) -> dict:
    """Return the stored card state for user_id.

    Returns ``{"tiene_datos": False, ...}`` when no data exists.
    """
    row = session.query(TarjetaEstado).filter_by(user_id=user_id).first()
    if row is None:
        return {
            "tiene_datos": False,
            "total_a_pagar": 0.0,
            "monto_minimo": 0.0,
            "fecha_vencimiento": None,
            "cupo_total": 0.0,
            "cupo_utilizado": 0.0,
            "comprometido_proximo_mes": 0.0,
            "cuotas": [],
        }

    fv_iso = row.fecha_vencimiento.isoformat() if row.fecha_vencimiento is not None else None
    cuotas = json.loads(row.cuotas) if row.cuotas else []

    return {
        "tiene_datos": True,
        "total_a_pagar": float(row.total_a_pagar),
        "monto_minimo": float(row.monto_minimo),
        "fecha_vencimiento": fv_iso,
        "cupo_total": float(row.cupo_total),
        "cupo_utilizado": float(row.cupo_utilizado),
        "comprometido_proximo_mes": float(row.comprometido_proximo_mes),
        "cuotas": cuotas,
    }
