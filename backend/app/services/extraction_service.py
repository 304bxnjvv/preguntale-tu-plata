from datetime import date
import io
import re
import base64
import pdfplumber
from pydantic import BaseModel
from langchain_openai import ChatOpenAI
from langchain_core.messages import HumanMessage
from app.config import settings
from app.models.schemas import Transaccion
from app.services.categorias import CATEGORIAS, categorizar_por_reglas, normalizar

# ── RUT masking: matches formats like 12.345.678-9 or 12345678-K ─────────────
_RUT_RE = re.compile(r"\b\d{1,2}\.?\d{3}\.?\d{3}-[\dkK]\b")
# ── Long digit runs (≥10 consecutive digits) → account/card numbers ──────────
_ACCOUNT_RE = re.compile(r"\b\d{10,}\b")


def _mask_sensitive(texto: str) -> str:
    """
    Redact Chilean RUTs and long digit strings (≥10 digits) from texto
    before sending to OpenAI. Leaves monetary amounts like $45.000 intact
    because those are not matched by the patterns above.
    """
    texto = _RUT_RE.sub("[RUT]", texto)
    texto = _ACCOUNT_RE.sub("[CUENTA]", texto)
    return texto


class TxnExtraida(BaseModel):
    fecha: str  # YYYY-MM-DD
    descripcion: str
    monto: float  # negativo = gasto/cargo/compra, positivo = ingreso/abono
    banco: str | None = None
    categoria: str | None = None


class Extraccion(BaseModel):
    transacciones: list[TxnExtraida]


_CATEGORIAS_STR = ", ".join(f'"{c}"' for c in CATEGORIAS)

_PROMPT = (
    "Eres un extractor de transacciones de cartolas bancarias chilenas "
    "(cuenta corriente o tarjeta de credito).\n"
    "Del TEXTO extrae TODAS las transacciones reales. Para cada una:\n"
    "- fecha en formato YYYY-MM-DD (usa el anio del periodo de la cartola)\n"
    "- descripcion = el comercio/glosa\n"
    "- monto: NEGATIVO si es gasto/cargo/compra; POSITIVO si es ingreso/abono/deposito/sueldo\n"
    "- banco si lo identificas (ej: \"Banco de Chile\", \"Scotiabank\", \"BCI\")\n"
    "- categoria: elige EXACTAMENTE UNA de estas opciones basandote en el comercio: "
    + _CATEGORIAS_STR
    + "; si no estas seguro usa \"Otros\".\n"
    "IGNORA: pagos de la tarjeta (MONTO CANCELADO), totales, saldos, cupos, comprobantes de pago.\n"
    "\nTEXTO:\n{texto}"
)


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
    categoria = categorizar_por_reglas(t.descripcion) or normalizar(t.categoria) or "Otros"
    return Transaccion(
        fecha=fecha,
        descripcion=t.descripcion,
        monto=t.monto,
        tipo="cargo" if t.monto < 0 else "abono",
        banco=banco,
        moneda="CLP",
        categoria=categoria,
    )


def extract_from_text(texto: str) -> list[Transaccion]:
    if not texto.strip():
        return []
    texto_safe = _mask_sensitive(texto[:30000])
    result = _extractor().invoke(_PROMPT.format(texto=texto_safe))
    return [m for t in result.transacciones if (m := _map(t)) is not None]


def extract_from_pdf(content: bytes) -> list[Transaccion]:
    with pdfplumber.open(io.BytesIO(content)) as pdf:
        texto = "\n".join((p.extract_text() or "") for p in pdf.pages)
    return extract_from_text(texto)


def extract_from_csv(content: bytes) -> list[Transaccion]:
    for enc in ("utf-8", "latin-1"):
        try:
            return extract_from_text(content.decode(enc))
        except UnicodeDecodeError:
            continue
    return extract_from_text(content.decode("latin-1", errors="ignore"))


def extract_from_image(content: bytes, ext: str) -> list[Transaccion]:
    b64 = base64.b64encode(content).decode()
    mime = "image/jpeg" if ext in ("jpg", "jpeg") else f"image/{ext}"
    msg = HumanMessage(content=[
        {"type": "text", "text": _PROMPT.format(texto="(ver imagen adjunta)")},
        {"type": "image_url", "image_url": {"url": f"data:{mime};base64,{b64}"}},
    ])
    result = _extractor().invoke([msg])
    return [m for t in result.transacciones if (m := _map(t)) is not None]


def extract_from_file(content: bytes, filename: str) -> list[Transaccion]:
    ext = filename.lower().rsplit(".", 1)[-1] if "." in filename else ""
    if ext == "pdf":
        return extract_from_pdf(content)
    if ext == "csv":
        return extract_from_csv(content)
    if ext in ("jpg", "jpeg", "png", "webp"):
        return extract_from_image(content, ext)
    raise ValueError(f"Tipo de archivo no soportado: .{ext}")


# ── Boleta / receipt extraction ──────────────────────────────────────────────

