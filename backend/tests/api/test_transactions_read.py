import pytest
from datetime import date
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from app.main import app as fastapi_app
from app.db.base import Base, get_session
from app.auth.jwt import get_current_user
from app.models.schemas import Transaccion
from app.services.transaction_service import insert_transactions
import app.db.models  # noqa: F401


@pytest.fixture
def client():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    TestSession = sessionmaker(bind=engine)
    s = TestSession()
    insert_transactions(s, "u1", [
        Transaccion(fecha=date(2025, 6, 1), descripcion="LIDER", monto=-45000,
                    tipo="cargo", banco="bci", categoria="supermercado"),
        Transaccion(fecha=date(2025, 6, 10), descripcion="SUELDO", monto=2500000,
                    tipo="abono", banco="bci"),
    ])
    s.close()

    def _override_session():
        s2 = TestSession()
        try:
            yield s2
        finally:
            s2.close()

    fastapi_app.dependency_overrides[get_session] = _override_session
    fastapi_app.dependency_overrides[get_current_user] = lambda: "u1"
    yield TestClient(fastapi_app)
    fastapi_app.dependency_overrides.clear()


def test_list_transactions(client):
    r = client.get("/api/v1/transactions")
    assert r.status_code == 200
    data = r.json()
    assert len(data) == 2
    assert data[0]["fecha"] == "2025-06-10"   # orden desc por fecha


def test_summary_endpoint(client):
    r = client.get("/api/v1/transactions/summary")
    assert r.status_code == 200
    body = r.json()
    assert body["por_moneda"]["CLP"]["ingresos"] == 2500000.0
    assert body["por_moneda"]["CLP"]["gastos"] == -45000.0
