from fastapi import APIRouter, HTTPException
from app.rag.rag_service import ask
from app.models.schemas import AskRequest, AskResponse

router = APIRouter()


@router.post("/ask", response_model=AskResponse)
async def preguntar(body: AskRequest):
    if not body.question.strip():
        raise HTTPException(status_code=400, detail="La pregunta no puede estar vacía.")
    return ask(body.question)
