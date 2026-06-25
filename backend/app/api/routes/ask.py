from datetime import date
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from app.rag.rag_service import ask, indexar_transacciones
from app.models.schemas import AskRequest, AskResponse, ChatMessageOut, Transaccion
from app.auth.jwt import get_current_user
from app.db.base import get_session
from app.db.chat_repo import save_message, get_history, get_recent_for_memory, delete_message
from app.services.chat_logger import clasificar_y_extraer
from app.services.transaction_service import insert_transactions

router = APIRouter()


@router.post("/chat/ask", response_model=AskResponse)
async def preguntar(
    body: AskRequest,
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    if not body.question.strip():
        raise HTTPException(status_code=400, detail="La pregunta no puede estar vacía.")

    # ── Chat-logger branch: detect spend/income logs before RAG ──────────────
    registro = clasificar_y_extraer(body.question)
    if registro is not None:
        tipo = registro["tipo"]
        monto_raw = registro["monto"]
        descripcion = registro["descripcion"]
        categoria = registro["categoria"]

        # Sign: gastos son negativos, ingresos positivos
        monto = -abs(monto_raw) if tipo == "gasto" else abs(monto_raw)
        tipo_txn = "cargo" if monto < 0 else "abono"

        txn = Transaccion(
            fecha=date.today(),
            descripcion=descripcion,
            monto=monto,
            tipo=tipo_txn,
            categoria=categoria,
            banco="manual",
            moneda="CLP",
        )
        inserted = insert_transactions(session, user_id, [txn], fuente="manual")

        # Index in vector store regardless of dup (graceful if already there)
        try:
            indexar_transacciones([txn], user_id)
        except Exception:
            pass  # vector store failure must not block the confirmation

        # Warm Chilean confirmation
        monto_fmt = f"${abs(monto):,.0f}".replace(",", ".")
        if tipo == "gasto":
            confirmacion = f"listo, anoté {monto_fmt} en {descripcion} 📝 ({categoria})"
        else:
            confirmacion = f"anotado, ingreso de {monto_fmt} por {descripcion} 💰 ({categoria})"

        save_message(session, user_id, "user", body.question)
        save_message(session, user_id, "assistant", confirmacion)
        return AskResponse(answer=confirmacion, citations=[])

    # ── Normal RAG flow (unchanged) ───────────────────────────────────────────
    recent = get_recent_for_memory(session, user_id)
    history = [(m.role, m.content) for m in recent]

    user_msg = save_message(session, user_id, "user", body.question)

    try:
        result = ask(body.question, user_id, history, session=session)
    except Exception:
        delete_message(session, user_msg.id)
        raise HTTPException(
            status_code=502,
            detail="No se pudo procesar la pregunta. Intenta de nuevo.",
        )

    save_message(session, user_id, "assistant", result.answer)
    return result


@router.get("/chat/history", response_model=list[ChatMessageOut])
async def historial(
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    return get_history(session, user_id)
