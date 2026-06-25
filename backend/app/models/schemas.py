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


class FinScoreFactor(BaseModel):
    texto: str
    signo: str  # "+" | "-"


class FinScoreResponse(BaseModel):
    score: int
    nivel: str        # "vas bien" | "ojo" | "alerta" | "sin datos"
    resumen: str
    factores: list[FinScoreFactor]
    tasa_ahorro: float


class EditarCategoriaIn(BaseModel):
    categoria: str


class EditarCategoriaOut(BaseModel):
    actualizadas: int


class PresupuestoIn(BaseModel):
    categoria: str
    monto_tope: float


class PresupuestoEstadoOut(BaseModel):
    categoria: str
    monto_tope: float
    gastado: float
    pct: float
    estado: str  # "ok" | "cerca" | "excedido"


class PresupuestosResponse(BaseModel):
    items: list[PresupuestoEstadoOut]


class OkResponse(BaseModel):
    ok: bool


class MetaIn(BaseModel):
    nombre: str
    monto_objetivo: float
    fecha_objetivo: Optional[str] = None  # YYYY-MM-DD


class MetaPatchIn(BaseModel):
    nombre: Optional[str] = None
    monto_objetivo: Optional[float] = None
    monto_actual: Optional[float] = None
    fecha_objetivo: Optional[str] = None  # YYYY-MM-DD


class MetaOut(BaseModel):
    id: str
    nombre: str
    monto_objetivo: float
    monto_actual: float
    fecha_objetivo: Optional[str]
    progreso: float
    aporte_mensual_necesario: Optional[float]


class MetasResponse(BaseModel):
    items: list[MetaOut]


class TarjetaEstadoResponse(BaseModel):
    tiene_datos: bool
    total_a_pagar: float
    monto_minimo: float
    fecha_vencimiento: Optional[str]   # YYYY-MM-DD or null
    cupo_total: float
    cupo_utilizado: float
    comprometido_proximo_mes: float
    cuotas: list[dict]
