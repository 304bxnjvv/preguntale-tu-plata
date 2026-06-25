"""
Servicio de metas de ahorro: crear, actualizar, eliminar y listar.
"""
from __future__ import annotations

from datetime import date, datetime, timezone
from typing import Any

from sqlalchemy.orm import Session

from app.db.models import Meta


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _meta_to_dict(meta: Meta) -> dict:
    """Convierte una instancia Meta a dict con campos calculados."""
    objetivo = float(meta.monto_objetivo) if meta.monto_objetivo is not None else 0.0
    actual = float(meta.monto_actual) if meta.monto_actual is not None else 0.0

    # progreso: clamp(actual/objetivo, 0, 1); 0 si objetivo == 0
    if objetivo > 0:
        progreso = min(actual / objetivo, 1.0)
    else:
        progreso = 0.0

    # aporte_mensual_necesario
    aporte: float | None = None
    if meta.fecha_objetivo is not None:
        # normalizar a date si es string
        if isinstance(meta.fecha_objetivo, str):
            fecha_obj = date.fromisoformat(meta.fecha_objetivo)
        else:
            fecha_obj = meta.fecha_objetivo

        hoy = date.today()
        dias_restantes = (fecha_obj - hoy).days
        if dias_restantes > 0:
            meses = max(1, round(dias_restantes / 30))
            restante = objetivo - actual
            aporte = max(0.0, restante / meses)
        else:
            # fecha ya pasada o es hoy → aporte 0
            aporte = 0.0

    fecha_objetivo_str: str | None = None
    if meta.fecha_objetivo is not None:
        if isinstance(meta.fecha_objetivo, str):
            fecha_objetivo_str = meta.fecha_objetivo
        else:
            fecha_objetivo_str = meta.fecha_objetivo.isoformat()

    return {
        "id": meta.id,
        "nombre": meta.nombre,
        "monto_objetivo": objetivo,
        "monto_actual": actual,
        "fecha_objetivo": fecha_objetivo_str,
        "progreso": progreso,
        "aporte_mensual_necesario": aporte,
    }


# ---------------------------------------------------------------------------
# Service functions
# ---------------------------------------------------------------------------

def crear_meta(
    session: Session,
    user_id: str,
    nombre: str,
    monto_objetivo: float,
    fecha_objetivo: str | None,
) -> dict:
    """Crea una nueva meta de ahorro para el usuario.

    Returns el dict de la meta creada con campos calculados.
    """
    fecha_obj: date | None = None
    if fecha_objetivo is not None:
        fecha_obj = date.fromisoformat(fecha_objetivo)

    meta = Meta(
        user_id=user_id,
        nombre=nombre,
        monto_objetivo=monto_objetivo,
        monto_actual=0,
        fecha_objetivo=fecha_obj,
    )
    session.add(meta)
    session.commit()
    session.refresh(meta)
    return _meta_to_dict(meta)


def actualizar_meta(
    session: Session,
    user_id: str,
    meta_id: str,
    **campos: Any,
) -> dict | None:
    """Actualiza campos de una meta del usuario.

    Campos admitidos: nombre, monto_objetivo, monto_actual, fecha_objetivo.
    Returns el dict actualizado, o None si no existe.
    """
    meta = session.query(Meta).filter_by(id=meta_id, user_id=user_id).first()
    if meta is None:
        return None

    if "nombre" in campos and campos["nombre"] is not None:
        meta.nombre = campos["nombre"]
    if "monto_objetivo" in campos and campos["monto_objetivo"] is not None:
        meta.monto_objetivo = campos["monto_objetivo"]
    if "monto_actual" in campos and campos["monto_actual"] is not None:
        meta.monto_actual = campos["monto_actual"]
    if "fecha_objetivo" in campos:
        valor = campos["fecha_objetivo"]
        if valor is None:
            meta.fecha_objetivo = None
        elif isinstance(valor, str):
            meta.fecha_objetivo = date.fromisoformat(valor)
        else:
            meta.fecha_objetivo = valor

    meta.updated_at = datetime.now(timezone.utc)
    session.commit()
    session.refresh(meta)
    return _meta_to_dict(meta)


def eliminar_meta(session: Session, user_id: str, meta_id: str) -> bool:
    """Elimina la meta del usuario.

    Returns True si existía y fue eliminada, False si no existía.
    """
    meta = session.query(Meta).filter_by(id=meta_id, user_id=user_id).first()
    if meta is None:
        return False
    session.delete(meta)
    session.commit()
    return True


def listar_metas(session: Session, user_id: str) -> list[dict]:
    """Lista todas las metas del usuario, ordenadas por created_at."""
    metas = (
        session.query(Meta)
        .filter_by(user_id=user_id)
        .order_by(Meta.created_at)
        .all()
    )
    return [_meta_to_dict(m) for m in metas]
