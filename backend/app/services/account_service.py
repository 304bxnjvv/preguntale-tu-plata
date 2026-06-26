"""
Account data service: export and hard-delete all user financial data.

Borra: Transaction, ChatMessage, Upload, TarjetaEstado, Presupuesto, Meta, CategoriaOverride.
NO borra: Subscription (relación de cobro, se mantiene).
"""
import httpx
from sqlalchemy.orm import Session
from app.db.models import (
    Transaction,
    ChatMessage,
    Upload,
    TarjetaEstado,
    Presupuesto,
    Meta,
    CategoriaOverride,
    CategoriaUsuario,
    Subscription,
)
from app.services.tarjeta_service import get_estado


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


def exportar_datos(session: Session, user_id: str, exportado_at: str) -> dict:
    """
    Reúne TODOS los datos del usuario en un dict serializable a JSON.
    Incluye: transactions, chat_messages, presupuestos, metas, tarjeta_estado,
    categoria_overrides, categorias_usuario, uploads, subscription.

    exportado_at: ISO timestamp generado por el endpoint (no por este service,
    para facilitar testing determinista).
    """
    # Transactions
    transactions = (
        session.query(Transaction)
        .filter(Transaction.user_id == user_id)
        .order_by(Transaction.fecha)
        .all()
    )
    txs_out = []
    for t in transactions:
        txs_out.append({
            "fecha": t.fecha.isoformat() if t.fecha else None,
            "descripcion": t.descripcion,
            "monto": float(t.monto) if t.monto is not None else None,
            "moneda": t.moneda,
            "tipo": t.tipo,
            "categoria": t.categoria,
            "banco": t.banco,
            "fuente": t.fuente,
        })

    # Chat messages
    chats = (
        session.query(ChatMessage)
        .filter(ChatMessage.user_id == user_id)
        .order_by(ChatMessage.created_at)
        .all()
    )
    chats_out = []
    for c in chats:
        chats_out.append({
            "role": c.role,
            "content": c.content,
            "created_at": c.created_at.isoformat() if c.created_at else None,
        })

    # Presupuestos
    presupuestos = (
        session.query(Presupuesto)
        .filter(Presupuesto.user_id == user_id)
        .all()
    )
    presupuestos_out = []
    for p in presupuestos:
        presupuestos_out.append({
            "categoria": p.categoria,
            "monto_tope": float(p.monto_tope) if p.monto_tope is not None else None,
        })

    # Metas
    metas = (
        session.query(Meta)
        .filter(Meta.user_id == user_id)
        .all()
    )
    metas_out = []
    for m in metas:
        metas_out.append({
            "nombre": m.nombre,
            "monto_objetivo": float(m.monto_objetivo) if m.monto_objetivo is not None else None,
            "monto_actual": float(m.monto_actual) if m.monto_actual is not None else None,
            "fecha_objetivo": m.fecha_objetivo.isoformat() if m.fecha_objetivo else None,
        })

    # TarjetaEstado
    tarjeta_estado = get_estado(session, user_id)

    # CategoriaOverrides
    overrides = (
        session.query(CategoriaOverride)
        .filter(CategoriaOverride.user_id == user_id)
        .all()
    )
    overrides_out = []
    for o in overrides:
        overrides_out.append({
            "comercio_key": o.comercio_key,
            "categoria": o.categoria,
        })

    # Categorias usuario
    cats = (
        session.query(CategoriaUsuario)
        .filter(CategoriaUsuario.user_id == user_id)
        .all()
    )
    cats_out = [{"nombre": c.nombre} for c in cats]

    # Uploads
    uploads = (
        session.query(Upload)
        .filter(Upload.user_id == user_id)
        .order_by(Upload.created_at)
        .all()
    )
    uploads_out = []
    for u in uploads:
        uploads_out.append({
            "filename": u.filename,
            "n_transacciones": u.n_transacciones,
            "created_at": u.created_at.isoformat() if u.created_at else None,
        })

    # Subscription
    sub = session.query(Subscription).filter(Subscription.user_id == user_id).first()
    subscription_out = None
    if sub:
        subscription_out = {
            "estado": sub.estado,
            "trial_ends_at": sub.trial_ends_at.isoformat() if sub.trial_ends_at else None,
            "periodo_fin": sub.periodo_fin.isoformat() if sub.periodo_fin else None,
            "created_at": sub.created_at.isoformat() if sub.created_at else None,
        }

    return {
        "exportado_at": exportado_at,
        "user_id": user_id,
        "transactions": txs_out,
        "chat_messages": chats_out,
        "presupuestos": presupuestos_out,
        "metas": metas_out,
        "tarjeta_estado": tarjeta_estado,
        "categoria_overrides": overrides_out,
        "categorias_usuario": cats_out,
        "uploads": uploads_out,
        "subscription": subscription_out,
    }


def eliminar_cuenta(
    session: Session,
    user_id: str,
    token_service_role: str,
    supabase_url: str,
) -> dict:
    """
    Borra todos los datos del usuario (llama a delete_user_data) y luego,
    si token_service_role no está vacío, elimina el usuario de Supabase Auth
    vía la Admin API.

    Retorna {"datos_eliminados": True, "auth_eliminada": bool}.
    auth_eliminada es True solo si la llamada a Supabase fue exitosa (200/204).
    Si token_service_role está vacío, no hace ninguna llamada de red.
    Los errores de red se manejan sin romper (auth_eliminada False).
    """
    delete_user_data(session, user_id)

    if not token_service_role:
        return {"datos_eliminados": True, "auth_eliminada": False}

    # Llama a la Admin API de Supabase para borrar el usuario Auth
    auth_eliminada = False
    try:
        url = f"{supabase_url}/auth/v1/admin/users/{user_id}"
        headers = {
            "Authorization": f"Bearer {token_service_role}",
            "apikey": token_service_role,
        }
        response = httpx.delete(url, headers=headers, timeout=10.0)
        if response.status_code in (200, 204):
            auth_eliminada = True
    except Exception:
        auth_eliminada = False

    return {"datos_eliminados": True, "auth_eliminada": auth_eliminada}
