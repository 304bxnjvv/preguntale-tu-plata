"""
Servicio de proyección de fin de mes (forecast lineal honesto).

Cálculo:
- gasto_actual = Σ|monto| (monto<0) del mes hasta hoy.
- ritmo = gasto_actual / dia_del_mes.
- gasto_proyectado = gasto_actual + ritmo * dias_restantes (proyección lineal).
- ingresos_mes = Σ monto (monto>0) del mes.
- neto_proyectado = ingresos_mes - gasto_proyectado SOLO si ingresos_mes > 0, si no None.
- categorias_en_riesgo: presupuestos donde la proyección excede el tope.
- confianza: 'baja' si dia<5, 'media' si dia<12, 'alta' si no.
- Sin saldo bancario: no se proyecta saldo de cuenta, solo gasto (y neto si hay ingresos).
"""
from __future__ import annotations

import calendar
from datetime import date
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.db.models import Transaction
from app.services.presupuesto_service import estado_presupuestos


def proyectar_mes(session: Session, user_id: str, hoy: date | None = None) -> dict:
    """Proyecta gasto de fin de mes para user_id.

    Retorna dict con:
        tiene_datos, dias_restantes, dia_del_mes,
        gasto_actual, gasto_proyectado,
        ingresos_mes, neto_proyectado (None si sin ingresos),
        categorias_en_riesgo: [{categoria, tope, proyectado, pct}],
        confianza: 'baja'|'media'|'alta', caveat: str
    """
    hoy = hoy or date.today()
    mes_ini = date(hoy.year, hoy.month, 1)
    mes_siguiente_ini = date(hoy.year + (1 if hoy.month == 12 else 0),
                             1 if hoy.month == 12 else hoy.month + 1, 1)

    dia = hoy.day
    _, dias_mes = calendar.monthrange(hoy.year, hoy.month)
    dias_restantes = dias_mes - dia

    # Gasto actual del mes (hasta hoy inclusive)
    gasto_raw = (
        session.query(func.sum(Transaction.monto))
        .filter(
            Transaction.user_id == user_id,
            Transaction.monto < 0,
            Transaction.fecha >= mes_ini,
            Transaction.fecha <= hoy,
        )
        .scalar()
    )
    gasto_actual = abs(float(gasto_raw)) if gasto_raw else 0.0

    if gasto_actual == 0:
        return {
            "tiene_datos": False,
            "dias_restantes": dias_restantes,
            "dia_del_mes": dia,
            "gasto_actual": 0.0,
            "gasto_proyectado": 0.0,
            "ingresos_mes": 0.0,
            "neto_proyectado": None,
            "categorias_en_riesgo": [],
            "confianza": _confianza(dia)[0],
            "caveat": _confianza(dia)[1],
        }

    # Proyección lineal
    ritmo = gasto_actual / dia
    gasto_proyectado = gasto_actual + ritmo * dias_restantes

    # Ingresos del mes
    ingresos_raw = (
        session.query(func.sum(Transaction.monto))
        .filter(
            Transaction.user_id == user_id,
            Transaction.monto > 0,
            Transaction.fecha >= mes_ini,
            Transaction.fecha < mes_siguiente_ini,
        )
        .scalar()
    )
    ingresos_mes = float(ingresos_raw) if ingresos_raw else 0.0
    neto_proyectado = (ingresos_mes - gasto_proyectado) if ingresos_mes > 0 else None

    # Categorías en riesgo: basadas en estado_presupuestos (gasto por categoría del mes)
    presupuestos = estado_presupuestos(session, user_id)
    categorias_en_riesgo = []
    for p in presupuestos:
        gastado_cat = p["gastado"]
        tope = p["monto_tope"]
        if tope <= 0:
            continue
        # Proyectar gasto de la categoría al ritmo actual
        proy_cat = gastado_cat + (gastado_cat / dia) * dias_restantes if dia > 0 else gastado_cat
        pct_cat = proy_cat / tope
        if pct_cat > 1.0:
            categorias_en_riesgo.append({
                "categoria": p["categoria"],
                "tope": tope,
                "proyectado": proy_cat,
                "pct": pct_cat,
            })

    confianza, caveat = _confianza(dia)

    return {
        "tiene_datos": True,
        "dias_restantes": dias_restantes,
        "dia_del_mes": dia,
        "gasto_actual": gasto_actual,
        "gasto_proyectado": gasto_proyectado,
        "ingresos_mes": ingresos_mes,
        "neto_proyectado": neto_proyectado,
        "categorias_en_riesgo": categorias_en_riesgo,
        "confianza": confianza,
        "caveat": caveat,
    }


def _confianza(dia: int) -> tuple[str, str]:
    """Devuelve (nivel_confianza, caveat) según el día del mes."""
    if dia < 5:
        return "baja", "aún es temprano en el mes, la proyección puede cambiar"
    elif dia < 12:
        return "media", "la proyección irá mejorando a medida que avance el mes"
    else:
        return "alta", ""
