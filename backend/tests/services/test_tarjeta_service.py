"""Tests for tarjeta_service: guardar_estado, get_estado, comprometido computation."""
import json
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

import app.db.models  # noqa: F401  – registers TarjetaEstado in Base.metadata
from app.db.base import Base
from app.services.tarjeta_service import guardar_estado, get_estado


@pytest.fixture
def session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    s = sessionmaker(bind=engine)()
    yield s
    s.close()


_DATOS_BASE = {
    "total_a_pagar": 250000.0,
    "monto_minimo": 25000.0,
    "fecha_vencimiento": "2026-07-10",
    "cupo_total": 1000000.0,
    "cupo_utilizado": 380000.0,
    "cuotas_pendientes": [
        {"descripcion": "TV Samsung", "valor_cuota": 45000.0, "cuotas_restantes": 5},
        {"descripcion": "Lavadora", "valor_cuota": 32000.0, "cuotas_restantes": 3},
    ],
}


def test_get_estado_sin_datos_devuelve_tiene_datos_false(session):
    result = get_estado(session, "u-nobody")
    assert result["tiene_datos"] is False


def test_guardar_estado_computa_comprometido(session):
    guardar_estado(session, "u1", _DATOS_BASE)
    estado = get_estado(session, "u1")
    assert estado["tiene_datos"] is True
    # comprometido = 45_000 + 32_000 = 77_000
    assert estado["comprometido_proximo_mes"] == pytest.approx(77000.0)


def test_guardar_estado_persiste_campos(session):
    guardar_estado(session, "u1", _DATOS_BASE)
    estado = get_estado(session, "u1")
    assert estado["total_a_pagar"] == pytest.approx(250000.0)
    assert estado["monto_minimo"] == pytest.approx(25000.0)
    assert estado["fecha_vencimiento"] == "2026-07-10"
    assert estado["cupo_total"] == pytest.approx(1000000.0)
    assert estado["cupo_utilizado"] == pytest.approx(380000.0)
    assert len(estado["cuotas"]) == 2


def test_guardar_estado_upsert_reemplaza(session):
    guardar_estado(session, "u1", _DATOS_BASE)
    datos2 = dict(_DATOS_BASE)
    datos2["total_a_pagar"] = 99000.0
    datos2["cuotas_pendientes"] = [
        {"descripcion": "Laptop", "valor_cuota": 80000.0, "cuotas_restantes": 6}
    ]
    guardar_estado(session, "u1", datos2)
    estado = get_estado(session, "u1")
    assert estado["total_a_pagar"] == pytest.approx(99000.0)
    assert estado["comprometido_proximo_mes"] == pytest.approx(80000.0)
    assert len(estado["cuotas"]) == 1


def test_guardar_estado_sin_cuotas(session):
    datos = dict(_DATOS_BASE)
    datos["cuotas_pendientes"] = []
    guardar_estado(session, "u1", datos)
    estado = get_estado(session, "u1")
    assert estado["comprometido_proximo_mes"] == pytest.approx(0.0)
    assert estado["cuotas"] == []


def test_guardar_estado_fecha_vencimiento_none(session):
    datos = dict(_DATOS_BASE)
    datos["fecha_vencimiento"] = None
    guardar_estado(session, "u1", datos)
    estado = get_estado(session, "u1")
    assert estado["fecha_vencimiento"] is None


def test_usuarios_aislados(session):
    guardar_estado(session, "u-a", _DATOS_BASE)
    datos_b = dict(_DATOS_BASE)
    datos_b["total_a_pagar"] = 5000.0
    datos_b["cuotas_pendientes"] = []
    guardar_estado(session, "u-b", datos_b)

    estado_a = get_estado(session, "u-a")
    estado_b = get_estado(session, "u-b")
    assert estado_a["total_a_pagar"] == pytest.approx(250000.0)
    assert estado_b["total_a_pagar"] == pytest.approx(5000.0)
