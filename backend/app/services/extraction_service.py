from datetime import date
from pydantic import BaseModel
from langchain_openai import ChatOpenAI
from app.config import settings
from app.models.schemas import Transaccion


class TxnExtraida(BaseModel):
    fecha: str  # YYYY-MM-DD
    descripcion: str
    monto: float  # negativo = gasto/cargo/compra, positivo = ingreso/abono
    banco: str | None = None


class Extraccion(BaseModel):
    transacciones: list[TxnExtraida]


_PROMPT = """Eres un extractor de transacciones de cartolas bancarias chilenas \
(cuenta corriente o tarjeta de credito).
Del TEXTO extrae TODAS las transacciones reales. Para cada una:
- fecha en formato YYYY-MM-DD (usa el anio del periodo de la cartola)
- descripcion = el comercio/glosa
- monto: NEGATIVO si es gasto/cargo/compra; POSITIVO si es ingreso/abono/deposito/sueldo
- banco si lo identificas (ej: "Banco de Chile", "Scotiabank", "BCI")
IGNORA: pagos de la tarjeta (MONTO CANCELADO), totales, saldos, cupos, comprobantes de pago.

TEXTO:
{texto}"""


def _extractor():
    return ChatOpenAI(
        model=settings.llm_model,
        api_key=settings.openai_api_key,
        temperature=0,
    ).with_structured_output(Extraccion)


def _map(t: TxnExtraida) -> Transaccion | None:
    try:
        fecha = date.fromisoformat(t.fecha)
    except (ValueError, TypeError):
        return None
    banco = (t.banco or "desconocido").strip().lower().replace(" ", "") or "desconocido"
    return Transaccion(
        fecha=fecha,
        descripcion=t.descripcion,
        monto=t.monto,
        tipo="cargo" if t.monto < 0 else "abono",
        banco=banco,
        moneda="CLP",
    )


def extract_from_text(texto: str) -> list[Transaccion]:
    if not texto.strip():
        return []
    result = _extractor().invoke(_PROMPT.format(texto=texto[:30000]))
    return [m for t in result.transacciones if (m := _map(t)) is not None]
