from pydantic import BaseModel, ConfigDict, field_validator
from datetime import date, datetime
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


class TransactionOut(BaseModel):
    id: str
    fecha: date
    descripcion: str
    monto: float
    moneda: str
    tarjeta: Optional[str] = None
    tipo: str
    categoria: Optional[str] = None
    banco: str
    fuente: str

    model_config = ConfigDict(from_attributes=True)

    @field_validator("id", mode="before")
    @classmethod
    def _id_to_str(cls, v):
        # En Postgres la columna id es UUID y psycopg2 devuelve un objeto UUID;
        # en SQLite (tests) es texto. Normalizamos a str en ambos casos.
        return str(v)


class MonedaTotales(BaseModel):
    ingresos: float  # positivo
    gastos: float    # negativo (los gastos son montos < 0)


class CategoriaTotal(BaseModel):
    categoria: str
    total: float     # negativo


class BancoTotal(BaseModel):
    banco: str
    total: float     # negativo


class SummaryResponse(BaseModel):
    por_moneda: dict[str, MonedaTotales]
    gastos_por_categoria: list[CategoriaTotal]
    gastos_por_banco: list[BancoTotal]


class ChatMessageOut(BaseModel):
    id: str
    role: str
    content: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

    @field_validator("id", mode="before")
    @classmethod
    def _id_to_str(cls, v):
        return str(v)


class SuscripcionItem(BaseModel):
    descripcion: str
    monto: float
    categoria: str


class SuscripcionesResponse(BaseModel):
    total_mensual: float
    items: list[SuscripcionItem]


class TopCambio(BaseModel):
    categoria: str
    delta: float


class ComparativoResponse(BaseModel):
    mes_actual: str
    mes_anterior: str
    gastos_actual: float
    gastos_anterior: float
    delta: float
    top_cambios: list[TopCambio]


class SubscriptionOut(BaseModel):
    estado: str
    dias_restantes: int
    trial_ends_at: Optional[datetime]
    precio_clp: int = 3990


class CheckoutOut(BaseModel):
    url: str


class WebhookOut(BaseModel):
    ok: bool


class CancelOut(BaseModel):
    estado: str
