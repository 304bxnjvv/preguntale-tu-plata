from app.services.extraction_service import (
    extract_from_text, _map, TxnExtraida, Extraccion,
)


def test_map_signo_a_tipo():
    gasto = _map(TxnExtraida(fecha="2025-06-01", descripcion="LIDER", monto=-45000, banco="BCI"))
    ingreso = _map(TxnExtraida(fecha="2025-06-10", descripcion="SUELDO", monto=2500000, banco="BCI"))
    assert gasto.tipo == "cargo" and gasto.monto == -45000 and gasto.moneda == "CLP"
    assert gasto.banco == "bci"
    assert ingreso.tipo == "abono" and ingreso.monto == 2500000


def test_map_fecha_invalida_devuelve_none():
    assert _map(TxnExtraida(fecha="no-fecha", descripcion="X", monto=-1, banco=None)) is None


def test_extract_from_text_usa_el_llm_mockeado(monkeypatch):
    fake = Extraccion(transacciones=[
        TxnExtraida(fecha="2025-06-01", descripcion="LIDER", monto=-45000, banco="BCI"),
        TxnExtraida(fecha="bad", descripcion="ROTA", monto=-1, banco=None),  # se filtra
    ])

    class FakeLLM:
        def invoke(self, _):
            return fake

    monkeypatch.setattr("app.services.extraction_service._extractor", lambda: FakeLLM())
    txns = extract_from_text("texto cualquiera")
    assert len(txns) == 1  # la de fecha mala se descarta
    assert txns[0].descripcion == "LIDER"


def test_extract_from_text_vacio():
    assert extract_from_text("   ") == []
