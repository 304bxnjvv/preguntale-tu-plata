from datetime import date
import io
import base64
import pdfplumber
from pydantic import BaseModel
from langchain_openai import ChatOpenAI
from langchain_core.messages import HumanMessage
from app.config import settings
from app.models.schemas import Transaccion
from app.services.categorias import CATEGORIAS, categorizar_por_reglas, normalizar


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
    result = _extractor().invoke(_PROMPT.format(texto=texto[:30000]))
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
