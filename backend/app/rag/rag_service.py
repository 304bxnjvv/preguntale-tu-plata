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

Transacciones relevantes:
{context}

Pregunta: {question}

Responde de forma clara y directa. Si calculas totales, muéstralos en formato $X.XXX CLP.
""")


def _llm():
    return ChatOpenAI(
        model=settings.deepseek_model,
        base_url="https://api.deepseek.com/v1",
        api_key=settings.deepseek_api_key,
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


def ask(question: str) -> AskResponse:
    vs = get_vector_store()
    docs = vs.similarity_search(question, k=settings.rag_top_k)

    context = "\n".join(f"- {d.page_content}" for d in docs)
    chain = PROMPT | _llm()
    answer = chain.invoke({"context": context, "question": question})

    citations = [
        TransaccionCitada(
            fecha=d.metadata.get("fecha", ""),
            descripcion=d.metadata.get("descripcion", ""),
            monto=d.metadata.get("monto", 0),
        )
        for d in docs
    ]

    return AskResponse(answer=answer.content, citations=citations)
