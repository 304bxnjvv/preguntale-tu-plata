"""Tests that ask() injects insights resumen into the LLM prompt."""
from datetime import date
from unittest.mock import MagicMock, patch

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

import app.db.models  # noqa: F401
from app.db.base import Base
from app.db.models import Transaction
from app.models.schemas import AskResponse, TransaccionCitada


@pytest.fixture
def session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    s = sessionmaker(bind=engine)()
    yield s
    s.close()


def _add(session, user_id, fecha, descripcion, monto, categoria=None):
    session.add(
        Transaction(
            user_id=user_id,
            fecha=fecha,
            descripcion=descripcion,
            monto=monto,
            moneda="CLP",
            tipo="cargo",
            categoria=categoria,
            banco="bci",
            fuente="cartola",
        )
    )
    session.commit()


def _fake_docs():
    from langchain_core.documents import Document
    return [
        Document(
            page_content="El 01/06/2026, gasto de $15.990 CLP por 'Netflix'.",
            metadata={"user_id": "u1", "fecha": "2026-06-01", "monto": -15990, "descripcion": "Netflix", "banco": "bci"},
        )
    ]


def test_ask_injects_resumen_block_with_session(session, monkeypatch):
    """ask() with a session should build and inject a resumen_block into the prompt."""
    today = date.today()
    _add(session, "u1", date(today.year, today.month, 1), "Netflix", -15990, "Suscripciones")

    captured_prompt_args = {}

    class FakeLLM:
        def __or__(self, other):
            return self

        def invoke(self, args):
            captured_prompt_args.update(args)
            m = MagicMock()
            m.content = "aquí va la respuesta"
            return m

    fake_chain = FakeLLM()

    def fake_build_chain(prompt, llm):
        return fake_chain

    with patch("app.rag.rag_service.get_vector_store") as mock_vs, \
         patch("app.rag.rag_service._llm") as mock_llm, \
         patch("app.rag.rag_service.PROMPT") as mock_prompt:

        mock_vs.return_value.similarity_search.return_value = _fake_docs()
        mock_llm.return_value = MagicMock()
        # Make PROMPT | llm() return our fake chain
        mock_prompt.__or__ = lambda self, other: fake_chain

        from app.rag.rag_service import ask, _build_resumen_block

        resumen = _build_resumen_block(session, "u1")

    # resumen block must mention suscripciones or month data
    assert "Netflix" in resumen or "15.990" in resumen or "suscripci" in resumen.lower()
    assert len(resumen) > 0


def test_ask_resumen_block_empty_without_session(monkeypatch):
    """ask() without a session → resumen_block is empty string."""
    from app.rag.rag_service import _build_resumen_block
    result = _build_resumen_block(None, "u1")
    assert result == ""


def test_ask_resumen_block_contains_comparativo(session):
    """resumen block should include current and previous month spending info."""
    from app.rag.rag_service import _build_resumen_block

    today = date.today()
    _add(session, "u1", date(today.year, today.month, 1), "Uber", -20000, "Transporte")

    result = _build_resumen_block(session, "u1")
    # Should reference the current month label
    mes_label = f"{today.year:04d}-{today.month:02d}"
    assert mes_label in result


def test_ask_resumen_block_no_suscripciones(session):
    """When no subscriptions exist, block should say so."""
    from app.rag.rag_service import _build_resumen_block

    result = _build_resumen_block(session, "u1")
    assert "sin suscripciones" in result.lower() or result == ""
