"""
Insights service: subscription detection + month-over-month comparison + FinScore.
"""
from __future__ import annotations

from collections import defaultdict
from datetime import date, timedelta

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.db.models import Transaction


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _normalize(text: str) -> str:
    """Lower-case + strip whitespace — used as dedup/recurrence key."""
    return text.strip().lower()


# ---------------------------------------------------------------------------
# detectar_suscripciones
# ---------------------------------------------------------------------------

def detectar_suscripciones(session: Session, user_id: str) -> dict:
    """Return subscription candidates for *user_id*.

    A transaction is a subscription candidate if:
    1. Its ``categoria`` == "Suscripciones", OR
    2. The same normalized ``descripcion`` appears in ≥2 distinct calendar months
       with a similar amount (±10% of the most recent amount).

    Returns a dict with shape::

        {
            "total_mensual": float,          # sum of |monto| of deduplicated items
            "items": [
                {"descripcion": str, "monto": float, "categoria": str},
                ...
            ]
        }

    Items are deduplicated by normalised description; where the same description
    appears multiple times, the most-recent occurrence wins.
    """
    rows = (
        session.query(Transaction)
        .filter(Transaction.user_id == user_id)
        .filter(Transaction.monto < 0)
        .order_by(Transaction.fecha.desc())
        .all()
    )

    # Group by normalized description to detect recurrence
    # groups: norm_desc -> list of (fecha, monto, categoria)
    groups: dict[str, list[tuple[date, float, str | None]]] = defaultdict(list)
    for row in rows:
        key = _normalize(row.descripcion)
        groups[key].append((row.fecha, float(row.monto), row.categoria))

    # For the "Suscripciones" categoria set — collect all distinct keys that
    # appear in that category (using the most-recent occurrence of each key).
    sus_keys: set[str] = set()
    for key, occurrences in groups.items():
        for _fecha, _monto, cat in occurrences:
            if cat == "Suscripciones":
                sus_keys.add(key)
                break

    # Detect recurrent keys: same normalized desc in ≥2 distinct calendar months
    # with similar amount (±10%)
    recurrent_keys: set[str] = set()
    for key, occurrences in groups.items():
        if len(occurrences) < 2:
            continue
        # Distinct calendar months (YYYY-MM)
        months = {(f.year, f.month) for f, _, _ in occurrences}
        if len(months) < 2:
            continue
        # Amount similarity: compare each pair against the most recent monto
        most_recent_monto = occurrences[0][1]  # already sorted desc by fecha
        ref = abs(most_recent_monto)
        similar = all(
            abs(abs(m) - ref) <= ref * 0.10
            for _f, m, _c in occurrences
        )
        if similar:
            recurrent_keys.add(key)

    candidate_keys = sus_keys | recurrent_keys

    # Build deduplicated items (most-recent occurrence per key)
    seen_keys: set[str] = set()
    items = []
    for row in rows:  # already sorted desc → first occurrence = most recent
        key = _normalize(row.descripcion)
        if key not in candidate_keys or key in seen_keys:
            continue
        seen_keys.add(key)
        items.append({
            "descripcion": row.descripcion,
            "monto": abs(float(row.monto)),
            "categoria": row.categoria or "Suscripciones",
        })

    total_mensual = sum(i["monto"] for i in items)
    return {"total_mensual": total_mensual, "items": items}


# ---------------------------------------------------------------------------
# comparativo_mensual
# ---------------------------------------------------------------------------

def comparativo_mensual(session: Session, user_id: str) -> dict:
    """Compare total spending (|monto| where monto<0) this calendar month vs last.

    Returns::

        {
            "mes_actual":    "YYYY-MM",
            "mes_anterior":  "YYYY-MM",
            "gastos_actual":  float,   # sum of |monto| current month
            "gastos_anterior": float,  # sum of |monto| previous month
            "delta":          float,   # gastos_actual - gastos_anterior
            "top_cambios": [           # top-3 categories by |delta|
                {"categoria": str, "delta": float},
                ...
            ]
        }
    """
    today = date.today()
    # Current month start
    curr_start = date(today.year, today.month, 1)
    # Previous month start
    if today.month == 1:
        prev_start = date(today.year - 1, 12, 1)
    else:
        prev_start = date(today.year, today.month - 1, 1)

    mes_actual = curr_start.strftime("%Y-%m")
    mes_anterior = prev_start.strftime("%Y-%m")

    def _month_total(start: date, end: date) -> float:
        result = (
            session.query(func.sum(Transaction.monto))
            .filter(Transaction.user_id == user_id)
            .filter(Transaction.monto < 0)
            .filter(Transaction.fecha >= start)
            .filter(Transaction.fecha < end)
            .scalar()
        )
        return abs(float(result)) if result else 0.0

    gastos_actual = _month_total(curr_start, date(today.year, today.month + 1, 1)
                                  if today.month < 12
                                  else date(today.year + 1, 1, 1))
    gastos_anterior = _month_total(prev_start, curr_start)

    # Per-category breakdown for both months
    def _cat_total(start: date, end: date) -> dict[str, float]:
        rows = (
            session.query(Transaction.categoria, func.sum(Transaction.monto))
            .filter(Transaction.user_id == user_id)
            .filter(Transaction.monto < 0)
            .filter(Transaction.categoria.isnot(None))
            .filter(Transaction.fecha >= start)
            .filter(Transaction.fecha < end)
            .group_by(Transaction.categoria)
            .all()
        )
        return {cat: abs(float(total)) for cat, total in rows}

    next_month_start = (
        date(today.year, today.month + 1, 1)
        if today.month < 12
        else date(today.year + 1, 1, 1)
    )

    cats_actual = _cat_total(curr_start, next_month_start)
    cats_prev = _cat_total(prev_start, curr_start)

    all_cats = set(cats_actual) | set(cats_prev)
    cambios = [
        {
            "categoria": cat,
            "delta": cats_actual.get(cat, 0.0) - cats_prev.get(cat, 0.0),
        }
        for cat in all_cats
    ]
    top_cambios = sorted(cambios, key=lambda x: abs(x["delta"]), reverse=True)[:3]

    return {
        "mes_actual": mes_actual,
        "mes_anterior": mes_anterior,
        "gastos_actual": gastos_actual,
        "gastos_anterior": gastos_anterior,
        "delta": gastos_actual - gastos_anterior,
        "top_cambios": top_cambios,
    }


