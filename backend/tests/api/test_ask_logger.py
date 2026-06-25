"""Integration tests for POST /chat/ask — chat-logger branch (TDD RED phase).

Tests:
1. Gasto message → Transaction inserted (monto=-5000, fuente="manual") + warm confirmation with "5.000"
2. Ingreso message → Transaction inserted with monto=+800000
3. Question → RAG path (ask() called, no insert)
4. Existing test client fixture must NOT break (classifier mocked to None for pre-existing tests).
"""
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.db.models  # noqa: F401
from app.main import app
from app.db.base import Base, get_session
from app.auth.jwt import get_current_user
from app.models.schemas import AskResponse
from app.db.models import Transaction


# ── shared helpers ────────────────────────────────────────────────────────────

def _make_engine():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    return engine


def _override_session(engine):
    TestSession = sessionmaker(bind=engine)

    def _dep():
        s = TestSession()
        try:
            yield s
        finally:
            s.close()

    return _dep


# ── tests ─────────────────────────────────────────────────────────────────────

def test_chat_gasto_inserts_transaction_and_confirms(monkeypatch):
    """'gasté 5 lucas en almuerzo' → monto=-5000 inserted, response contains '5.000'."""
    engine = _make_engine()

    # Fake classifier: returns gasto 5000
    monkeypatch.setattr(
        "app.api.routes.ask.clasificar_y_extraer",
        lambda msg: {
            "tipo": "gasto",
            "monto": 5000.0,
            "descripcion": "almuerzo",
            "categoria": "Comida y delivery",
        },
    )
    # Mock indexar_transacciones so no vector store is needed
    monkeypatch.setattr("app.api.routes.ask.indexar_transacciones", lambda txns, uid: None)

    app.dependency_overrides[get_session] = _override_session(engine)
    app.dependency_overrides[get_current_user] = lambda: "u1"

    try:
        client = TestClient(app)
        r = client.post("/api/v1/chat/ask", json={"question": "gasté 5 lucas en almuerzo"})
        assert r.status_code == 200
        data = r.json()
        # Warm confirmation must mention the amount
        assert "5.000" in data["answer"]
        # Transaction must be in the DB
        s = sessionmaker(bind=engine)()
        rows = s.query(Transaction).filter(Transaction.user_id == "u1").all()
        assert len(rows) == 1
        assert rows[0].monto == -5000.0
        assert rows[0].fuente == "manual"
        assert rows[0].banco == "manual"
        s.close()
    finally:
        app.dependency_overrides.clear()


def test_chat_ingreso_inserts_positive_monto(monkeypatch):
    """'me llegaron 800 lucas de sueldo' → monto=+800000 inserted."""
    engine = _make_engine()

    monkeypatch.setattr(
        "app.api.routes.ask.clasificar_y_extraer",
        lambda msg: {
            "tipo": "ingreso",
            "monto": 800000.0,
            "descripcion": "sueldo",
            "categoria": "Otros",
        },
    )
    monkeypatch.setattr("app.api.routes.ask.indexar_transacciones", lambda txns, uid: None)

    app.dependency_overrides[get_session] = _override_session(engine)
    app.dependency_overrides[get_current_user] = lambda: "u1"

    try:
        client = TestClient(app)
        r = client.post("/api/v1/chat/ask", json={"question": "me llegaron 800 lucas de sueldo"})
        assert r.status_code == 200
        s = sessionmaker(bind=engine)()
        rows = s.query(Transaction).filter(Transaction.user_id == "u1").all()
        assert len(rows) == 1
        assert rows[0].monto == 800000.0
        assert rows[0].fuente == "manual"
        s.close()
    finally:
        app.dependency_overrides.clear()


def test_chat_pregunta_goes_to_rag(monkeypatch):
    """'¿cuánto gasté este mes?' → classifier returns None → RAG ask() is called, no insert."""
    engine = _make_engine()
    captured = {}

    monkeypatch.setattr(
        "app.api.routes.ask.clasificar_y_extraer",
        lambda msg: None,  # not a registro
    )

    def _fake_ask(question, user_id, history=None, session=None):
        captured["called"] = True
        captured["question"] = question
        return AskResponse(answer="gastaste mucho", citations=[])

    monkeypatch.setattr("app.api.routes.ask.ask", _fake_ask)

    app.dependency_overrides[get_session] = _override_session(engine)
    app.dependency_overrides[get_current_user] = lambda: "u1"

    try:
        client = TestClient(app)
        r = client.post("/api/v1/chat/ask", json={"question": "¿cuánto gasté este mes?"})
        assert r.status_code == 200
        assert captured.get("called") is True
        # No transaction inserted
        s = sessionmaker(bind=engine)()
        rows = s.query(Transaction).filter(Transaction.user_id == "u1").all()
        assert len(rows) == 0
        s.close()
    finally:
        app.dependency_overrides.clear()


def test_existing_ask_behavior_unchanged(monkeypatch):
    """Original ask behavior still works when classifier returns None (regression guard)."""
    engine = _make_engine()
    captured = {}

    monkeypatch.setattr(
        "app.api.routes.ask.clasificar_y_extraer",
        lambda msg: None,
    )

    def _fake_ask(question, user_id, history=None, session=None):
        captured["user_id"] = user_id
        captured["question"] = question
        return AskResponse(answer="ok", citations=[])

    monkeypatch.setattr("app.api.routes.ask.ask", _fake_ask)

    app.dependency_overrides[get_session] = _override_session(engine)
    app.dependency_overrides[get_current_user] = lambda: "u1"

    try:
        client = TestClient(app)
        r = client.post("/api/v1/chat/ask", json={"question": "cuanto gaste?"})
        assert r.status_code == 200
        assert captured["user_id"] == "u1"
        assert captured["question"] == "cuanto gaste?"
    finally:
        app.dependency_overrides.clear()
