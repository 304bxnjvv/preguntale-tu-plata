"""
Insights service: subscription detection + month-over-month comparison.
"""
from __future__ import annotations

from collections import defaultdict
from datetime import date

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