# ---------------------------------------------------------------------------
# calcular_finscore
# ---------------------------------------------------------------------------

def calcular_finscore(session: Session, user_id: str) -> dict:
    """Calculate a heuristic financial health score (0-100) for *user_id*.

    FORMULA (heuristic — adjust multipliers as business data matures):
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Window: últimos 90 días (o toda la historia si hay menos datos).
    1. ``ingresos`` = sum of monto where monto > 0.
       ``gastos``   = sum of |monto| where monto < 0.
    2. If ingresos == 0: score=50, nivel='sin datos' — no meaningful signal.
    3. tasa_ahorro = (ingresos - gastos) / ingresos.
       score_base = clamp(round(55 + tasa_ahorro * 130), 5, 99)
       Examples: ahorro 0% → 55; ahorro 20% → 81; gasto -40% sobre ingreso → 3 → clamp 5.
    4. Subscription modifier:
       susc = detectar_suscripciones(...)["total_mensual"]
       If susc / ingresos > 0.15 → score -= 8
    5. Final score = clamp(score, 5, 99).
    6. nivel: score >= 75 → "vas bien"; 50-74 → "ojo"; < 50 → "alerta".
    7. factores: list of 2-4 {"texto": str, "signo": "+"|"-"} in Chilean Spanish.

    Returns:
        {
            "score": int,
            "nivel": str,         # "vas bien" | "ojo" | "alerta" | "sin datos"
            "resumen": str,       # warm one-liner
            "factores": list[dict],
            "tasa_ahorro": float,
        }
    """
    cutoff = date.today() - timedelta(days=90)

    ingresos_raw = (
        session.query(func.sum(Transaction.monto))
        .filter(Transaction.user_id == user_id)
        .filter(Transaction.monto > 0)
        .filter(Transaction.fecha >= cutoff)
        .scalar()
    )
    gastos_raw = (
        session.query(func.sum(Transaction.monto))
        .filter(Transaction.user_id == user_id)
        .filter(Transaction.monto < 0)
        .filter(Transaction.fecha >= cutoff)
        .scalar()
    )

    ingresos = float(ingresos_raw) if ingresos_raw else 0.0
    gastos = abs(float(gastos_raw)) if gastos_raw else 0.0

    if ingresos == 0:
        return {
            "score": 50,
            "nivel": "sin datos",
            "resumen": "necesito más datos para calcular tu salud financiera",
            "factores": [],
            "tasa_ahorro": 0.0,
        }

    tasa_ahorro = (ingresos - gastos) / ingresos

    score = max(5, min(99, round(55 + tasa_ahorro * 130)))

    # Subscription modifier
    susc = detectar_suscripciones(session, user_id)["total_mensual"]
    susc_penalizado = susc / ingresos > 0.15

    if susc_penalizado:
        score = max(5, min(99, score - 8))

    # Nivel
    if score >= 75:
        nivel = "vas bien"
        resumen = "¡Vas por buen camino! Sigue así y tu billetera lo va a agradecer."
    elif score >= 50:
        nivel = "ojo"
        resumen = "Tu situación está okay, pero hay espacio para mejorar."
    else:
        nivel = "alerta"
        resumen = "Ojo, estás gastando más de lo que entra. Revisemos juntos tus gastos."

    # Factores
    factores: list[dict] = []

    ahorro_pct = round(tasa_ahorro * 100, 1)
    if tasa_ahorro >= 0:
        factores.append({
            "texto": f"ahorras el {ahorro_pct}% de lo que ganas",
            "signo": "+" if tasa_ahorro > 0 else "-",
        })
    else:
        factores.append({
            "texto": f"gastaste un {abs(ahorro_pct)}% más de lo que ingresó",
            "signo": "-",
        })

    if susc > 0:
        susc_fmt = f"${susc:,.0f}".replace(",", ".")
        if susc_penalizado:
            factores.append({
                "texto": f"{susc_fmt}/mes en suscripciones (más del 15% de tu ingreso)",
                "signo": "-",
            })
        else:
            factores.append({
                "texto": f"{susc_fmt}/mes en suscripciones, dentro de lo razonable",
                "signo": "+",
            })

    if ingresos > 0 and gastos > 0:
        ratio = gastos / ingresos
        if ratio < 0.6:
            factores.append({
                "texto": "tus gastos son controlados respecto a tus ingresos",
                "signo": "+",
            })
        elif ratio > 1.0:
            factores.append({
                "texto": "gastaste más de lo que ingresó este período",
                "signo": "-",
            })

    return {
        "score": score,
        "nivel": nivel,
        "resumen": resumen,
        "factores": factores,
        "tasa_ahorro": tasa_ahorro,
    }
