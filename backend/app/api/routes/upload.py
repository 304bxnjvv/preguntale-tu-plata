from fastapi import APIRouter, UploadFile, File, HTTPException, Depends, Query
from sqlalchemy.orm import Session
from app.parsers.bci_parser import BciParser
from app.parsers.santander_parser import SantanderParser
from app.parsers.banco_estado_parser import BancoEstadoParser
from app.services.transaction_service import insert_transactions, list_transactions, get_summary
from app.rag.rag_service import indexar_transacciones
from app.models.schemas import UploadResponse, TransactionOut, SummaryResponse
from app.auth.jwt import get_current_user
from app.db.base import get_session

router = APIRouter()

PARSERS = {
    "bci": BciParser(),
    "santander": SantanderParser(),
    "bancoestado": BancoEstadoParser(),
}


@router.post("/transactions/upload-csv", response_model=UploadResponse, status_code=201)
async def upload_csv(
    file: UploadFile = File(...),
    banco: str = "bci",
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    banco = banco.lower().replace(" ", "")
    if banco not in PARSERS:
        raise HTTPException(
            status_code=400,
            detail=f"Banco '{banco}' no soportado. Opciones: {list(PARSERS.keys())}",
        )
    if not (file.filename or "").endswith(".csv"):
        raise HTTPException(status_code=400, detail="Solo se aceptan archivos CSV.")

    content = await file.read()
    transacciones = PARSERS[banco].parse(content)
    if not transacciones:
        raise HTTPException(
            status_code=422, detail="No se pudieron parsear transacciones del archivo."
        )

    nuevas = insert_transactions(session, user_id, transacciones, fuente="cartola")
    if nuevas:
        indexar_transacciones(nuevas, user_id)

    return UploadResponse(
        banco=banco,
        transacciones_procesadas=len(nuevas),
        message=f"{len(nuevas)} transacciones nuevas indexadas ({len(transacciones) - len(nuevas)} duplicadas omitidas).",
    )


@router.get("/transactions", response_model=list[TransactionOut])
async def listar_transacciones(
    banco: str | None = None,
    limit: int = Query(default=100, ge=1, le=1000),
    offset: int = Query(default=0, ge=0),
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    return list_transactions(session, user_id, banco=banco, limit=limit, offset=offset)


@router.get("/transactions/summary", response_model=SummaryResponse)
async def resumen(
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    return get_summary(session, user_id)
