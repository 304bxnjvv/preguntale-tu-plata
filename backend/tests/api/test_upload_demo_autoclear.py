"""
Test that uploading real cartola data auto-clears demo rows.
"""
import io
from datetime import date

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.db.models  # noqa: F401
import app.api.routes.upload as upload_mod
from app.main import app
from app.db.base import Base, get_session
from app.auth.jwt import get_current_user
from app.db.models import Transaction
from app.models.schemas import Transaccion
from app.services.demo_service import seed_demo


@pytest.fixture
def client_with_session(monkeypatch):
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    TestSession = sessionmaker(bind=engine)
    shared_session = TestSession()

    def _override_session():
        yield shared_session

    monkeypatch.setattr(upload_mod, "extract_from_file", lambda c, f: [
        Transaccion(fecha=date(2025, 6, 1), descripcion="LIDER", monto=-45000,
                    tipo="cargo", banco="bci"),
        Transaccion(fecha=date(2025, 6, 10), descripcion="SUELDO", monto=2500000,
                    tipo="abono", banco="bci"),
    ])
    monkeypatch.setattr(upload_mod, "indexar_transacciones", lambda txns, uid: len(txns))

    app.dependency_overrides[get_session] = _override_session
    app.dependency_overrides[get_current_user] = lambda: "u1"
    yield TestClient(app), shared_session
    app.dependency_overrides.clear()
    shared_session.close()


def _file():
    return {"file": ("cartola.pdf", io.BytesIO(b"%PDF-fake"), "application/pdf")}


def test_demo_rows_cleared_after_real_upload(client_with_session):
    c, session = client_with_session

    # Seed demo rows first
    seed_demo(session, "u1")
    demo_count = session.query(Transaction).filter_by(user_id="u1", fuente="demo").count()
    assert demo_count >= 18, "Demo rows should be present before upload"

    # Upload real cartola
    r = c.post("/api/v1/transactions/upload", files=_file())
    assert r.status_code == 201

    # Demo rows must be gone
    remaining_demo = session.query(Transaction).filter_by(user_id="u1", fuente="demo").count()
    assert remaining_demo == 0, f"Expected 0 demo rows after real upload, got {remaining_demo}"

    # Real cartola rows remain
    cartola_count = session.query(Transaction).filter_by(user_id="u1", fuente="cartola").count()
    assert cartola_count >= 1
