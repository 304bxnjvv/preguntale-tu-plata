"""
chat_logger.py — Classifica mensajes de chat y extrae registros de gastos/ingresos
escritos en lenguaje natural chileno.

Chilenismos soportados (los convierte el LLM, el prompt lo instruye):
  luca  = $1.000        lucas = miles de pesos
  palo / melón = $1.000.000
  gamba = $100
  quina = $500
  medio palo = $500.000
"""
from pydantic import BaseModel
from langchain_openai import ChatOpenAI
from app.config import settings
from app.services.categorias import CATEGORIAS, categorizar_por_reglas

_CATEGORIAS_STR = ", ".join(f'"{c}"' for c in CATEGORIAS)

_PROMPT = (
    "Eres un asistente de finanzas personales chileno.\n"
    "El usuario acaba de escribir este mensaje en el chat:\n"
    "\"{mensaje}\"\n\n"
    "Decide si el mensaje es un REGISTRO de gasto o ingreso (el usuario está anotando "
    "algo que gastó, pagó, compró, recibió o le llegó) o si es una PREGUNTA/consulta.\n\n"
    "Chilenismos monetarios que debes interpretar:\n"
    "  - 'luca' o 'lucas' = miles de pesos (5 lucas = $5.000, 800 lucas = $800.000)\n"
    "  - 'palo' o 'melón' = $1.000.000\n"
    "  - 'medio palo' = $500.000\n"
    "  - 'gamba' = $100\n"
    "  - 'quina' = $500\n\n"
    "Si ES un registro, extrae:\n"
    "  - tipo: 'gasto' (gasté, pagué, compré) o 'ingreso' (me llegaron, recibí, gané)\n"
    "  - monto: el valor en pesos chilenos (número entero, sin símbolo)\n"
    "  - descripcion: dónde o en qué se gastó/recibió (corta, 1-4 palabras)\n"
    "  - categoria: elige EXACTAMENTE UNA de: " + _CATEGORIAS_STR + "\n\n"
    "Si NO es un registro (es pregunta, consulta, saludo, etc.), "
    "responde con es_registro=false y deja los demás campos vacíos."
)


class RegistroChat(BaseModel):
    es_registro: bool
    tipo: str = "gasto"          # "gasto" | "ingreso"
    monto: float = 0.0           # en pesos CLP
    descripcion: str = ""
    categoria: str = ""


def _clasificador():
    """Module-level factory so tests can monkeypatch 'app.services.chat_logger._clasificador'."""
    return ChatOpenAI(
        model=settings.llm_model,
        api_key=settings.openai_api_key,
        temperature=0,
    ).with_structured_output(RegistroChat)


def clasificar_y_extraer(mensaje: str) -> dict | None:
    """Classify *mensaje* and extract registro data if it's a spend/income log.

    Returns a dict with keys (tipo, monto, descripcion, categoria) if the
    message is a registro, or None if it's a question/other.

    The LLM interprets Chilean money slang (lucas, palo, gamba, quina, etc.).
    categorizar_por_reglas() is applied on the description as a rule-based
    fallback/override for the LLM-chosen category.
    """
    llm = _clasificador()
    prompt = _PROMPT.format(mensaje=mensaje)
    registro: RegistroChat = llm.invoke(prompt)

    if not registro.es_registro:
        return None

    # Rule-based category override/backup
    categoria = categorizar_por_reglas(registro.descripcion) or registro.categoria or "Otros"

    return {
        "tipo": registro.tipo,
        "monto": registro.monto,
        "descripcion": registro.descripcion,
        "categoria": categoria,
    }
