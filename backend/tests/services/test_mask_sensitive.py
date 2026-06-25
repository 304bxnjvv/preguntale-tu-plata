"""Tests for _mask_sensitive in extraction_service."""
import pytest
from app.services.extraction_service import _mask_sensitive


# ── RUT patterns ─────────────────────────────────────────────────────────────

@pytest.mark.parametrize("rut", [
    "12.345.678-9",      # standard format with dots
    "12345678-9",        # without dots
    "1.234.567-K",       # single leading digit, K verifier (upper)
    "1.234.567-k",       # lower-case k verifier
    "9.999.999-0",
])
def test_rut_is_redacted(rut):
    result = _mask_sensitive(f"Cliente RUT {rut} pago en tienda")
    assert "[RUT]" in result, f"Expected [RUT] for input: {rut!r}"
    assert rut not in result, f"RUT should be removed: {rut!r}"


def test_multiple_ruts_all_redacted():
    text = "RUT 12.345.678-9 y también 9.876.543-K en el mismo texto"
    result = _mask_sensitive(text)
    assert result.count("[RUT]") == 2
    assert "12.345.678-9" not in result
    assert "9.876.543-K" not in result


# ── Long digit runs (account/card numbers) ───────────────────────────────────

def test_16_digit_account_redacted():
    text = "Número de cuenta: 1234567890123456 transferencia"
    result = _mask_sensitive(text)
    assert "[CUENTA]" in result
    assert "1234567890123456" not in result


def test_10_digit_run_redacted():
    text = "Referencia 1234567890 boleta"
    result = _mask_sensitive(text)
    assert "[CUENTA]" in result


def test_9_digit_run_not_redacted():
    """9-digit run is below threshold — should NOT be masked."""
    text = "Código 123456789 reserva"
    result = _mask_sensitive(text)
    assert "123456789" in result
    assert "[CUENTA]" not in result


# ── Should NOT touch amounts, dates, or glosas ────────────────────────────────

def test_amounts_not_redacted():
    assert "$45.000" in _mask_sensitive("Pago de $45.000 en Lider")
    assert "$1.200.000" in _mask_sensitive("Sueldo $1.200.000 deposito")


def test_date_not_redacted():
    text = "Fecha 2025-06-01 transacción UBER"
    result = _mask_sensitive(text)
    assert "2025-06-01" in result


def test_short_rut_digits_in_glosa_not_masked():
    """A standalone short number like 'N° 34' is not a RUT and should stay."""
    text = "Boleta N° 34 emisión"
    result = _mask_sensitive(text)
    assert "34" in result


def test_empty_string():
    assert _mask_sensitive("") == ""


def test_no_sensitive_data_unchanged():
    text = "SUPERMERCADO LIDER 2025-06-10 monto -42300 CLP"
    assert _mask_sensitive(text) == text
