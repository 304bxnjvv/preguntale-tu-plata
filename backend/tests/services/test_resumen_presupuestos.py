"""Task A5: Tests para inyección de presupuestos y metas en _build_resumen_block."""
import pytest
from datetime import date, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.db.models  # noqa — registra todos los modelos en Base.metadata
from app.db.base import Base
from app.db.models import Transaction, Presupuesto, Meta


@pytest.fixture
def session():
    eng = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(eng)
    s = sessionmaker(bind=eng)()
    yield s
    s.close()


def _mk_gasto(session, user_id: str, categoria: str, monto: float, dias_atras: int = 0):
    """Helper: crea una transacción de gasto."""
    fecha = date.today() - timedelta(days=dias_atras)
    t = Transaction(
        user_id=user_id,
        fecha=fecha,
        descripcion=f"gasto {categoria}",
        monto=monto,
        moneda="CLP",
        tipo="gasto",
        categoria=categoria,
        banco="bci",
        fuente="test",
    )
    session.add(t)
    session.commit()


def test_resumen_incluye_presupuesto_excedido(session):
    """Con un presupuesto excedido, _build_resumen_block debe mencionar la categoría y 'excedido'."""
    from app.services.presupuesto_service import set_tope
    from app.rag.rag_service import _build_resumen_block

    set_tope(session, "u1", "Compras", 10_000)
    _mk_gasto(session, "u1", "Compras", -15_000)

    resumen = _build_resumen_block(session, "u1")
    assert "Compras" in resumen
    assert "excedido" in resumen.lower()


def test_resumen_incluye_presupuesto_cerca(session):
    """Con un presupuesto cerca del tope, _build_resumen_block debe mencionarlo."""
    from app.services.presupuesto_service import set_tope
    from app.rag.rag_service import _build_resumen_block

    set_tope(session, "u1", "Salud", 100_000)
    _mk_gasto(session, "u1", "Salud", -85_000)

    resumen = _build_resumen_block(session, "u1")
    assert "Salud" in resumen
    # debe indicar porcentaje o estado "cerca"
    assert "cerca" in resumen.lower() or "%" in resumen


def test_resumen_no_incluye_presupuesto_ok(session):
    """Presupuesto con estado 'ok' (< 80%) no debe añadir ruido al resumen."""
    from app.services.presupuesto_service import set_tope
    from app.rag.rag_service import _build_resumen_block

    set_tope(session, "u1", "Transporte", 100_000)
    _mk_gasto(session, "u1", "Transporte", -10_000)

    resumen = _build_resumen_block(session, "u1")
    # Transporte está ok (10% del tope) → no debe aparecer en el bloque de alertas
    # (puede aparecer en top_cambios de comparativo, pero no en el bloque de presupuestos)
    # Verificamos que el texto de alertas de presupuesto no esté presente
    assert "excedido" not in resumen.lower()
    assert "cerca" not in resumen.lower()


def test_resumen_incluye_meta(session):
    """Con una meta activa, _build_resumen_block debe mencionar su nombre."""
    from app.services.meta_service import crear_meta
    from app.rag.rag_service import _build_resumen_block

    crear_meta(session, "u1", "Vacaciones Japón", 500_000, None)

    resumen = _build_resumen_block(session, "u1")
    assert "Vacaciones Japón" in resumen


def test_resumen_incluye_progreso_meta(session):
    """Con una meta parcialmente cumplida, el resumen debe mostrar el progreso."""
    from app.services.meta_service import crear_meta, actualizar_meta
    from app.rag.rag_service import _build_resumen_block

    meta = crear_meta(session, "u1", "Auto nuevo", 1_000_000, None)
    actualizar_meta(session, "u1", meta["id"], monto_actual=500_000)

    resumen = _build_resumen_block(session, "u1")
    assert "Auto nuevo" in resumen
    # 50% de progreso debe aparecer en algún formato
    assert "50" in resumen


def test_resumen_sin_presupuestos_ni_metas(session):
    """Sin presupuestos ni metas, _build_resumen_block no debe fallar (sigue funcionando)."""
    from app.rag.rag_service import _build_resumen_block

    resumen = _build_resumen_block(session, "u1")
    # sin datos de gastos/suscripciones tampoco, pero no debe lanzar excepción
    # el bloque puede ser vacío o contener solo info de comparativo mensual
    assert isinstance(resumen, str)
