# backend/app/services/resumen_semanal_service.py
from __future__ import annotations
from datetime import date, timedelta
from collections import defaultdict
from sqlalchemy.orm import Session
from app.db.models import Transaction


def _fmt(x: float) -> str:
    return f"${x:,.0f}".replace(",", ".")


def generar_resumen(session: Session, user_id: str, hoy: date | None = None) -> dict:
    hoy = hoy or date.today()
    ini = hoy - timedelta(days=7)
    ini_prev = hoy - timedelta(days=14)

    def _gastos(desde, hasta):
        return (session.query(Transaction)
                .filter(Transaction.user_id == user_id, Transaction.monto < 0,
                        Transaction.fecha >= desde, Transaction.fecha < hasta).all())

    sem = _gastos(ini, hoy + timedelta(days=1))
    gasto_semana = sum(abs(float(t.monto)) for t in sem)
    if gasto_semana == 0:
        return {"tiene_datos": False, "periodo": f"{ini.isoformat()}..{hoy.isoformat()}",
                "gasto_semana": 0.0, "top_categoria": None, "top_monto": 0.0,
                "delta_pct": None, "texto": ""}

    por_cat: dict[str, float] = defaultdict(float)
    for t in sem:
        por_cat[t.categoria or "Otros"] += abs(float(t.monto))
    top_categoria, top_monto = max(por_cat.items(), key=lambda kv: kv[1])

    prev = _gastos(ini_prev, ini)
    gasto_prev = sum(abs(float(t.monto)) for t in prev)
    delta_pct = ((gasto_semana - gasto_prev) / gasto_prev * 100) if gasto_prev > 0 else None

    # Plantilla chilena determinista
    partes = [f"Esta semana se te fueron {_fmt(gasto_semana)}."]
    partes.append(f"Lo más fuerte fue {top_categoria} ({_fmt(top_monto)}).")
    if delta_pct is not None:
        if delta_pct > 5:
            partes.append(f"Gastaste un {abs(delta_pct):.0f}% más que la semana pasada, ojo 👀.")
        elif delta_pct < -5:
            partes.append(f"Bajaste un {abs(delta_pct):.0f}% vs la semana pasada, ¡bien ahí! 👏.")
        else:
            partes.append("Te mantuviste parecido a la semana pasada.")
    texto = " ".join(partes)

    return {"tiene_datos": True, "periodo": f"{ini.isoformat()}..{hoy.isoformat()}",
            "gasto_semana": gasto_semana, "top_categoria": top_categoria, "top_monto": top_monto,
            "delta_pct": delta_pct, "texto": texto}
