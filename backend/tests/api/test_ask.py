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


@pytest.fixture
def client(monkeypatch):
    captured = {}

    def _fake_ask(question, user_id, history=None):
        captured["user_id"] = user_id
        captured["question"] = question
        captured["history"] = history
        return AskResponse(answer="ok", citations=[])

    monkeypatch.setattr("app.api.routes.ask.ask", _fake_ask)

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

    app.dependency_overrides[get_session] = _override_session
    app.dependency_overrides[get_current_user] = lambda: "u1"
    yield TestClient(app), captured
    app.dependency_overrides.clear()


def test_ask_passes_user_id(client):
    c, captured = client
    r = c.post("/api/v1/chat/ask", json={"question": "cuanto gaste?"})
    assert r.status_code == 200
    assert captured["user_id"] == "u1"        # el filtro por usuario llega al servicio
    assert captured["question"] == "cuanto gaste?"


def test_ask_requires_auth():
    app.dependency_overrides.clear()
    c = TestClient(app)
    r = c.post("/api/v1/chat/ask", json={"question": "hola"})
    assert r.status_code in (401, 403)
