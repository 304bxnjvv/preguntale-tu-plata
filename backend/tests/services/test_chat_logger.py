"""Tests for app.services.chat_logger — written BEFORE production code (TDD RED phase).

Covers:
- clasificar_y_extraer returns None for questions (no registro)
- clasificar_y_extraer returns dict with correct fields for gasto (lucas slang)
- clasificar_y_extraer returns dict with correct fields for ingreso (lucas slang)
- monto conversion: lucas→miles, palo/melón→millón, gamba→100, quina→500
"""
import pytest
from unittest.mock import MagicMock
from app.services.chat_logger import RegistroChat, clasificar_y_extraer


# ── helpers ─────────────────────────────────────────────────────────────────

def _fake_clasificador(es_registro: bool, tipo: str = "gasto", monto: float = 0.0,
                       descripcion: str = "", categoria: str = "Otros"):
    """Build a fake LLM that returns a RegistroChat with the given values."""
    class FakeLLM:
        def invoke(self, _prompt):
            return RegistroChat(
                es_registro=es_registro,
                tipo=tipo,
                monto=monto,
                descripcion=descripcion,
                categoria=categoria,
            )
    return FakeLLM()


# ── tests ────────────────────────────────────────────────────────────────────

def test_clasificar_pregunta_devuelve_none(monkeypatch):
    """A question like '¿cuánto gasté este mes?' should return None (no registro)."""
    monkeypatch.setattr(
        "app.services.chat_logger._clasificador",
        lambda: _fake_clasificador(es_registro=False),
    )
    result = clasificar_y_extraer("¿cuánto gasté este mes?")
    assert result is None


def test_clasificar_gasto_lucas(monkeypatch):
    """'gasté 5 lucas en almuerzo' → gasto 5000, descripcion almuerzo, categoria Comida."""
    monkeypatch.setattr(
        "app.services.chat_logger._clasificador",
        lambda: _fake_clasificador(
            es_registro=True,
            tipo="gasto",
            monto=5000.0,
            descripcion="almuerzo",
            categoria="Comida y delivery",
        ),
    )
    result = clasificar_y_extraer("gasté 5 lucas en almuerzo")
    assert result is not None
    assert result["tipo"] == "gasto"
    assert result["monto"] == 5000.0
    assert result["descripcion"] == "almuerzo"
    assert result["categoria"] == "Comida y delivery"


def test_clasificar_ingreso_lucas(monkeypatch):
    """'me llegaron 800 lucas de sueldo' → ingreso 800000."""
    monkeypatch.setattr(
        "app.services.chat_logger._clasificador",
        lambda: _fake_clasificador(
            es_registro=True,
            tipo="ingreso",
            monto=800000.0,
            descripcion="sueldo",
            categoria="Otros",
        ),
    )
    result = clasificar_y_extraer("me llegaron 800 lucas de sueldo")
    assert result is not None
    assert result["tipo"] == "ingreso"
    assert result["monto"] == 800000.0


def test_clasificar_gamba(monkeypatch):
    """'pagué una gamba por el pasaje' → gasto 100."""
    monkeypatch.setattr(
        "app.services.chat_logger._clasificador",
        lambda: _fake_clasificador(
            es_registro=True,
            tipo="gasto",
            monto=100.0,
            descripcion="pasaje",
            categoria="Transporte",
        ),
    )
    result = clasificar_y_extraer("pagué una gamba por el pasaje")
    assert result is not None
    assert result["monto"] == 100.0


def test_clasificar_palo(monkeypatch):
    """'gasté un palo en el auto' → gasto 1000000."""
    monkeypatch.setattr(
        "app.services.chat_logger._clasificador",
        lambda: _fake_clasificador(
            es_registro=True,
            tipo="gasto",
            monto=1_000_000.0,
            descripcion="auto",
            categoria="Compras",
        ),
    )
    result = clasificar_y_extraer("gasté un palo en el auto")
    assert result is not None
    assert result["monto"] == 1_000_000.0


def test_clasificar_resultado_es_registro_false_devuelve_none(monkeypatch):
    """When the LLM says es_registro=False, return None even if monto is populated."""
    monkeypatch.setattr(
        "app.services.chat_logger._clasificador",
        lambda: _fake_clasificador(
            es_registro=False,
            tipo="gasto",
            monto=999.0,
            descripcion="algo",
            categoria="Otros",
        ),
    )
    result = clasificar_y_extraer("¿cuánto gané este año?")
    assert result is None
