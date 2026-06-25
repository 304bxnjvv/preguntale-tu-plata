"""Task A1: Tests para modelos Presupuesto y Meta (sqlite in-memory)."""
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
import app.db.models  # noqa — registra todos los modelos en Base.metadata
from app.db.base import Base
from app.db.models import Presupuesto, Meta


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


# ---------------------------------------------------------------------------
# Presupuesto
# ---------------------------------------------------------------------------

def test_presupuesto_crea_y_persiste(session):
    p = Presupuesto(user_id="u1", categoria="Comida y delivery", monto_tope=100000)
    session.add(p)
    session.commit()

    row = session.query(Presupuesto).filter_by(user_id="u1").first()
    assert row is not None
    assert row.categoria == "Comida y delivery"
    assert float(row.monto_tope) == 100000.0
    assert row.id is not None  # uuid asignado


def test_presupuesto_unique_user_categoria(session):
    """Insertar dos veces (user_id, categoria) → IntegrityError al hacer commit."""
    from sqlalchemy.exc import IntegrityError

    session.add(Presupuesto(user_id="u1", categoria="Compras", monto_tope=50000))
    session.commit()

    session.add(Presupuesto(user_id="u1", categoria="Compras", monto_tope=60000))
    with pytest.raises(IntegrityError):
        session.commit()


def test_presupuesto_misma_categoria_distinto_usuario(session):
    """Distinto usuario → no hay conflicto."""
    session.add(Presupuesto(user_id="u1", categoria="Salud", monto_tope=20000))
    session.add(Presupuesto(user_id="u2", categoria="Salud", monto_tope=30000))
    session.commit()  # no debe lanzar

    count = session.query(Presupuesto).filter_by(categoria="Salud").count()
    assert count == 2


# ---------------------------------------------------------------------------
# Meta
# ---------------------------------------------------------------------------

def test_meta_crea_y_persiste(session):
    from datetime import date

    m = Meta(
        user_id="u1",
        nombre="Fondo de emergencia",
        monto_objetivo=1_000_000,
        monto_actual=250_000,
        fecha_objetivo=date(2026, 12, 31),
    )
    session.add(m)
    session.commit()

    row = session.query(Meta).filter_by(user_id="u1").first()
    assert row is not None
    assert row.nombre == "Fondo de emergencia"
    assert float(row.monto_objetivo) == 1_000_000.0
    assert float(row.monto_actual) == 250_000.0
    assert row.fecha_objetivo == date(2026, 12, 31)
    assert row.id is not None


def test_meta_fecha_opcional(session):
    m = Meta(user_id="u1", nombre="Viaje", monto_objetivo=500_000)
    session.add(m)
    session.commit()

    row = session.query(Meta).filter_by(nombre="Viaje").first()
    assert row.fecha_objetivo is None
    assert float(row.monto_actual) == 0.0  # default


def test_meta_multiples_por_usuario(session):
    session.add(Meta(user_id="u1", nombre="Meta A", monto_objetivo=100_000))
    session.add(Meta(user_id="u1", nombre="Meta B", monto_objetivo=200_000))
    session.commit()

    metas = session.query(Meta).filter_by(user_id="u1").all()
    assert len(metas) == 2
