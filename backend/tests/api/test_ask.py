import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.auth.jwt import get_current_user
from app.models.schemas import AskResponse


@pytest.fixture
def client(monkeypatch):
    captured = {}

    def _fake_ask(question, user_id):
        captured["user_id"] = user_id
        captured["question"] = question
        return AskResponse(answer="ok", citations=[])

    monkeypatch.setattr("app.api.routes.ask.ask", _fake_ask)
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
    c = TestClient(app)
    r = c.post("/api/v1/chat/ask", json={"question": "hola"})
    assert r.status_code in (401, 403)
