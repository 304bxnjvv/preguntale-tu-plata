"""
Demo seed service: inserts ~18 realistic Chilean transactions for a demo user.
Idempotent: if the user already has fuente="demo" rows, does nothing.
"""
from datetime import date, timedelta
from sqlalchemy.orm import Session
from app.db.models import Transaction


def _first_of_month(d: date) -> date:
    return d.replace(day=1)


def _demo_rows(user_id: str, today: date) -> list[dict]:
    """Build ~18 demo transaction dicts for current and previous calendar month."""
    curr = _first_of_month(today)
    # Previous month
    prev = _first_of_month(curr - timedelta(days=1))

    def d(month_start: date, day: int) -> date:
        return month_start.replace(day=day)

    rows = [
        # ── Ingresos ─────────────────────────────────────────────────────────
        {
            "fecha": d(prev, 1),
            "descripcion": "DEPOSITO REMUNERACION EMPRESA ABC",
            "monto": 1200000.0,
            "tipo": "abono",
            "categoria": "Transferencias",
            "banco": "bci",
        },
        {
            "fecha": d(curr, 1),
            "descripcion": "DEPOSITO REMUNERACION EMPRESA ABC",
            "monto": 1200000.0,
            "tipo": "abono",
            "categoria": "Transferencias",
            "banco": "bci",
        },
        # ── Supermercado ─────────────────────────────────────────────────────
        {
            "fecha": d(prev, 5),
            "descripcion": "SUPERMERCADO LIDER",
            "monto": -42300.0,
            "tipo": "cargo",
            "categoria": "Supermercado",
            "banco": "bci",
        },
        {
            "fecha": d(curr, 5),
            "descripcion": "JUMBO MALL COSTANERA",
            "monto": -65800.0,
            "tipo": "cargo",
            "categoria": "Supermercado",
            "banco": "bci",
        },
        {
            "fecha": d(curr, 19),
            "descripcion": "SUPERMERCADO LIDER",
            "monto": -38500.0,
            "tipo": "cargo",
            "categoria": "Supermercado",
            "banco": "bci",
        },
        # ── Comida y delivery ─────────────────────────────────────────────────
        {
            "fecha": d(prev, 8),
            "descripcion": "RAPPI CHILE",
            "monto": -14900.0,
            "tipo": "cargo",
            "categoria": "Comida y delivery",
            "banco": "bci",
        },
        {
            "fecha": d(prev, 15),
            "descripcion": "RAPPI CHILE",
            "monto": -9900.0,
            "tipo": "cargo",
            "categoria": "Comida y delivery",
            "banco": "bci",
        },
        {
            "fecha": d(curr, 7),
            "descripcion": "RAPPI CHILE",
            "monto": -12500.0,
            "tipo": "cargo",
            "categoria": "Comida y delivery",
            "banco": "bci",
        },
        # ── Transporte ────────────────────────────────────────────────────────
        {
            "fecha": d(prev, 10),
            "descripcion": "UBER CHILE",
            "monto": -5900.0,
            "tipo": "cargo",
            "categoria": "Transporte",
            "banco": "bci",
        },
        {
            "fecha": d(curr, 11),
            "descripcion": "UBER CHILE",
            "monto": -7200.0,
            "tipo": "cargo",
            "categoria": "Transporte",
            "banco": "bci",
        },
        {
            "fecha": d(curr, 15),
            "descripcion": "COPEC BENCINERA",
            "monto": -48000.0,
            "tipo": "cargo",
            "categoria": "Transporte",
            "banco": "bci",
        },
        # ── Suscripciones (recurring in BOTH months) ─────────────────────────
        {
            "fecha": d(prev, 3),
            "descripcion": "NETFLIX SUSCRIPCION",
            "monto": -7990.0,
            "tipo": "cargo",
            "categoria": "Suscripciones",
            "banco": "bci",
        },
        {
            "fecha": d(curr, 3),
            "descripcion": "NETFLIX SUSCRIPCION",
            "monto": -7990.0,
            "tipo": "cargo",
            "categoria": "Suscripciones",
            "banco": "bci",
        },
        {
            "fecha": d(prev, 4),
            "descripcion": "SPOTIFY PREMIUM",
            "monto": -3990.0,
            "tipo": "cargo",
            "categoria": "Suscripciones",
            "banco": "bci",
        },
        {
            "fecha": d(curr, 4),
            "descripcion": "SPOTIFY PREMIUM",
            "monto": -3990.0,
            "tipo": "cargo",
            "categoria": "Suscripciones",
            "banco": "bci",
        },
        # ── Salud ─────────────────────────────────────────────────────────────
        {
            "fecha": d(curr, 9),
            "descripcion": "FARMACIA CRUZ VERDE",
            "monto": -18500.0,
            "tipo": "cargo",
            "categoria": "Salud",
            "banco": "bci",
        },
        # ── Compras ───────────────────────────────────────────────────────────
        {
            "fecha": d(curr, 13),
            "descripcion": "FALABELLA TIENDA",
            "monto": -59990.0,
            "tipo": "cargo",
            "categoria": "Compras",
            "banco": "bci",
        },
        # ── Cuentas y servicios ───────────────────────────────────────────────
        {
            "fecha": d(curr, 10),
            "descripcion": "ENEL DISTRIBUCIÓN BOLETA",
            "monto": -32100.0,
            "tipo": "cargo",
            "categoria": "Cuentas y servicios",
            "banco": "bci",
        },
    ]
    return rows


def seed_demo(session: Session, user_id: str, today: date | None = None) -> int:
    """Insert ~18 realistic demo transactions. Idempotent: returns 0 if already seeded."""
    from app.db.models import Transaction  # local to avoid circular

    existing = (
        session.query(Transaction)
        .filter(Transaction.user_id == user_id, Transaction.fuente == "demo")
        .count()
    )
    if existing > 0:
        return 0

    if today is None:
        today = date.today()

    rows = _demo_rows(user_id, today)
    for r in rows:
        session.add(
            Transaction(
                user_id=user_id,
                fecha=r["fecha"],
                descripcion=r["descripcion"],
                monto=r["monto"],
                moneda="CLP",
                tarjeta=None,
                tipo=r["tipo"],
                categoria=r["categoria"],
                banco=r["banco"],
                fuente="demo",
            )
        )
    session.commit()
    return len(rows)


def clear_demo(session: Session, user_id: str) -> int:
    """Delete all fuente='demo' rows for user_id. Returns count deleted."""
    rows = (
        session.query(Transaction)
        .filter(Transaction.user_id == user_id, Transaction.fuente == "demo")
        .all()
    )
    count = len(rows)
    for row in rows:
        session.delete(row)
    session.commit()
    return count
