"""
Servicio de alertas: evalúa reglas sobre el estado financiero del usuario y
devuelve una lista de alertas in-app. Reusa los servicios de tarjeta y
presupuestos. Cada alerta tiene una `key` determinística para que el front
pueda marcarlas como vistas.
"""
from __future__ import annotations

import statistics
from datetime import date, timedelta

from sqlalchemy.orm import Session

from app.db.models import Transaction
from app.services.tarjeta_service import get_estado
from app.services.presupuesto_service import estado_presupuestos

# Umbrales
_DIAS_VENCIMIENTO = 5          # alertar si la tarjeta vence dentro de N días
_DIAS_GASTO_RECIENTE = 7       # ventana de gastos "recientes"
_DIAS_HISTORIA_GASTOS = 90     # ventana para calcular la mediana
_FACTOR_GASTO_INUSUAL = 3.0    # |monto| > factor * mediana
_PISO_GASTO_INUSUAL = 50000.0  # y además |monto| > este piso


def evaluar_alertas(session: Session, user_id: str) -> list[dict]:
    """Evalúa todas las reglas de alerta para el usuario.

    Cada alerta es un dict con shape:
        {key, tipo, severidad, titulo, detalle, fecha}

    Severidades: 'urgent' | 'warning' | 'info'.
    """
    hoy = date.today()
    alertas: list[dict] = []

    alertas.extend(_alertas_tarjeta_vence(session, user_id, hoy))
    alertas.extend(_alertas_presupuesto(session, user_id))
    alertas.extend(_alertas_cuotas_proximo_mes(session, user_id))
    alertas.extend(_alertas_gasto_inusual(session, user_id, hoy))

    return alertas


def _fmt_clp(monto: float) -> str:
    return f"${monto:,.0f}".replace(",", ".")


def _alertas_tarjeta_vence(session: Session, user_id: str, hoy: date) -> list[dict]:
    estado = get_estado(session, user_id)
    if not estado.get("tiene_datos"):
        return []
    fv_iso = estado.get("fecha_vencimiento")
    if not fv_iso:
        return []
    try:
        fv = date.fromisoformat(fv_iso)
    except (ValueError, TypeError):
        return []
    dias = (fv - hoy).days
    if dias > _DIAS_VENCIMIENTO:
        return []

    total = float(estado.get("total_a_pagar", 0) or 0)
    if dias < 0:
        detalle = f"Tu tarjeta venció el {fv_iso}. Tienes {_fmt_clp(total)} por pagar."
    elif dias == 0:
        detalle = f"Tu tarjeta vence hoy. Tienes {_fmt_clp(total)} por pagar."
    else:
        detalle = (
            f"Tu tarjeta vence en {dias} día{'s' if dias != 1 else ''}. "
            f"Tienes {_fmt_clp(total)} por pagar."
        )

    return [{
        "key": f"tarjeta_vence:{fv_iso}",
        "tipo": "tarjeta_vence",
        "severidad": "urgent",
        "titulo": "Tu tarjeta está por vencer",
        "detalle": detalle,
        "fecha": fv_iso,
    }]


def _alertas_presupuesto(session: Session, user_id: str) -> list[dict]:
    hoy_iso = date.today().isoformat()
    out: list[dict] = []
    for est in estado_presupuestos(session, user_id):
        if est["estado"] not in ("cerca", "excedido"):
            continue
        categoria = est["categoria"]
        pct = est["pct"]
        gastado = _fmt_clp(est["gastado"])
        tope = _fmt_clp(est["monto_tope"])
        if est["estado"] == "excedido":
            titulo = f"Te pasaste en {categoria}"
            detalle = f"Llevas {gastado} de {tope} este mes ({pct * 100:.0f}%)."
        else:
            titulo = f"Vas cerca del tope en {categoria}"
            detalle = f"Llevas {gastado} de {tope} este mes ({pct * 100:.0f}%)."
        out.append({
            "key": f"presupuesto:{categoria}",
            "tipo": "presupuesto",
            "severidad": "warning",
            "titulo": titulo,
            "detalle": detalle,
            "fecha": hoy_iso,
        })
    return out


def _alertas_cuotas_proximo_mes(session: Session, user_id: str) -> list[dict]:
    estado = get_estado(session, user_id)
    if not estado.get("tiene_datos"):
        return []
    comprometido = float(estado.get("comprometido_proximo_mes", 0) or 0)
    if comprometido <= 0:
        return []
    return [{
        "key": "cuotas_proximo_mes",
        "tipo": "cuotas_proximo_mes",
        "severidad": "warning",
        "titulo": "Cuotas comprometidas el próximo mes",
        "detalle": (
            f"Ya tienes {_fmt_clp(comprometido)} comprometidos en cuotas "
            f"para el próximo mes."
        ),
        "fecha": date.today().isoformat(),
    }]


def _alertas_gasto_inusual(session: Session, user_id: str, hoy: date) -> list[dict]:
    inicio_historia = hoy - timedelta(days=_DIAS_HISTORIA_GASTOS)
    gastos = (
        session.query(Transaction)
        .filter(Transaction.user_id == user_id)
        .filter(Transaction.monto < 0)
        .filter(Transaction.fecha >= inicio_historia)
        .filter(Transaction.fecha <= hoy)
        .all()
    )
    if len(gastos) < 2:
        return []

    montos_abs = [abs(float(g.monto)) for g in gastos]
    mediana = statistics.median(montos_abs)
    if mediana <= 0:
        return []

    umbral = mediana * _FACTOR_GASTO_INUSUAL
    inicio_reciente = hoy - timedelta(days=_DIAS_GASTO_RECIENTE)

    out: list[dict] = []
    for g in gastos:
        if g.fecha < inicio_reciente:
            continue
        monto_abs = abs(float(g.monto))
        if monto_abs > umbral and monto_abs > _PISO_GASTO_INUSUAL:
            fecha_iso = g.fecha.isoformat()
            out.append({
                "key": f"gasto:{g.id}",
                "tipo": "gasto_inusual",
                "severidad": "info",
                "titulo": "Gasto fuera de lo habitual",
                "detalle": (
                    f"{g.descripcion}: {_fmt_clp(monto_abs)} el {fecha_iso}. "
                    f"Es bastante más alto que tu gasto típico."
                ),
                "fecha": fecha_iso,
            })
    return out
