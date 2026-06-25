"""Tests for extraer_boleta in extraction_service (Task V1)."""
import pytest
from app.services import extraction_service as ex


def test_extraer_boleta_ok(monkeypatch):
    """Valid receipt → dict with negative monto + category from rules."""
    class _Fake:
        def invoke(self, *_a, **_k):
            return ex.BoletaExtraida(
                es_boleta=True, comercio="LIDER", monto=12990, fecha="2026-06-20", categoria=None
            )

    monkeypatch.setattr(ex, "_extractor_boleta", lambda: _Fake())
    out = ex.extraer_boleta(b"fakebytes", "jpg")
    assert out is not None
    assert out["monto"] == -12990
    assert out["categoria"] == "Supermercado"   # por reglas (LIDER)
    assert out["fecha"] == "2026-06-20"


def test_extraer_boleta_no_es_boleta(monkeypatch):
    """Non-receipt image → None."""
    class _Fake:
        def invoke(self, *_a, **_k):
            return ex.BoletaExtraida(es_boleta=False)

    monkeypatch.setattr(ex, "_extractor_boleta", lambda: _Fake())
    assert ex.extraer_boleta(b"x", "jpg") is None


def test_extraer_boleta_categoria_llm_fallback(monkeypatch):
    """When rules give no match, categoria from LLM is normalized."""
    class _Fake:
        def invoke(self, *_a, **_k):
            return ex.BoletaExtraida(
                es_boleta=True, comercio="COMERCIO DESCONOCIDO XYZ", monto=5000,
                fecha="2026-06-21", categoria="salud"
            )

    monkeypatch.setattr(ex, "_extractor_boleta", lambda: _Fake())
    out = ex.extraer_boleta(b"fakebytes", "png")
    assert out is not None
    assert out["monto"] == -5000
    assert out["categoria"] == "Salud"


def test_extraer_boleta_categoria_defaults_otros(monkeypatch):
    """When neither rules nor LLM match, category is 'Otros'."""
    class _Fake:
        def invoke(self, *_a, **_k):
            return ex.BoletaExtraida(
                es_boleta=True, comercio="MISTERIO S.A.", monto=999,
                fecha="2026-06-22", categoria=None
            )

    monkeypatch.setattr(ex, "_extractor_boleta", lambda: _Fake())
    out = ex.extraer_boleta(b"fakebytes", "jpeg")
    assert out is not None
    assert out["categoria"] == "Otros"
    assert out["comercio"] == "MISTERIO S.A."


def test_extraer_boleta_monto_already_negative(monkeypatch):
    """monto is always forced negative (abs), even if LLM returns positive."""
    class _Fake:
        def invoke(self, *_a, **_k):
            return ex.BoletaExtraida(
                es_boleta=True, comercio="FARMACIA CRUZ VERDE", monto=3500,
                fecha="2026-06-23", categoria=None
            )

    monkeypatch.setattr(ex, "_extractor_boleta", lambda: _Fake())
    out = ex.extraer_boleta(b"img", "jpg")
    assert out is not None
    assert out["monto"] == -3500
    assert out["categoria"] == "Salud"  # reglas detectan farmacia/cruz verde
