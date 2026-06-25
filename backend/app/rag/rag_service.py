from langchain_openai import ChatOpenAI
from langchain_core.documents import Document
from langchain_core.prompts import ChatPromptTemplate
from sqlalchemy.orm import Session
from app.config import settings
from app.rag.vector_store import get_vector_store
from app.models.schemas import Transaccion, AskResponse, TransaccionCitada


PROMPT = ChatPromptTemplate.from_template("""
eres el asistente de finanzas personales de confianza del usuario — chileno, cálido, directo y sin juicio.
habla en minúscula relajada, usa "plata" en vez de "dinero", tutea al usuario y ve al grano.
sé proactivo: si ves algo relevante en los datos (una suscripción cara, un mes peor que el anterior), menciónalo sin que te lo pidan.
cuando cites montos, usa los números reales del contexto — nunca inventes ni redondees.
si no hay datos suficientes, dilo sin rodeos.
{history_block}
Resumen del usuario:
{resumen_block}

Transacciones relevantes:
{context}

Pregunta: {question}

si calculas totales, SUMA PASO A PASO mostrando el acumulado parcial
(ej: 45.000 + 12.500 = 57.500; 57.500 + 23.400 = 80.900; ...) y verifica el resultado antes de dar el total final.
no redondees ni inventes montos. formato: $X.XXX CLP.
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
    """Render the 'Conversación previa' block for prompt injection, or empty string.

    When *history* is empty/None, returns ``""`` so the ``{history_block}``
    placeholder in the prompt template produces no extra blank line.
    When non-empty, the returned string starts with a leading newline (to
    separate from the preceding paragraph) but has NO trailing newline — the
    template's own line-break after ``{history_block}`` acts as the separator
    to the next section, keeping the prompt clean in both cases.
    """
    if not history:
        return ""
    role_labels = {"user": "Usuario", "assistant": "Asistente"}
    lines = "\n".join(
        f"{role_labels.get(role, role)}: {content}" for role, content in history
    )
    return f"\nConversación previa:\n{lines}"


def _build_resumen_block(session: Session | None, user_id: str) -> str:
    """Build the 'Resumen del usuario' block with insights data.

    Returns an empty string when no session is provided (e.g. unit tests that
    stub the LLM without a DB).
    """
    if session is None:
        return ""
    try:
        from app.services.insights_service import (
            comparativo_mensual,
            detectar_suscripciones,
        )
        comp = comparativo_mensual(session, user_id)
        sus = detectar_suscripciones(session, user_id)

        lines = [
            f"- Mes actual ({comp['mes_actual']}): gastos ${comp['gastos_actual']:,.0f} CLP",
            f"- Mes anterior ({comp['mes_anterior']}): gastos ${comp['gastos_anterior']:,.0f} CLP",
            f"- Delta: {'+' if comp['delta'] >= 0 else ''}{comp['delta']:,.0f} CLP",
        ]
        if comp["top_cambios"]:
            cambios_str = ", ".join(
                f"{c['categoria']} {'+' if c['delta'] >= 0 else ''}{c['delta']:,.0f}"
                for c in comp["top_cambios"]
            )
            lines.append(f"- Top cambios por categoría: {cambios_str}")
        if sus["items"]:
            sus_str = ", ".join(
                f"{i['descripcion']} ${i['monto']:,.0f}" for i in sus["items"]
            )
            lines.append(
                f"- Suscripciones detectadas (total ~${sus['total_mensual']:,.0f}/mes): {sus_str}"
            )
        else:
            lines.append("- Sin suscripciones detectadas este mes.")

        # Inject credit-card state if available
        try:
            from app.services.tarjeta_service import get_estado as _get_tarjeta
            tc = _get_tarjeta(session, user_id)
            if tc["tiene_datos"]:
                fv = tc["fecha_vencimiento"] or "sin fecha"
                lines.append(
                    f"- Tarjeta de crédito: total a pagar ${tc['total_a_pagar']:,.0f} CLP"
                    f", vence {fv}"
                    f", comprometido próximo mes ${tc['comprometido_proximo_mes']:,.0f} CLP"
                )
        except Exception:
            pass

        return "\n".join(lines)
    except Exception:
        return ""


def ask(
    question: str,
    user_id: str,
    history: list[tuple[str, str]] | None = None,
    session: Session | None = None,
) -> AskResponse:
    vs = get_vector_store()
    docs = vs.similarity_search(
        question, k=settings.rag_top_k, filter={"user_id": user_id}
    )

    context = "\n".join(f"- {d.page_content}" for d in docs)
    history_block = _build_history_block(history)
    resumen_block = _build_resumen_block(session, user_id)
    chain = PROMPT | _llm()
    answer = chain.invoke(
        {
            "context": context,
            "question": question,
            "history_block": history_block,
            "resumen_block": resumen_block,
        }
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
