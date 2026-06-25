"""Tests for GET /api/v1/insights/tarjeta and upload→card-state integration."""
import io
import json
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
def client():
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

    app.dependency_overrides[get_session] = _override_session
    app.dependency_overrides[get_current_user] = lambda: "u1"
    yield TestClient(app)
    app.dependency_overrides.clear()


def test_tarjeta_get_sin_datos(client):
    r = client.get("/api/v1/insights/tarjeta")
    assert r.status_code == 200
    body = r.json()
    assert body["tiene_datos"] is False


def test_tarjeta_get_shape(client):
    r = client.get("/api/v1/insights/tarjeta")
    body = r.json()
    for key in ("tiene_datos", "total_a_pagar", "monto_minimo", "fecha_vencimiento",
                "cupo_total", "cupo_utilizado", "comprometido_proximo_mes", "cuotas"):
        assert key in body


def test_tarjeta_requires_auth():
    app.dependency_overrides.clear()
    c = TestClient(app)
    r = c.get("/api/v1/insights/tarjeta")
    assert r.status_code in (401, 403)


def test_upload_pdf_guarda_estado_tarjeta(client, monkeypatch):
    """When upload receives a PDF that is a credit-card statement, it stores the card state."""
    estado = {
        "es_tarjeta": True,
        "total_a_pagar": 175000.0,
        "monto_minimo": 17500.0,
        "fecha_vencimiento": "2026-07-15",
        "cupo_total": 800000.0,
        "cupo_utilizado": 290000.0,
        "cuotas_pendientes": [
            {"descripcion": "Refrigerador", "valor_cuota": 38000.0, "cuotas_restantes": 7}
        ],
    }

    monkeypatch.setattr(upload_mod, "extract_from_file", lambda c, f: [
        Transaccion(fecha=date(2026, 6, 1), descripcion="LIDER", monto=-45000,
                    tipo="cargo", banco="bci"),
    ])
    monkeypatch.setattr(upload_mod, "indexar_transacciones", lambda txns, uid: None)
    monkeypatch.setattr(upload_mod, "extraer_estado_tarjeta", lambda c, f: estado)

    r = client.post(
        "/api/v1/transactions/upload",
        files={"file": ("estado_cuenta.pdf", io.BytesIO(b"%PDF-fake"), "application/pdf")},
    )
    assert r.status_code == 201

    r2 = client.get("/api/v1/insights/tarjeta")
    body = r2.json()
    assert body["tiene_datos"] is True
    assert body["total_a_pagar"] == pytest.approx(175000.0)
    assert body["comprometido_proximo_mes"] == pytest.approx(38000.0)


def test_upload_no_pdf_no_llama_extractor_tarjeta(client, monkeypatch):
    """A CSV upload should not invoke the card extractor at all."""
    extractor_called = []

    monkeypatch.setattr(upload_mod, "extract_from_file", lambda c, f: [
        Transaccion(fecha=date(2026, 6, 1), descripcion="SUELDO", monto=1500000,
                    tipo="abono", banco="bci"),
    ])
    monkeypatch.setattr(upload_mod, "indexar_transacciones", lambda txns, uid: None)

    def _extractor_spy(c, f):
        extractor_called.append(True)
        return None

    monkeypatch.setattr(upload_mod, "extraer_estado_tarjeta", _extractor_spy)

    client.post(
        "/api/v1/transactions/upload",
        files={"file": ("cartola.csv", io.BytesIO(b"fecha,monto\n2026-06-01,-45000"), "text/csv")},
    )
    # extraer_estado_tarjeta should return None for CSV (non-PDF), so no card state stored
    r = client.get("/api/v1/insights/tarjeta")
    assert r.json()["tiene_datos"] is False


def test_upload_card_extractor_failure_does_not_break_upload(client, monkeypatch):
    """If the card extractor raises an exception, the upload still returns 201."""
    monkeypatch.setattr(upload_mod, "extract_from_file", lambda c, f: [
        Transaccion(fecha=date(2026, 6, 1), descripcion="LIDER", monto=-45000,
                    tipo="cargo", banco="bci"),
    ])
    monkeypatch.setattr(upload_mod, "indexar_transacciones", lambda txns, uid: None)
    monkeypatch.setattr(upload_mod, "extraer_estado_tarjeta", lambda c, f: (_ for _ in ()).throw(RuntimeError("LLM exploded")))

    r = client.post(
        "/api/v1/transactions/upload",
        files={"file": ("estado.pdf", io.BytesIO(b"%PDF-fake"), "application/pdf")},
    )
    assert r.status_code == 201
