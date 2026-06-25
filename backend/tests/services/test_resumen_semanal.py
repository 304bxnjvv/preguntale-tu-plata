# backend/tests/services/test_resumen_semanal.py
import pytest
from datetime import date, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
import app.db.models  # noqa
from app.db.base import Base
from app.db.models import Transaction
from app.services.resumen_semanal_service import generar_resumen

HOY = date(2026, 6, 25)

@pytest.fixture
def session():
    eng = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(eng)
    s = sessionmaker(bind=eng)()
    yield s
    s.close()

def _g(s, dias_atras, monto, cat="Comida y delivery", desc="x"):
    s.add(Transaction(user_id="u1", fecha=HOY - timedelta(days=dias_atras), descripcion=desc,
                      monto=monto, moneda="CLP", tipo="gasto", categoria=cat, banco="b", fuente="test"))
    s.commit()

def test_sin_datos(session):
    r = generar_resumen(session, "u1", hoy=HOY)
    assert r["tiene_datos"] is False
    assert r["gasto_semana"] == 0

def test_gasto_y_top_categoria(session):
    _g(session, 1, -20000, "Comida y delivery")
    _g(session, 2, -5000, "Transporte")
    r = generar_resumen(session, "u1", hoy=HOY)
    assert r["tiene_datos"] is True
    assert r["gasto_semana"] == 25000
    assert r["top_categoria"] == "Comida y delivery"
    assert r["top_monto"] == 20000
    assert "25.000" in r["texto"]

def test_delta_vs_semana_anterior(session):
    _g(session, 1, -10000)          # esta semana
    _g(session, 9, -5000)           # semana pasada
    r = generar_resumen(session, "u1", hoy=HOY)
    assert r["delta_pct"] == pytest.approx(100.0)  # subió 100%

def test_delta_none_sin_semana_previa(session):
    _g(session, 1, -10000)
    r = generar_resumen(session, "u1", hoy=HOY)
    assert r["delta_pct"] is None
