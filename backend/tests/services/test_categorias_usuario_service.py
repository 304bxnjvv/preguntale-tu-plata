"""Tests para categorias_usuario_service (sqlite in-memory)."""
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.db.models  # noqa — registra todos los modelos en Base.metadata
from app.db.base import Base
from app.services.categorias_usuario_service import (
    agregar,
    categorias_efectivas,
    eliminar,
    listar,
)
from app.services.categorias import CATEGORIAS


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


def test_agregar_y_listar(session):
    nombre = agregar(session, "u1", "Mascotas")
    assert nombre == "Mascotas"
    lista = listar(session, "u1")
    assert lista == ["Mascotas"]


def test_agregar_trim(session):
    nombre = agregar(session, "u1", "  Viajes  ")
    assert nombre == "Viajes"
    assert listar(session, "u1") == ["Viajes"]


def test_agregar_rechaza_vacio(session):
    with pytest.raises(ValueError, match="vacío"):
        agregar(session, "u1", "   ")


def test_agregar_rechaza_mas_de_30_chars(session):
    with pytest.raises(ValueError, match="30 caracteres"):
        agregar(session, "u1", "A" * 31)


def test_agregar_rechaza_duplicado_exacto(session):
    agregar(session, "u1", "Mascotas")
    with pytest.raises(ValueError, match="(?i)ya existe"):
        agregar(session, "u1", "Mascotas")


def test_agregar_rechaza_duplicado_case_insensitive(session):
    agregar(session, "u1", "Mascotas")
    with pytest.raises(ValueError, match="(?i)ya existe"):
        agregar(session, "u1", "mascotas")


def test_agregar_rechaza_duplicado_accent_insensitive(session):
    agregar(session, "u1", "Mascotas")
    with pytest.raises(ValueError, match="(?i)ya existe"):
        agregar(session, "u1", "Máscotas")


def test_agregar_rechaza_choque_con_categoria_base(session):
    with pytest.raises(ValueError, match="categoría base"):
        agregar(session, "u1", "Salud")


def test_agregar_rechaza_choque_con_base_case_insensitive(session):
    with pytest.raises(ValueError, match="categoría base"):
        agregar(session, "u1", "salud")


def test_agregar_rechaza_choque_con_base_accent_insensitive(session):
    # "Entretención" con acento
    with pytest.raises(ValueError, match="categoría base"):
        agregar(session, "u1", "Entretencion")


def test_agregar_usuarios_distintos_no_interfieren(session):
    agregar(session, "u1", "Mascotas")
    # u2 puede agregar la misma categoría
    nombre = agregar(session, "u2", "Mascotas")
    assert nombre == "Mascotas"
    assert listar(session, "u1") == ["Mascotas"]
    assert listar(session, "u2") == ["Mascotas"]


def test_eliminar_existente(session):
    agregar(session, "u1", "Mascotas")
    ok = eliminar(session, "u1", "Mascotas")
    assert ok is True
    assert listar(session, "u1") == []


def test_eliminar_inexistente(session):
    ok = eliminar(session, "u1", "NoExiste")
    assert ok is False


def test_eliminar_case_insensitive(session):
    agregar(session, "u1", "Mascotas")
    ok = eliminar(session, "u1", "mascotas")
    assert ok is True
    assert listar(session, "u1") == []


def test_categorias_efectivas_incluye_base_y_custom(session):
    agregar(session, "u1", "Mascotas")
    agregar(session, "u1", "Ropa")
    efectivas = categorias_efectivas(session, "u1")
    # Las 11 base deben estar primero
    assert efectivas[:len(CATEGORIAS)] == list(CATEGORIAS)
    # Las custom al final
    assert "Mascotas" in efectivas
    assert "Ropa" in efectivas
    assert len(efectivas) == len(CATEGORIAS) + 2


def test_categorias_efectivas_sin_custom_igual_a_base(session):
    efectivas = categorias_efectivas(session, "u1")
    assert efectivas == list(CATEGORIAS)


def test_categorias_efectivas_sin_duplicados(session):
    agregar(session, "u1", "Mascotas")
    efectivas = categorias_efectivas(session, "u1")
    assert len(efectivas) == len(set(efectivas))
