"""Integration tests for /api/v1/demo/* and /api/v1/account/data endpoints."""
import pytest
from datetime import date
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.db.models  # noqa: F401
from app.main import app
from app.db.base import Base, get_session
from app.auth.jwt import get_current_user
from app.db.models import Transaction, ChatMessage, Upload


@pytest.fixture
def client(monkeypatch):
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    TestSession = sessionmaker(bind=engine)
    _shared_session = TestSession()

    def _override_session():
        yield _shared_session

    app.dependency_overrides[get_session] = _override_session
    app.dependency_overrides[get_current_user] = lambda: "u1"
    yield TestClient(app), _shared_session
    app.dependency_overrides.clear()
    _shared_session.close()


# ── POST /demo/seed ───────────────────────────────────────────────────────────

def test_demo_seed_returns_201_with_inserted(client):
    c, session = client
    r = c.post("/api/v1/demo/seed")
    assert r.status_code == 201
    data = r.json()
    assert "inserted" in data
    assert data["inserted"] >= 18


def test_demo_seed_idempotent_via_api(client):
    c, session = client
    r1 = c.post("/api/v1/demo/seed")
    assert r1.status_code == 201
    assert r1.json()["inserted"] >= 18

    r2 = c.post("/api/v1/demo/seed")
    assert r2.status_code == 201
    assert r2.json()["inserted"] == 0


# ── DELETE /demo/seed ─────────────────────────────────────────────────────────

def test_demo_clear_returns_deleted_count(client):
    c, session = client
    c.post("/api/v1/demo/seed")
    r = c.delete("/api/v1/demo/seed")
    assert r.status_code == 200
    data = r.json()
    assert "deleted" in data
    assert data["deleted"] >= 18

    # After clear, db has zero demo rows for u1
    assert session.query(Transaction).filter_by(user_id="u1", fuente="demo").count() == 0


def test_demo_clear_empty_returns_zero(client):
    c, _ = client
    r = c.delete("/api/v1/demo/seed")
    assert r.status_code == 200
    assert r.json()["deleted"] == 0


# ── DELETE /account/data ──────────────────────────────────────────────────────

def test_account_delete_clears_all_tables(client):
    c, session = client
    # Seed demo data
    c.post("/api/v1/demo/seed")
    # Also add a chat message and upload directly
    session.add(ChatMessage(user_id="u1", role="user", content="test"))
    session.add(Upload(user_id="u1", filename="f.csv", n_transacciones=1))
    session.commit()

    r = c.delete("/api/v1/account/data")
    assert r.status_code == 200
    data = r.json()
    assert data["transactions"] >= 18
    assert data["chat"] == 1
    assert data["uploads"] == 1

    # Verify DB is empty for u1
    assert session.query(Transaction).filter_by(user_id="u1").count() == 0
    assert session.query(ChatMessage).filter_by(user_id="u1").count() == 0
    assert session.query(Upload).filter_by(user_id="u1").count() == 0


def test_account_delete_empty_returns_zeros(client):
    c, _ = client
    r = c.delete("/api/v1/account/data")
    assert r.status_code == 200
    assert r.json() == {"transactions": 0, "chat": 0, "uploads": 0}
