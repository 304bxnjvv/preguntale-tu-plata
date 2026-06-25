"""
Tests for chat history persistence + bounded conversational memory.
Covers: repo layer, rag_service memory injection, API endpoints.
"""
import pytest
from datetime import datetime, timezone, timedelta
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
import app.db.models  # noqa: F401  (registers ChatMessage in Base.metadata)
from app.main import app
from app.db.base import Base, get_session
from app.auth.jwt import get_current_user
from app.db.chat_repo import save_message, get_history, get_recent_for_memory
from app.db.models import ChatMessage
from app.models.schemas import AskResponse


def _save_with_ts(session, user_id, role, content, offset_seconds=0):
    """Helper: save a ChatMessage with an explicit timestamp to avoid SQLite ties."""
    ts = datetime(2025, 1, 1, tzinfo=timezone.utc) + timedelta(seconds=offset_seconds)
    msg = ChatMessage(user_id=user_id, role=role, content=content, created_at=ts)
    session.add(msg)
    session.commit()
    session.refresh(msg)
    return msg


# ---------------------------------------------------------------------------
# Shared in-memory session fixture
# ---------------------------------------------------------------------------

@pytest.fixture
def session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    s = sessionmaker(bind=engine)()
    yield s
    s.close()


# ---------------------------------------------------------------------------
# Repo tests
# ---------------------------------------------------------------------------

class TestSaveAndGetHistory:
    def test_save_then_get_history_returns_ascending(self, session):
        save_message(session, "u1", "user", "hola")
        save_message(session, "u1", "assistant", "hola, soy tu plata")
        save_message(session, "u1", "user", "cuanto gaste?")

        rows = get_history(session, "u1")
        assert len(rows) == 3
        assert rows[0].role == "user"
        assert rows[0].content == "hola"
        assert rows[1].role == "assistant"
        assert rows[2].content == "cuanto gaste?"

    def test_get_history_isolates_by_user(self, session):
        save_message(session, "u1", "user", "soy u1")
        save_message(session, "u2", "user", "soy u2")

        rows_u1 = get_history(session, "u1")
        rows_u2 = get_history(session, "u2")
        assert len(rows_u1) == 1
        assert len(rows_u2) == 1
        assert rows_u1[0].content == "soy u1"
        assert rows_u2[0].content == "soy u2"

    def test_get_history_empty_for_new_user(self, session):
        assert get_history(session, "ghost") == []


class TestGetRecentForMemory:
    def test_caps_at_limit_and_returns_ascending(self, session):
        # Insert 10 messages with distinct timestamps
        for i in range(10):
            role = "user" if i % 2 == 0 else "assistant"
            _save_with_ts(session, "u1", role, f"msg {i}", offset_seconds=i)

        rows = get_recent_for_memory(session, "u1", limit=6)
        assert len(rows) == 6

        # Must be ascending: each created_at <= next
        for a, b in zip(rows, rows[1:]):
            assert a.created_at <= b.created_at

    def test_returns_tail_messages(self, session):
        for i in range(8):
            _save_with_ts(session, "u1", "user", f"msg {i}", offset_seconds=i)

        rows = get_recent_for_memory(session, "u1", limit=3)
        # The last 3 inserted messages (msg 5, 6, 7) should be returned
        contents = [r.content for r in rows]
        assert "msg 7" in contents
        assert "msg 6" in contents
        assert "msg 5" in contents
        assert "msg 0" not in contents

    def test_fewer_than_limit_returns_all_ascending(self, session):
        _save_with_ts(session, "u1", "user", "a", offset_seconds=0)
        _save_with_ts(session, "u1", "assistant", "b", offset_seconds=1)

        rows = get_recent_for_memory(session, "u1", limit=6)
        assert len(rows) == 2
        assert rows[0].content == "a"
        assert rows[1].content == "b"

    def test_empty_for_new_user(self, session):
        assert get_recent_for_memory(session, "nobody", limit=6) == []


# ---------------------------------------------------------------------------
# RAG service: memory injection
# ---------------------------------------------------------------------------

