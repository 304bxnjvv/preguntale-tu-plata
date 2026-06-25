from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from app.rag.rag_service import ask
from app.models.schemas import AskRequest, AskResponse, ChatMessageOut
from app.auth.jwt import get_current_user
from app.db.base import get_session
from app.db.chat_repo import save_message, get_history, get_recent_for_memory

router = APIRouter()


@router.post("/chat/ask", response_model=AskResponse)
async def preguntar(
    body: AskRequest,
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    if not body.question.strip():
        raise HTTPException(status_code=400, detail="La pregunta no puede estar vacía.")

    # Load memory BEFORE saving the current question (so user msg is not duplicated).
    recent = get_recent_for_memory(session, user_id)
    history = [(m.role, m.content) for m in recent]

    # Persist user message.
    save_message(session, user_id, "user", body.question)

    # Call RAG with history context.
    result = ask(body.question, user_id, history)

    # Persist assistant message.
    save_message(session, user_id, "assistant", result.answer)

    return result


@router.get("/chat/history", response_model=list[ChatMessageOut])
async def historial(
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    return get_history(session, user_id)
