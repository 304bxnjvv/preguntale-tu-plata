from datetime import date
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.db.base import Base
from app.db.models import Transaction


def _memory_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    return sessionmaker(bind=engine)()


def test_insert_and_query_transaction():
    s = _memory_session()
    t = Transaction(
        user_id="u1",
        fecha=date(2025, 6, 1),
        descripcion="SUPERMERCADO LIDER",
        monto=-45000,
        tipo="cargo",
        banco="bci",
        fuente="cartola",
    )
    s.add(t)
    s.commit()

    rows = s.query(Transaction).filter_by(user_id="u1").all()
    assert len(rows) == 1
    assert rows[0].id is not None
    assert rows[0].moneda == "CLP"      # default aplicado
    assert rows[0].tarjeta is None
