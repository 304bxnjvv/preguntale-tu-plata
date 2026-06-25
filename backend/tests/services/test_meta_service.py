"""Task A3: Tests para meta_service (sqlite in-memory)."""
import pytest
from datetime import date, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
import app.db.models  # noqa — registra todos los modelos en Base.metadata
from app.db.base import Base
from app.services.meta_service import (
    crear_meta,
    actualizar_meta,
    eliminar_meta,
    listar_metas,
)


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
# Tests
# ---------------------------------------------------------------------------


def test_crear_meta_y_listar(session):
    """Crear una meta y listarla; verificar campos básicos."""
    m = crear_meta(session, "u1", "Fondo emergencia", 500000, None)
    assert m["nombre"] == "Fondo emergencia"
    assert float(m["monto_objetivo"]) == 500000
    assert float(m["monto_actual"]) == 0
    assert m["fecha_objetivo"] is None
    assert m["progreso"] == 0.0
    assert m["aporte_mensual_necesario"] is None

    lista = listar_metas(session, "u1")
    assert len(lista) == 1
    assert lista[0]["id"] == m["id"]


def test_progreso_correcto(session):
    """progreso = monto_actual / monto_objetivo clampado a [0, 1]."""
    m = crear_meta(session, "u1", "Vacaciones", 200000, None)
    act = actualizar_meta(session, "u1", m["id"], monto_actual=100000)
    assert act is not None
    assert abs(act["progreso"] - 0.5) < 0.001


def test_progreso_cero_si_objetivo_es_cero(session):
    """Si monto_objetivo == 0, progreso debe ser 0 (no dividir por cero)."""
    m = crear_meta(session, "u1", "Prueba cero", 0, None)
    lista = listar_metas(session, "u1")
    fila = next(x for x in lista if x["id"] == m["id"])
    assert fila["progreso"] == 0.0


def test_progreso_clampado_a_1(session):
    """Si monto_actual > monto_objetivo, progreso no debe superar 1."""
    m = crear_meta(session, "u1", "SuperMeta", 100000, None)
    act = actualizar_meta(session, "u1", m["id"], monto_actual=150000)
    assert act["progreso"] == 1.0


def test_aporte_mensual_necesario_con_fecha_futura(session):
    """Cuando hay fecha_objetivo futura, calcula aporte_mensual_necesario."""
    fecha_futura = (date.today() + timedelta(days=90)).isoformat()  # ~3 meses
    m = crear_meta(session, "u1", "Auto", 900000, fecha_futura)
    lista = listar_metas(session, "u1")
    fila = next(x for x in lista if x["id"] == m["id"])
    # ~3 meses → aporte ≈ 300000; validar que es positivo y no None
    assert fila["aporte_mensual_necesario"] is not None
    assert fila["aporte_mensual_necesario"] > 0


def test_aporte_mensual_necesario_nunca_negativo(session):
    """Si monto_actual >= monto_objetivo, aporte_mensual_necesario debe ser 0 (nunca negativo)."""
    fecha_futura = (date.today() + timedelta(days=60)).isoformat()
    m = crear_meta(session, "u1", "Ya cumplida", 100000, fecha_futura)
    act = actualizar_meta(session, "u1", m["id"], monto_actual=120000)
    assert act["aporte_mensual_necesario"] is not None
    assert act["aporte_mensual_necesario"] >= 0


def test_aporte_mensual_sin_fecha_es_null(session):
    """Sin fecha_objetivo, aporte_mensual_necesario es null."""
    m = crear_meta(session, "u1", "Sin fecha", 100000, None)
    lista = listar_metas(session, "u1")
    fila = next(x for x in lista if x["id"] == m["id"])
    assert fila["aporte_mensual_necesario"] is None


def test_actualizar_meta_nombre_y_objetivo(session):
    """actualizar_meta permite cambiar nombre y monto_objetivo."""
    m = crear_meta(session, "u1", "Viaje", 300000, None)
    act = actualizar_meta(session, "u1", m["id"], nombre="Viaje Europa", monto_objetivo=500000)
    assert act["nombre"] == "Viaje Europa"
    assert float(act["monto_objetivo"]) == 500000


def test_actualizar_meta_no_existente_retorna_none(session):
    """Si meta_id no existe para ese usuario, retorna None."""
    result = actualizar_meta(session, "u1", "id-inexistente", nombre="X")
    assert result is None


def test_eliminar_meta(session):
    """eliminar_meta retorna True y elimina la meta de la lista."""
    m = crear_meta(session, "u1", "Borrar", 100000, None)
    assert eliminar_meta(session, "u1", m["id"]) is True
    assert listar_metas(session, "u1") == []


def test_eliminar_meta_inexistente(session):
    """eliminar_meta retorna False si la meta no existe."""
    assert eliminar_meta(session, "u1", "no-existe") is False


def test_metas_son_por_usuario(session):
    """Las metas de u1 no aparecen para u2."""
    crear_meta(session, "u1", "Solo u1", 100000, None)
    assert listar_metas(session, "u2") == []


def test_listar_metas_multiples(session):
    """Se pueden tener varias metas y listar_metas las devuelve todas."""
    crear_meta(session, "u1", "Meta A", 100000, None)
    crear_meta(session, "u1", "Meta B", 200000, None)
    lista = listar_metas(session, "u1")
    assert len(lista) == 2
    nombres = {m["nombre"] for m in lista}
    assert nombres == {"Meta A", "Meta B"}
