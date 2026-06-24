import io
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
import app.db.models  # noqa: F401
from app.main import app
from app.db.base import Base, get_session
from app.auth.jwt import get_current_user


@pytest.fixture
def client(monkeypatch):
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

    # Evita llamar a pgvector/red en el test.
    monkeypatch.setattr(
        "app.api.routes.upload.indexar_transacciones", lambda txns, user_id: len(txns)
    )

    app.dependency_overrides[get_session] = _override_session
    app.dependency_overrides[get_current_user] = lambda: "u1"
    yield TestClient(app)
    app.dependency_overrides.clear()


CSV = (
    "fecha;descripción;cargo;abono;saldo\n"
    "01/06/2025;SUPERMERCADO LIDER;45000;;1500000\n"
    "05/06/2025;UBER EATS;12500;;1487500\n"
).encode("latin-1")


def test_upload_requires_auth():
    # Sin override de auth → 403 (sin credenciales bearer).
    c = TestClient(app)
    r = c.post("/api/v1/transactions/upload-csv?banco=bci",
               files={"file": ("c.csv", io.BytesIO(CSV), "text/csv")})
    assert r.status_code in (401, 403)


def test_upload_inserts_and_dedups(client):
    files = {"file": ("c.csv", io.BytesIO(CSV), "text/csv")}
    r = client.post("/api/v1/transactions/upload-csv?banco=bci", files=files)
    assert r.status_code == 201
    assert r.json()["transacciones_procesadas"] == 2

    # Re-subir el mismo CSV → 0 nuevas (dedup).
    r2 = client.post("/api/v1/transactions/upload-csv?banco=bci",
                     files={"file": ("c.csv", io.BytesIO(CSV), "text/csv")})
    assert r2.status_code == 201
    assert r2.json()["transacciones_procesadas"] == 0
