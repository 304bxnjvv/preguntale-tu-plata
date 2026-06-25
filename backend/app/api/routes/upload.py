from datetime import date, timedelta
from fastapi import APIRouter, UploadFile, File, HTTPException, Depends, Query
from sqlalchemy.orm import Session
from app.parsers.bci_parser import BciParser
from app.parsers.santander_parser import SantanderParser
from app.parsers.banco_estado_parser import BancoEstadoParser
from app.services.transaction_service import insert_transactions, list_transactions, get_summary
from app.rag.rag_service import indexar_transacciones
from app.models.schemas import (
    UploadResponse,
    TransactionOut,
    SummaryResponse,
    EditarCategoriaIn,
    EditarCategoriaOut,
)
from app.auth.jwt import get_current_user
from app.db.base import get_session
from app.services.extraction_service import extract_from_file, extraer_estado_tarjeta
from app.services.upload_limit import check_limit, log_upload, UploadLimitError
from app.services.demo_service import clear_demo
from app.services.tarjeta_service import guardar_estado
from app.services.categorias import CATEGORIAS, comercio_key
from app.services.categoria_override_service import upsert_override
from app.db.models import Transaction

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


@router.post("/transactions/upload", response_model=UploadResponse, status_code=201)
async def upload_universal(
    file: UploadFile = File(...),
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    try:
        check_limit(session, user_id)
    except UploadLimitError as e:
        raise HTTPException(status_code=429, detail=str(e))

    content = await file.read()
    filename = file.filename or "archivo"
    try:
        transacciones = extract_from_file(content, filename)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    nuevas = insert_transactions(session, user_id, transacciones, fuente="cartola")
    if nuevas:
        indexar_transacciones(nuevas, user_id)
        # Auto-clear demo rows now that the user has real cartola data.
        clear_demo(session, user_id)
    # El LLM ya se invocó (costo) → la subida cuenta contra el límite, haya o no transacciones.
    log_upload(session, user_id, filename, len(nuevas))

    # Try to extract credit-card statement data from PDFs (best-effort, never blocks upload).
    if filename.lower().endswith(".pdf"):
        try:
            estado_tarjeta = extraer_estado_tarjeta(content, filename)
            if estado_tarjeta is not None:
                guardar_estado(session, user_id, estado_tarjeta)
        except Exception:
            pass  # extraction failure must never break the upload response

    if not transacciones:
        raise HTTPException(
            status_code=422, detail="No detectamos transacciones en el archivo."
        )

    return UploadResponse(
        banco=transacciones[0].banco,
        transacciones_procesadas=len(nuevas),
        message=f"{len(nuevas)} transacciones nuevas ({len(transacciones) - len(nuevas)} duplicadas).",
    )


_TIPO_VALUES = {"ingreso", "gasto"}


@router.get("/transactions", response_model=list[TransactionOut])
async def listar_transacciones(
    banco: str | None = None,
    limit: int = Query(default=100, ge=1, le=1000),
    offset: int = Query(default=0, ge=0),
    dias: int | None = Query(default=None, ge=1, le=366),
    tipo: str | None = Query(default=None),
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    if tipo is not None and tipo not in _TIPO_VALUES:
        raise HTTPException(status_code=422, detail=f"tipo debe ser 'ingreso' o 'gasto', no '{tipo}'")
    desde: date | None = date.today() - timedelta(days=dias) if dias is not None else None
    return list_transactions(session, user_id, banco=banco, limit=limit, offset=offset, desde=desde, tipo=tipo)


@router.patch("/transactions/{txn_id}", response_model=EditarCategoriaOut)
async def editar_categoria(
    txn_id: str,
    body: EditarCategoriaIn,
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    if body.categoria not in CATEGORIAS:
        raise HTTPException(status_code=422, detail="categoría inválida")
    txn = session.query(Transaction).filter_by(id=txn_id, user_id=user_id).first()
    if txn is None:
        raise HTTPException(status_code=404, detail="transacción no encontrada")
    txn.categoria = body.categoria
    txn.categoria_manual = True
    key = comercio_key(txn.descripcion)
    if key:
        upsert_override(session, user_id, key, body.categoria)
    actualizadas = 1
    if key:
        otras = (
            session.query(Transaction)
            .filter(
                Transaction.user_id == user_id,
                Transaction.id != txn_id,
                Transaction.categoria_manual.is_(False),
            )
            .all()
        )
        for o in otras:
            if key in comercio_key(o.descripcion):
                o.categoria = body.categoria
                actualizadas += 1
    session.commit()
    return EditarCategoriaOut(actualizadas=actualizadas)


@router.get("/transactions/summary", response_model=SummaryResponse)
async def resumen(
    dias: int | None = Query(default=None, ge=1, le=366),
    tipo: str | None = Query(default=None),
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    if tipo is not None and tipo not in _TIPO_VALUES:
        raise HTTPException(status_code=422, detail=f"tipo debe ser 'ingreso' o 'gasto', no '{tipo}'")
    desde: date | None = date.today() - timedelta(days=dias) if dias is not None else None
    return get_summary(session, user_id, desde=desde, tipo=tipo)
