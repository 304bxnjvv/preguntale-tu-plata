from pydantic import BaseModel
from datetime import date
from typing import Optional


class Transaccion(BaseModel):
    fecha: date
    descripcion: str
    monto: float          # negativo = gasto, positivo = ingreso
    tipo: str             # "cargo" | "abono"
    categoria: Optional[str] = None
    banco: str
    moneda: str = "CLP"
    tarjeta: Optional[str] = None


class AskRequest(BaseModel):
    question: str


class TransaccionCitada(BaseModel):
    fecha: str
    descripcion: str
    monto: float


class AskResponse(BaseModel):
    answer: str
    citations: list[TransaccionCitada]


class UploadResponse(BaseModel):
    banco: str
    transacciones_procesadas: int
    message: str
