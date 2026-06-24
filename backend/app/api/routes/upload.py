from fastapi import APIRouter, UploadFile, File, HTTPException
from app.parsers.bci_parser import BciParser
from app.parsers.santander_parser import SantanderParser
from app.parsers.banco_estado_parser import BancoEstadoParser
from app.rag.rag_service import indexar_transacciones
from app.models.schemas import UploadResponse

router = APIRouter()

PARSERS = {
    "bci": BciParser(),
    "santander": SantanderParser(),
    "bancoestado": BancoEstadoParser(),
}


@router.post("/upload", response_model=UploadResponse, status_code=201)
async def upload_csv(
    file: UploadFile = File(...),
    banco: str = "bci",
):
    banco = banco.lower().replace(" ", "")
    if banco not in PARSERS:
        raise HTTPException(
            status_code=400,
            detail=f"Banco '{banco}' no soportado. Opciones: {list(PARSERS.keys())}",
        )
    if not file.filename.endswith(".csv"):
        raise HTTPException(status_code=400, detail="Solo se aceptan archivos CSV.")

    content = await file.read()
    transacciones = PARSERS[banco].parse(content)

    if not transacciones:
        raise HTTPException(status_code=422, detail="No se pudieron parsear transacciones del archivo.")

    indexadas = indexar_transacciones(transacciones)

    return UploadResponse(
        banco=banco,
        transacciones_procesadas=indexadas,
        message=f"{indexadas} transacciones indexadas correctamente.",
    )
