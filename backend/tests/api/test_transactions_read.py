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


# --- NEW: API filter tests ---

def test_list_transactions_tipo_gasto_filter(client):
    """GET /transactions?tipo=gasto returns only expenses."""
    r = client.get("/api/v1/transactions?tipo=gasto")
    assert r.status_code == 200
    data = r.json()
    assert len(data) == 1
    assert data[0]["monto"] == -45000.0


def test_list_transactions_dias_filter(client):
    """GET /transactions?dias=7 limits to last 7 days (future-proof: both txns are old, so 0 results)."""
    r = client.get("/api/v1/transactions?dias=7")
    assert r.status_code == 200
    # Both transactions are from 2025, well outside 7 days from today (2026-06-24)
    data = r.json()
    assert len(data) == 0


def test_list_transactions_dias_and_tipo(client):
    """GET /transactions?dias=7&tipo=gasto filters both dimensions."""
    r = client.get("/api/v1/transactions?dias=7&tipo=gasto")
    assert r.status_code == 200
    data = r.json()
    assert len(data) == 0


def test_list_transactions_invalid_tipo_returns_422(client):
    """GET /transactions?tipo=foo → 422."""
    r = client.get("/api/v1/transactions?tipo=foo")
    assert r.status_code == 422


def test_summary_tipo_ingreso_via_api(client):
    """GET /transactions/summary?tipo=ingreso → gastos_por_banco reflects income side."""
    r = client.get("/api/v1/transactions/summary?tipo=ingreso")
    assert r.status_code == 200
    body = r.json()
    bancos = {b["banco"]: b["total"] for b in body["gastos_por_banco"]}
    assert bancos.get("bci") == 2500000.0


def test_summary_invalid_tipo_returns_422(client):
    """GET /transactions/summary?tipo=xyz → 422."""
    r = client.get("/api/v1/transactions/summary?tipo=xyz")
    assert r.status_code == 422


def test_summary_no_params_backward_compat(client):
    """No-param summary call is unchanged."""
    r = client.get("/api/v1/transactions/summary")
    assert r.status_code == 200
    body = r.json()
    assert body["por_moneda"]["CLP"]["ingresos"] == 2500000.0
    assert body["por_moneda"]["CLP"]["gastos"] == -45000.0


def test_list_transactions_no_params_backward_compat(client):
    """No-param list call returns all transactions (backward compat)."""
    r = client.get("/api/v1/transactions")
    assert r.status_code == 200
    assert len(r.json()) == 2
