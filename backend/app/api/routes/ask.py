from fastapi import APIRouter, HTTPException, Depends
from app.rag.rag_service import ask
from app.models.schemas import AskRequest, AskResponse
from app.auth.jwt import get_current_user

router = APIRouter()


@router.post("/chat/ask", response_model=AskResponse)
async def preguntar(
    body: AskRequest,
    user_id: str = Depends(get_current_user),
):
    if not body.question.strip():
        raise HTTPException(status_code=400, detail="La pregunta no puede estar vacía.")
    return ask(body.question, user_id)
