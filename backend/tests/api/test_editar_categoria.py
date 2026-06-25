import pytest
from datetime import date
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
import app.db.models  # noqa
from app.main import app
from app.db.base import Base, get_session
from app.auth.jwt import get_current_user
from app.db.models import Transaction


@pytest.fixture
def ctx():
    eng = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(eng)
    TS = sessionmaker(bind=eng)

    def _ov():
        s = TS()
        try:
            yield s
        finally:
            s.close()

    app.dependency_overrides[get_session] = _ov
    app.dependency_overrides[get_current_user] = lambda: "u1"
    yield TS
    app.dependency_overrides.clear()


def _mk(s, desc, cat):
    t = Transaction(
        user_id="u1",
        fecha=date(2026, 6, 1),
        descripcion=desc,
        monto=-1000,
        moneda="CLP",
        tipo="gasto",
        categoria=cat,
        banco="x",
        fuente="test",
    )
    s.add(t)
    s.commit()
    s.refresh(t)
    return t.id


def test_editar_categoria_marca_manual_y_recategoriza(ctx):
    s = ctx()
    id1 = _mk(s, "UBER EATS 1", "Otros")
    id2 = _mk(s, "UBER EATS 2", "Otros")  # mismo comercio, no manual
    c = TestClient(app)
    r = c.patch(f"/api/v1/transactions/{id1}", json={"categoria": "Comida y delivery"})
    assert r.status_code == 200
    assert r.json()["actualizadas"] >= 2  # la editada + la pasada
    s2 = ctx()
    assert s2.query(Transaction).filter_by(id=id1).first().categoria == "Comida y delivery"
    assert s2.query(Transaction).filter_by(id=id1).first().categoria_manual is True
    assert s2.query(Transaction).filter_by(id=id2).first().categoria == "Comida y delivery"


def test_editar_categoria_invalida_422(ctx):
    s = ctx()
    idx = _mk(s, "X", "Otros")
    c = TestClient(app)
    r = c.patch(f"/api/v1/transactions/{idx}", json={"categoria": "NoExiste"})
    assert r.status_code == 422


def test_editar_categoria_no_pisa_otra_manual(ctx):
    s = ctx()
    id1 = _mk(s, "UBER EATS 1", "Salud")
    s.query(Transaction).filter_by(id=id1).update({"categoria_manual": True})
    s.commit()
    id2 = _mk(s, "UBER EATS 2", "Otros")
    c = TestClient(app)
    c.patch(f"/api/v1/transactions/{id2}", json={"categoria": "Comida y delivery"})
    s2 = ctx()
    # id1 era manual con otra categoría → no se pisa
    assert s2.query(Transaction).filter_by(id=id1).first().categoria == "Salud"


def test_patch_transaction_requires_auth():
    app.dependency_overrides.clear()
    c = TestClient(app)
    r = c.patch(
        "/api/v1/transactions/00000000-0000-0000-0000-000000000001",
        json={"categoria": "Comida y delivery"},
    )
    assert r.status_code in (401, 403)
