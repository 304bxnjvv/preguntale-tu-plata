"""Tests for extraer_estado_tarjeta in extraction_service."""
import pytest
from app.services.extraction_service import (
    extraer_estado_tarjeta,
    EstadoTarjeta,
    CuotaPendiente,
    _extractor_tarjeta,
)


class _FakeLLMTarjeta:
    """Returns a fixed EstadoTarjeta on invoke."""

    def __init__(self, result: EstadoTarjeta):
        self._result = result

    def invoke(self, _):
        return self._result


def _estado_tarjeta_valido() -> EstadoTarjeta:
    return EstadoTarjeta(
        es_tarjeta=True,
        total_a_pagar=230000.0,
        monto_minimo=23000.0,
        fecha_vencimiento="2026-07-10",
        cupo_total=900000.0,
        cupo_utilizado=350000.0,
        cuotas_pendientes=[
            CuotaPendiente(descripcion="TV Samsung", valor_cuota=42000.0, cuotas_restantes=4),
        ],
    )


def _fake_pdf_bytes() -> bytes:
    """Minimal bytes that pdfplumber can open (single empty PDF page)."""
    # Minimal valid PDF with one empty page
    return (
        b"%PDF-1.4\n"
        b"1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n"
        b"2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n"
        b"3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]>>endobj\n"
        b"xref\n0 4\n"
        b"0000000000 65535 f\r\n"
        b"0000000009 00000 n\r\n"
        b"0000000058 00000 n\r\n"
        b"0000000115 00000 n\r\n"
        b"trailer<</Size 4/Root 1 0 R>>\n"
        b"startxref\n190\n%%EOF"
    )


def test_extraccion_tarjeta_returns_none_si_es_tarjeta_false(monkeypatch):
    fake = EstadoTarjeta(es_tarjeta=False)
    monkeypatch.setattr(
        "app.services.extraction_service._extractor_tarjeta",
        lambda: _FakeLLMTarjeta(fake),
    )
    result = extraer_estado_tarjeta(_fake_pdf_bytes(), "estado_cuenta.pdf")
    assert result is None


def test_extraccion_tarjeta_returns_dict_si_es_tarjeta_true(monkeypatch):
    fake = _estado_tarjeta_valido()
    monkeypatch.setattr(
        "app.services.extraction_service._extractor_tarjeta",
        lambda: _FakeLLMTarjeta(fake),
    )
    result = extraer_estado_tarjeta(_fake_pdf_bytes(), "estado_cuenta.pdf")
    assert isinstance(result, dict)
    assert result["total_a_pagar"] == pytest.approx(230000.0)
    assert result["fecha_vencimiento"] == "2026-07-10"
    assert len(result["cuotas_pendientes"]) == 1
    assert result["cuotas_pendientes"][0]["descripcion"] == "TV Samsung"
    assert result["cuotas_pendientes"][0]["cuotas_restantes"] == 4


def test_extraccion_tarjeta_returns_none_para_no_pdf(monkeypatch):
    """Non-PDF files should return None immediately (no LLM call)."""
    called = []
    monkeypatch.setattr(
        "app.services.extraction_service._extractor_tarjeta",
        lambda: (_ for _ in ()).throw(AssertionError("should not be called")),
    )
    result = extraer_estado_tarjeta(b"nombre,monto\nLider,-45000", "cartola.csv")
    assert result is None


def test_extraccion_tarjeta_campos_cuota(monkeypatch):
    """Verifies cuotas_pendientes list is returned correctly."""
    fake = EstadoTarjeta(
        es_tarjeta=True,
        total_a_pagar=100000.0,
        cuotas_pendientes=[
            CuotaPendiente(descripcion="Laptop HP", valor_cuota=55000.0, cuotas_restantes=9),
            CuotaPendiente(descripcion="Celular", valor_cuota=20000.0, cuotas_restantes=2),
        ],
    )
    monkeypatch.setattr(
        "app.services.extraction_service._extractor_tarjeta",
        lambda: _FakeLLMTarjeta(fake),
    )
    result = extraer_estado_tarjeta(_fake_pdf_bytes(), "tarjeta.pdf")
    assert result is not None
    assert len(result["cuotas_pendientes"]) == 2
    assert result["cuotas_pendientes"][1]["valor_cuota"] == pytest.approx(20000.0)
