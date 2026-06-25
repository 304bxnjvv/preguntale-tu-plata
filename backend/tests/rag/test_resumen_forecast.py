"""Task F2: Tests that _build_resumen_block injects forecast data into chat context."""
from datetime import date
from unittest.mock import patch

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.db.models  # noqa: F401
from app.db.base import Base
from app.db.models import Transaction


@pytest.fixture
def session():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    s = sessionmaker(bind=engine)()
    yield s
    s.close()


def _add(session, user_id, fecha, descripcion, monto, cat="Otros"):
    session.add(
        Transaction(
            user_id=user_id,
            fecha=fecha,
            descripcion=descripcion,
            monto=monto,
            moneda="CLP",
            tipo="gasto" if monto < 0 else "ingreso",
            categoria=cat,
            banco="bci",
            fuente="cartola",
        )
    )
    session.commit()


def test_build_resumen_block_includes_proyeccion_when_tiene_datos(session):
    """Cuando hay gastos este mes, _build_resumen_block debe incluir 'Proyección'."""
    hoy = date.today()
    # Agrega gasto este mes para que tiene_datos=True
    _add(session, "u1", date(hoy.year, hoy.month, 1), "supermercado", -50000, "Comida y delivery")

    from app.rag.rag_service import _build_resumen_block
    result = _build_resumen_block(session, "u1")

    # Debe contener la línea de proyección
    assert "Proyección" in result


def test_build_resumen_block_no_proyeccion_sin_datos(session):
    """Sin gastos este mes (tiene_datos=False), no debe incluir línea de proyección."""
    from app.rag.rag_service import _build_resumen_block
    result = _build_resumen_block(session, "u1")

    # Sin datos no debe proyectar (la línea no aparece)
    assert "Proyección" not in result


def test_build_resumen_block_proyeccion_includes_monto(session):
    """La línea de proyección debe incluir el gasto proyectado en formato CLP."""
    hoy = date.today()
    _add(session, "u1", date(hoy.year, hoy.month, 1), "gastos", -100000, "Otros")

    from app.rag.rag_service import _build_resumen_block
    result = _build_resumen_block(session, "u1")

    # Debe mencionar algún monto en formato pesos
    assert "$" in result
    # Debe mencionar proyección
    assert "Proyección" in result
