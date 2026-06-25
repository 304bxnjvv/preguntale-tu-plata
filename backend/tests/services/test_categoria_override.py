import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
import app.db.models  # noqa
from app.db.base import Base
from app.services.categoria_override_service import get_override, upsert_override


@pytest.fixture
def session():
    eng = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(eng)
    s = sessionmaker(bind=eng)()
    yield s
    s.close()


def test_upsert_y_get_override(session):
    upsert_override(session, "u1", "uber eats", "Comida y delivery")
    assert get_override(session, "u1", "UBER EATS *9988 STGO") == "Comida y delivery"


def test_get_override_sin_match(session):
    assert get_override(session, "u1", "FALABELLA 123") is None


def test_upsert_reemplaza(session):
    upsert_override(session, "u1", "uber eats", "Comida y delivery")
    upsert_override(session, "u1", "uber eats", "Transporte")
    assert get_override(session, "u1", "uber eats 1") == "Transporte"


def test_override_es_por_usuario(session):
    upsert_override(session, "u1", "uber eats", "Comida y delivery")
    assert get_override(session, "u2", "uber eats") is None