class BoletaExtraida(BaseModel):
    es_boleta: bool
    comercio: str = ""
    monto: float = 0  # positivo como lo da el LLM; se fuerza negativo al devolver
    fecha: str | None = None  # YYYY-MM-DD
    categoria: str | None = None


_CATEGORIAS_LIST_STR = ", ".join(CATEGORIAS)

_PROMPT_BOLETA = (
    "Eres un extractor de BOLETAS/recibos chilenos. "
    "De la imagen extrae el TOTAL pagado (monto, positivo), el comercio, "
    "la fecha (YYYY-MM-DD) y una categoría de ["
    + _CATEGORIAS_LIST_STR
    + "]. "
    "Si no es una boleta legible, es_boleta=false."
)


def _extractor_boleta():
    return ChatOpenAI(
        model=settings.llm_model,
        api_key=settings.openai_api_key,
        temperature=0,
    ).with_structured_output(BoletaExtraida)


def extraer_boleta(content: bytes, ext: str) -> dict | None:
    """Extract receipt data from an image using vision LLM.

    Returns a dict {comercio, monto (negative = gasto), fecha, categoria}
    or None if the image is not a legible receipt.
    """
    b64 = base64.b64encode(content).decode()
    mime = "image/jpeg" if ext in ("jpg", "jpeg") else f"image/{ext}"
    msg = HumanMessage(content=[
        {"type": "text", "text": _PROMPT_BOLETA},
        {"type": "image_url", "image_url": {"url": f"data:{mime};base64,{b64}"}},
    ])
    resultado: BoletaExtraida = _extractor_boleta().invoke([msg])
    if not resultado.es_boleta:
        return None
    categoria = (
        categorizar_por_reglas(resultado.comercio)
        or normalizar(resultado.categoria)
        or "Otros"
    )
    return {
        "comercio": resultado.comercio,
        "monto": -abs(resultado.monto),
        "fecha": resultado.fecha,
        "categoria": categoria,
    }


# ── Credit-card statement extraction ─────────────────────────────────────────

class CuotaPendiente(BaseModel):
    descripcion: str
    valor_cuota: float
    cuotas_restantes: int


class EstadoTarjeta(BaseModel):
    es_tarjeta: bool
    total_a_pagar: float = 0.0
    monto_minimo: float = 0.0
    fecha_vencimiento: str | None = None  # YYYY-MM-DD
    cupo_total: float = 0.0
    cupo_utilizado: float = 0.0
    cuotas_pendientes: list[CuotaPendiente] = []


_PROMPT_TARJETA = (
    "Eres un extractor de estados de cuenta de tarjetas de crédito chilenas "
    "(Banco de Chile, Scotiabank, Falabella, BCI, Itaú, Santander, etc.).\n"
    "Analiza el siguiente TEXTO y determina si es un estado de cuenta de tarjeta de crédito.\n"
    "Si LO ES, extrae:\n"
    "- total_a_pagar: monto total a pagar / total facturado / total cobrado (número positivo)\n"
    "- monto_minimo: pago mínimo requerido (número positivo)\n"
    "- fecha_vencimiento: fecha límite de pago en formato YYYY-MM-DD (o null si no la encuentras)\n"
    "- cupo_total: cupo total de la tarjeta (número positivo)\n"
    "- cupo_utilizado: cupo utilizado o consumido (número positivo)\n"
    "- cuotas_pendientes: lista de compras en cuotas vigentes. Para cada una:\n"
    "    * descripcion: nombre del comercio o glosa\n"
    "    * valor_cuota: monto de CADA cuota mensual (no el total)\n"
    "    * cuotas_restantes: cuotas que AÚN quedan por pagar "
    "(ej: '3 de 12 cuotas' → cuotas_restantes=9, es decir 12-3)\n"
    "Si NO es un estado de cuenta de tarjeta de crédito, devuelve es_tarjeta=false.\n"
    "IGNORA transacciones normales de cartola bancaria que no sean cuotas de TC.\n"
    "\nTEXTO:\n{texto}"
)


def _extractor_tarjeta():
    return ChatOpenAI(
        model="gpt-4o-mini",
        api_key=settings.openai_api_key,
        temperature=0,
    ).with_structured_output(EstadoTarjeta)


def extraer_estado_tarjeta(content: bytes, filename: str) -> dict | None:
    """Extract credit-card statement data from a PDF.

    Returns a dict (model_dump of EstadoTarjeta) when the file is a Chilean
    credit-card statement, or None otherwise (non-PDF or not a statement).
    """
    ext = filename.lower().rsplit(".", 1)[-1] if "." in filename else ""
    if ext != "pdf":
        return None

    with pdfplumber.open(io.BytesIO(content)) as pdf:
        texto = "\n".join((p.extract_text() or "") for p in pdf.pages)

    texto_safe = _mask_sensitive(texto[:30000])
    resultado: EstadoTarjeta = _extractor_tarjeta().invoke(
        _PROMPT_TARJETA.format(texto=texto_safe)
    )
    if not resultado.es_tarjeta:
        return None
    return resultado.model_dump()
