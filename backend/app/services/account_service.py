"""
Account data service: hard-delete all user financial data.

Borra: Transaction, ChatMessage, Upload, TarjetaEstado, Presupuesto, Meta, CategoriaOverride.
NO borra: Subscription (relación de cobro, se mantiene).
"""
from sqlalchemy.orm import Session
from app.db.models import (
    Transaction,
    ChatMessage,
    Upload,
    TarjetaEstado,
    Presupuesto,
    Meta,
    CategoriaOverride,
)


def delete_user_data(session: Session, user_id: str) -> dict:
    """
    Delete ALL rows for user_id across all financial data tables:
    Transaction, ChatMessage, Upload, TarjetaEstado, Presupuesto, Meta, CategoriaOverride.

    Does NOT delete Subscription rows (billing relationship is preserved).

    Returns counts of deleted rows per table:
      transactions, chat, uploads, tarjeta, presupuestos, metas, overrides.
    """
    transactions = (
        session.query(Transaction)
        .filter(Transaction.user_id == user_id)
        .all()
    )
    t_count = len(transactions)
    for row in transactions:
        session.delete(row)

    chats = (
        session.query(ChatMessage)
        .filter(ChatMessage.user_id == user_id)
        .all()
    )
    c_count = len(chats)
    for row in chats:
        session.delete(row)

    uploads = (
        session.query(Upload)
        .filter(Upload.user_id == user_id)
        .all()
    )
    u_count = len(uploads)
    for row in uploads:
        session.delete(row)

    tarjetas = (
        session.query(TarjetaEstado)
        .filter(TarjetaEstado.user_id == user_id)
        .all()
    )
    tarjeta_count = len(tarjetas)
    for row in tarjetas:
        session.delete(row)

    presupuestos = (
        session.query(Presupuesto)
        .filter(Presupuesto.user_id == user_id)
        .all()
    )
    presupuesto_count = len(presupuestos)
    for row in presupuestos:
        session.delete(row)

    metas = (
        session.query(Meta)
        .filter(Meta.user_id == user_id)
        .all()
    )
    meta_count = len(metas)
    for row in metas:
        session.delete(row)

    overrides = (
        session.query(CategoriaOverride)
        .filter(CategoriaOverride.user_id == user_id)
        .all()
    )
    override_count = len(overrides)
    for row in overrides:
        session.delete(row)

    session.commit()
    return {
        "transactions": t_count,
        "chat": c_count,
        "uploads": u_count,
        "tarjeta": tarjeta_count,
        "presupuestos": presupuesto_count,
        "metas": meta_count,
        "overrides": override_count,
    }
