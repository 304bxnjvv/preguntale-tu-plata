"""Task B1: Tests para alertas_service (sqlite in-memory)."""
import pytest
from datetime import date, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.db.models  # noqa — registra todos los modelos en Base.metadata
from app.db.base import Base
from app.db.models import Transaction
from app.services.alertas_service import evaluar_alertas


@pytest.fixture
def session():
    eng = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(eng)
    S = sessionmaker(bind=eng)
    s = S()
    yield s
    s.close()


def _mk_gasto(session, user_id: str, descripcion: str, monto: float, dias_atras: int = 0,
              categoria: str = "Otros"):
    """Helper: crea una transacción de gasto para hoy (o días_atras)."""
    t = Transaction(
        user_id=user_id,
        fecha=date.today() - timedelta(days=dias_atras),
        descripcion=descripcion,
        monto=monto,
        moneda="CLP",
        tipo="gasto",
        categoria=categoria,
        banco="test",
        fuente="test",
    )
    session.add(t)
    session.commit()


def test_alerta_tarjeta_vence(session):
    from app.services.tarjeta_service import guardar_estado
    venc = (date.today() + timedelta(days=3)).isoformat()
    guardar_estado(
        session, "u1",
        {"total_a_pagar": 200000, "fecha_vencimiento": venc, "cuotas_pendientes": []},
    )
    alertas = evaluar_alertas(session, "u1")
    assert any(a["tipo"] == "tarjeta_vence" and a["severidad"] == "urgent" for a in alertas)


def test_tarjeta_vence_lejos_sin_alerta(session):
    """Vencimiento a más de 5 días no genera alerta de tarjeta."""
    from app.services.tarjeta_service import guardar_estado
    venc = (date.today() + timedelta(days=20)).isoformat()
    guardar_estado(
        session, "u1",
        {"total_a_pagar": 200000, "fecha_vencimiento": venc, "cuotas_pendientes": []},
    )
    alertas = evaluar_alertas(session, "u1")
    assert not any(a["tipo"] == "tarjeta_vence" for a in alertas)


def test_alerta_presupuesto_excedido(session):
    from app.services.presupuesto_service import set_tope
    set_tope(session, "u1", "Compras", 10000)
    _mk_gasto(session, "u1", "Compras", -15000, categoria="Compras")  # hoy
    alertas = evaluar_alertas(session, "u1")
    presupuesto_alertas = [a for a in alertas if a["tipo"] == "presupuesto"]
    assert len(presupuesto_alertas) >= 1
    assert presupuesto_alertas[0]["key"] == "presupuesto:Compras"


def test_alerta_cuotas_proximo_mes(session):
    from app.services.tarjeta_service import guardar_estado
    guardar_estado(
        session, "u1",
        {
            "total_a_pagar": 200000,
            "fecha_vencimiento": None,
            "cuotas_pendientes": [{"valor_cuota": 30000}],
        },
    )
    alertas = evaluar_alertas(session, "u1")
    cuotas = [a for a in alertas if a["tipo"] == "cuotas_proximo_mes"]
    assert len(cuotas) == 1
    assert cuotas[0]["severidad"] == "warning"
    assert cuotas[0]["key"] == "cuotas_proximo_mes"


def test_sin_datos_sin_alertas(session):
    assert evaluar_alertas(session, "u1") == []


def test_gasto_inusual(session):
    # varios gastos chicos + uno enorme reciente
    for _ in range(6):
        _mk_gasto(session, "u1", "almuerzo", -5000, dias_atras=30)
    _mk_gasto(session, "u1", "notebook", -800000, dias_atras=1)
    alertas = evaluar_alertas(session, "u1")
    inusuales = [a for a in alertas if a["tipo"] == "gasto_inusual"]
    assert len(inusuales) >= 1
    assert inusuales[0]["severidad"] == "info"
    assert inusuales[0]["key"].startswith("gasto:")


def test_gasto_normal_no_es_inusual(session):
    """Gastos parejos (sin outlier) no generan alerta de gasto inusual."""
    for _ in range(6):
        _mk_gasto(session, "u1", "almuerzo", -5000, dias_atras=30)
    _mk_gasto(session, "u1", "almuerzo", -6000, dias_atras=1)
    alertas = evaluar_alertas(session, "u1")
    assert not any(a["tipo"] == "gasto_inusual" for a in alertas)


def test_gasto_inusual_requiere_minimo_50000(session):
    """Un gasto que es 3x la mediana pero <50000 no genera alerta."""
    for _ in range(6):
        _mk_gasto(session, "u1", "cafe", -1000, dias_atras=30)
    _mk_gasto(session, "u1", "cena", -10000, dias_atras=1)  # 10x mediana pero <50k
    alertas = evaluar_alertas(session, "u1")
    assert not any(a["tipo"] == "gasto_inusual" for a in alertas)


def test_alerta_por_usuario(session):
    """Las alertas son por usuario: u2 no ve las de u1."""
    from app.services.presupuesto_service import set_tope
    set_tope(session, "u1", "Compras", 10000)
    _mk_gasto(session, "u1", "Compras", -15000, categoria="Compras")
    assert evaluar_alertas(session, "u2") == []
