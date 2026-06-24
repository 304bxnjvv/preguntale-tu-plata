import io
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from datetime import date
import app.db.models  # noqa: F401
import app.api.routes.upload as upload_mod
from app.main import app
from app.db.base import Base, get_session
from app.auth.jwt import get_current_user
from app.models.schemas import Transaccion


@pytest.fixture
def client(monkeypatch):
    engine = create_engine(
        "sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    Base.metadata.create_all(engine)
    TestSession = sessionmaker(bind=engine)

    def _override_session():
        s = TestSession()
        try:
            yield s
        finally:
            s.close()

    # extracción mockeada: 2 transacciones fijas, sin tocar OpenAI ni pgvector
    monkeypatch.setattr(upload_mod, "extract_from_file", lambda c, f: [
        Transaccion(fecha=date(2025, 6, 1), descripcion="LIDER", monto=-45000,
                    tipo="cargo", banco="bci"),
        Transaccion(fecha=date(2025, 6, 10), descripcion="SUELDO", monto=2500000,
                    tipo="abono", banco="bci"),
    ])
    monkeypatch.setattr(upload_mod, "indexar_transacciones", lambda txns, uid: len(txns))

    app.dependency_overrides[get_session] = _override_session
    app.dependency_overrides[get_current_user] = lambda: "u1"
    yield TestClient(app)
    app.dependency_overrides.clear()


def _file():
    return {"file": ("cartola.pdf", io.BytesIO(b"%PDF-fake"), "application/pdf")}


def test_upload_inserta_y_dedup(client):
    r = client.post("/api/v1/transactions/upload", files=_file())
    assert r.status_code == 201
    assert r.json()["transacciones_procesadas"] == 2
    r2 = client.post("/api/v1/transactions/upload", files=_file())
    assert r2.json()["transacciones_procesadas"] == 0  # dedup


def test_upload_sin_transacciones_422(client, monkeypatch):
    monkeypatch.setattr(upload_mod, "extract_from_file", lambda c, f: [])
    r = client.post("/api/v1/transactions/upload", files=_file())
    assert r.status_code == 422


def test_upload_limite_429(client, monkeypatch):
    from app.services.upload_limit import UploadLimitError
    def _raise(s, u):
        raise UploadLimitError("Llegaste al límite de subidas del mes")
    monkeypatch.setattr(upload_mod, "check_limit", _raise)
    r = client.post("/api/v1/transactions/upload", files=_file())
    assert r.status_code == 429
