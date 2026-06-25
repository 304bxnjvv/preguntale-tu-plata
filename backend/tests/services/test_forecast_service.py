# backend/tests/services/test_forecast_service.py
import pytest
from datetime import date
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
import app.db.models  # noqa
from app.db.base import Base
from app.db.models import Transaction
from app.services.forecast_service import proyectar_mes

@pytest.fixture
def session():
    eng = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(eng)
    s = sessionmaker(bind=eng)()
    yield s
    s.close()

def _t(s, dia, monto, cat="Otros"):
    s.add(Transaction(user_id="u1", fecha=date(2026, 6, dia), descripcion="x", monto=monto,
                      moneda="CLP", tipo="gasto" if monto < 0 else "ingreso", categoria=cat, banco="b", fuente="test"))
    s.commit()

def test_proyeccion_lineal(session):
    # día 10, gastó 100.000 → ritmo 10.000/día, quedan 20 días → proyectado 300.000
    _t(session, 5, -50000); _t(session, 9, -50000)
    r = proyectar_mes(session, "u1", hoy=date(2026, 6, 10))
    assert r["tiene_datos"] is True
    assert r["gasto_actual"] == 100000
    assert r["gasto_proyectado"] == pytest.approx(300000)
    assert r["dias_restantes"] == 20

def test_neto_con_ingresos(session):
    _t(session, 5, -50000); _t(session, 9, -50000)
    _t(session, 1, 500000, "Otros")  # ingreso
    r = proyectar_mes(session, "u1", hoy=date(2026, 6, 10))
    assert r["ingresos_mes"] == 500000
    assert r["neto_proyectado"] == pytest.approx(200000)  # 500k - 300k

def test_neto_none_sin_ingresos(session):
    _t(session, 5, -50000)
    r = proyectar_mes(session, "u1", hoy=date(2026, 6, 10))
    assert r["neto_proyectado"] is None

def test_confianza_baja_temprano(session):
    _t(session, 1, -10000)
    r = proyectar_mes(session, "u1", hoy=date(2026, 6, 2))
    assert r["confianza"] == "baja"

def test_sin_datos(session):
    r = proyectar_mes(session, "u1", hoy=date(2026, 6, 10))
    assert r["tiene_datos"] is False
