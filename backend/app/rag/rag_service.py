from langchain_openai import ChatOpenAI
from langchain_core.documents import Document
from langchain_core.prompts import ChatPromptTemplate
from app.config import settings
from app.rag.vector_store import get_vector_store
from app.models.schemas import Transaccion, AskResponse, TransaccionCitada


PROMPT = ChatPromptTemplate.from_template("""
Eres un asistente financiero personal para usuarios chilenos.
Responde en español, con montos en pesos chilenos (CLP).
Basa tu respuesta ÚNICAMENTE en las transacciones del contexto.
Si no hay información suficiente, dilo claramente.
{history_block}
Transacciones relevantes:
{context}

Pregunta: {question}

Responde de forma clara y directa. Si calculas totales, SUMA PASO A PASO mostrando el
acumulado parcial (ej: 45.000 + 12.500 = 57.500; 57.500 + 23.400 = 80.900; ...) y verifica
el resultado antes de dar el total final. No redondees ni inventes montos. Formato: $X.XXX CLP.
""")


def _llm():
    # OpenAI gpt-4o-mini (EE.UU., ofrece DPA) — antes DeepSeek (China).
    return ChatOpenAI(
        model=settings.llm_model,
        api_key=settings.openai_api_key,
        temperature=0.1,
    )


def _transaccion_to_document(t: Transaccion, user_id: str) -> Document:
    tipo_str = "gasto" if t.monto < 0 else "ingreso"
    monto_abs = abs(t.monto)
    categoria = f" Categoría: {t.categoria}." if t.categoria else ""
    content = (
        f"El {t.fecha.strftime('%d/%m/%Y')}, {tipo_str} de "
        f"${monto_abs:,.0f} CLP por '{t.descripcion}'.{categoria} Banco: {t.banco}."
    )
    return Document(
        page_content=content,
        metadata={
            "user_id": user_id,
            "fecha": str(t.fecha),
            "monto": t.monto,
            "descripcion": t.descripcion,
            "banco": t.banco,
        },
    )


def indexar_transacciones(transacciones: list[Transaccion], user_id: str) -> int:
    docs = [_transaccion_to_document(t, user_id) for t in transacciones]
    vs = get_vector_store()
    vs.add_documents(docs)
    return len(docs)


def _build_history_block(history: list[tuple[str, str]] | None) -> str:
    """Render the 'Conversación previa' block for prompt injection, or empty string."""
    if not history:
        return ""
    role_labels = {"user": "Usuario", "assistant": "Asistente"}
    lines = "\n".join(
        f"{role_labels.get(role, role)}: {content}" for role, content in history
    )
    return f"\nConversación previa:\n{lines}\n"


def ask(
    question: str,
    user_id: str,
    history: list[tuple[str, str]] | None = None,
) -> AskResponse:
    vs = get_vector_store()
    docs = vs.similarity_search(
        question, k=settings.rag_top_k, filter={"user_id": user_id}
    )

    context = "\n".join(f"- {d.page_content}" for d in docs)
    history_block = _build_history_block(history)
    chain = PROMPT | _llm()
    answer = chain.invoke(
        {"context": context, "question": question, "history_block": history_block}
    )

    citations = [
        TransaccionCitada(
            fecha=d.metadata.get("fecha", ""),
            descripcion=d.metadata.get("descripcion", ""),
            monto=d.metadata.get("monto", 0),
        )
        for d in docs
    ]
    return AskResponse(answer=answer.content, citations=citations)