class TestRagMemoryInjection:
    def test_history_included_in_prompt(self):
        """Verifies 'Conversación previa' block appears in the prompt when history is supplied."""
        from app.rag.rag_service import ask as rag_ask

        captured_input = {}

        fake_response = MagicMock()
        fake_response.content = "respuesta del asistente"

        def fake_invoke(inputs):
            captured_input.update(inputs)
            return fake_response

        fake_chain = MagicMock()
        fake_chain.invoke = fake_invoke

        fake_docs = []

        with patch("app.rag.rag_service.get_vector_store") as mock_vs, \
             patch("app.rag.rag_service._llm") as mock_llm, \
             patch("app.rag.rag_service.PROMPT") as mock_prompt:

            mock_vs.return_value.similarity_search.return_value = fake_docs
            mock_prompt.__or__ = lambda self, other: fake_chain  # PROMPT | _llm() → fake_chain

            result = rag_ask(
                "cuanto gaste?",
                "u1",
                history=[("user", "hola"), ("assistant", "hola, soy tu plata")],
            )

        history_block = captured_input.get("history_block", "")
        assert "Conversación previa" in history_block
        assert "Usuario: hola" in history_block
        assert "Asistente: hola, soy tu plata" in history_block

    def test_no_history_gives_empty_block(self):
        """Default call (history=None) produces an empty history_block (no regression)."""
        from app.rag.rag_service import _build_history_block
        assert _build_history_block(None) == ""
        assert _build_history_block([]) == ""

    def test_history_labels_mapped_correctly(self):
        from app.rag.rag_service import _build_history_block
        block = _build_history_block([("user", "pregunta"), ("assistant", "respuesta")])
        assert "Usuario: pregunta" in block
        assert "Asistente: respuesta" in block
        assert "Conversación previa" in block


# ---------------------------------------------------------------------------
# API tests
# ---------------------------------------------------------------------------

@pytest.fixture
def api_client(monkeypatch):
    """Test client with SQLite DB, auth override, and LLM mocked out."""
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    TestSession = sessionmaker(bind=engine)

    def _override_session():
        s = TestSession()
        try:
            yield s
        finally:
            s.close()

    def _fake_ask(question, user_id, history=None):
        return AskResponse(answer="respuesta-mock", citations=[])

    monkeypatch.setattr("app.api.routes.ask.ask", _fake_ask)

    app.dependency_overrides[get_session] = _override_session
    app.dependency_overrides[get_current_user] = lambda: "u1"
    yield TestClient(app)
    app.dependency_overrides.clear()


class TestChatAskEndpoint:
    def test_post_ask_persists_two_rows(self, api_client):
        r = api_client.post("/api/v1/chat/ask", json={"question": "cuanto gaste?"})
        assert r.status_code == 200
        assert r.json()["answer"] == "respuesta-mock"

        # Verify via GET /history that exactly 2 rows were saved
        hist = api_client.get("/api/v1/chat/history")
        assert hist.status_code == 200
        rows = hist.json()
        assert len(rows) == 2
        assert rows[0]["role"] == "user"
        assert rows[0]["content"] == "cuanto gaste?"
        assert rows[1]["role"] == "assistant"
        assert rows[1]["content"] == "respuesta-mock"

    def test_history_returned_ascending(self, api_client):
        api_client.post("/api/v1/chat/ask", json={"question": "primera"})
        api_client.post("/api/v1/chat/ask", json={"question": "segunda"})

        hist = api_client.get("/api/v1/chat/history")
        rows = hist.json()
        assert len(rows) == 4  # 2 asks × 2 messages each
        assert rows[0]["content"] == "primera"
        assert rows[2]["content"] == "segunda"

    def test_get_history_requires_auth(self):
        app.dependency_overrides.clear()
        c = TestClient(app)
        r = c.get("/api/v1/chat/history")
        assert r.status_code in (401, 403)

    def test_empty_question_returns_400(self, api_client):
        r = api_client.post("/api/v1/chat/ask", json={"question": "   "})
        assert r.status_code == 400

    def test_history_isolated_per_user(self, monkeypatch):
        """Two different user overrides should not see each other's messages."""
        engine = create_engine(
            "sqlite:///:memory:",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        Base.metadata.create_all(engine)
        TestSession = sessionmaker(bind=engine)

        def _override_session():
            s = TestSession()
            try:
                yield s
            finally:
                s.close()

        def _fake_ask(question, user_id, history=None):
            return AskResponse(answer="ok", citations=[])

        monkeypatch.setattr("app.api.routes.ask.ask", _fake_ask)
        app.dependency_overrides[get_session] = _override_session

        # User A
        app.dependency_overrides[get_current_user] = lambda: "userA"
        ca = TestClient(app)
        ca.post("/api/v1/chat/ask", json={"question": "pregunta A"})

        # User B
        app.dependency_overrides[get_current_user] = lambda: "userB"
        cb = TestClient(app)
        cb.post("/api/v1/chat/ask", json={"question": "pregunta B"})
        hist_b = cb.get("/api/v1/chat/history").json()
        assert all(r["content"] != "pregunta A" for r in hist_b)

        app.dependency_overrides.clear()
