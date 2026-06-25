"""Task A2: Tests para presupuesto_service (sqlite in-memory)."""
import pytest
from datetime import date
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
import app.db.models  # noqa — registra todos los modelos en Base.metadata
from app.db.base import Base
from app.db.models import Transaction
from app.services.presupuesto_service import set_tope, delete_tope, estado_presupuestos


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


def _mk_gasto(session, user_id: str, categoria: str, monto: float, dias_atras: int = 0):
    """Helper: crea una transacción de gasto para hoy (o días_atras)."""
    from datetime import timedelta
    t = Transaction(
        user_id=user_id,
        fecha=date.today() - timedelta(days=dias_atras),
        descripcion=categoria,
        monto=monto,
        moneda="CLP",
        tipo="gasto",
        categoria=categoria,
        banco="test",
        fuente="test",
    )
    session.add(t)
    session.commit()


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

def test_set_tope_y_estado_ok(session):
    set_tope(session, "u1", "Comida y delivery", 100000)
    # gasto 50.000 este mes en esa categoría → pct 0.5, estado ok
    _mk_gasto(session, "u1", "Comida y delivery", -50000)
    est = estado_presupuestos(session, "u1")
    fila = next(e for e in est if e["categoria"] == "Comida y delivery")
    assert fila["gastado"] == 50000
    assert fila["estado"] == "ok"


def test_estado_excedido(session):
    set_tope(session, "u1", "Compras", 10000)
    _mk_gasto(session, "u1", "Compras", -15000)
    fila = estado_presupuestos(session, "u1")[0]
    assert fila["estado"] == "excedido"


def test_estado_cerca(session):
    set_tope(session, "u1", "Salud", 10000)
    # gastar 8500 → pct 0.85, estado cerca
    _mk_gasto(session, "u1", "Salud", -8500)
    fila = estado_presupuestos(session, "u1")[0]
    assert fila["estado"] == "cerca"


def test_set_tope_categoria_invalida(session):
    with pytest.raises(ValueError):
        set_tope(session, "u1", "NoExiste", 1000)


def test_delete_tope(session):
    set_tope(session, "u1", "Salud", 5000)
    assert delete_tope(session, "u1", "Salud") is True
    assert estado_presupuestos(session, "u1") == []


def test_delete_tope_inexistente(session):
    assert delete_tope(session, "u1", "Salud") is False


def test_set_tope_upsert(session):
    """Hacer set_tope dos veces en la misma categoría hace UPSERT, no duplicado."""
    set_tope(session, "u1", "Compras", 10000)
    set_tope(session, "u1", "Compras", 20000)
    est = estado_presupuestos(session, "u1")
    assert len(est) == 1
    assert float(est[0]["monto_tope"]) == 20000


def test_gastos_de_mes_anterior_no_cuentan(session):
    """Gastos del mes anterior no deben sumarse al mes actual."""
    from datetime import timedelta
    set_tope(session, "u1", "Compras", 10000)
    # gasto del mes anterior (hace 32 días)
    _mk_gasto(session, "u1", "Compras", -5000, dias_atras=32)
    fila = estado_presupuestos(session, "u1")[0]
    # el gasto de mes pasado no cuenta → gastado=0, estado ok
    assert fila["gastado"] == 0
    assert fila["estado"] == "ok"


def test_estado_retorna_pct(session):
    set_tope(session, "u1", "Transporte", 20000)
    _mk_gasto(session, "u1", "Transporte", -10000)
    fila = estado_presupuestos(session, "u1")[0]
    assert abs(fila["pct"] - 0.5) < 0.001
    assert fila["monto_tope"] == 20000
