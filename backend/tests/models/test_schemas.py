import uuid
from datetime import date
from app.models.schemas import TransactionOut


def test_transactionout_coerces_uuid_id_to_str():
    """En Postgres el id es UUID (psycopg2 devuelve uuid.UUID); debe serializar a str."""

    class Row:
        id = uuid.uuid4()
        fecha = date(2025, 6, 1)
        descripcion = "LIDER"
        monto = -45000.0
        moneda = "CLP"
        tarjeta = None
        tipo = "cargo"
        categoria = None
        banco = "bci"
        fuente = "cartola"

    out = TransactionOut.model_validate(Row())
    assert isinstance(out.id, str)
    assert out.id == str(Row.id)
