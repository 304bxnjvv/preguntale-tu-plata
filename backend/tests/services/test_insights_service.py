"""Tests for app.services.insights_service."""
from datetime import date, timedelta
from unittest.mock import patch

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

import app.db.models  # noqa: F401
from app.db.base import Base
from app.db.models import Transaction
from app.services.insights_service import comparativo_mensual, detectar_suscripciones


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    s = sessionmaker(bind=engine)()
    yield s
    s.close()


def _add(session, user_id, fecha, descripcion, monto, categoria=None):
    session.add(
        Transaction(
            user_id=user_id,
            fecha=fecha,
            descripcion=descripcion,
            monto=monto,
            moneda="CLP",
            tipo="cargo",
            categoria=categoria,
            banco="bci",
            fuente="cartola",
        )
    )
    session.commit()


# ---------------------------------------------------------------------------
# detectar_suscripciones — via categoria
# ---------------------------------------------------------------------------

def test_detecta_suscripcion_por_categoria(session):
    _add(session, "u1", date(2026, 6, 1), "Netflix", -15990, "Suscripciones")
    _add(session, "u1", date(2026, 6, 2), "Supermercado Lider", -45000, "Supermercado")

    result = detectar_suscripciones(session, "u1")
    descs = [i["descripcion"] for i in result["items"]]
    assert "Netflix" in descs
    assert "Supermercado Lider" not in descs
    assert result["total_mensual"] == pytest.approx(15990)


def test_detecta_suscripcion_por_recurrencia_2_meses(session):
    """Mismo descripcion en 2 meses distintos → detectado como suscripción."""
    _add(session, "u1", date(2026, 5, 10), "Spotify", -6990, "Entretención")
    _add(session, "u1", date(2026, 6, 10), "Spotify", -6990, "Entretención")

    result = detectar_suscripciones(session, "u1")
    descs = [i["descripcion"] for i in result["items"]]
    assert "Spotify" in descs


def test_no_detecta_gasto_unico(session):
    """Gasto que aparece solo una vez y no tiene categoría Suscripciones → ignorado."""
    _add(session, "u1", date(2026, 6, 5), "Cine Hoyts", -5000, "Entretención")

    result = detectar_suscripciones(session, "u1")
    assert result["items"] == []
    assert result["total_mensual"] == 0.0


def test_no_detecta_recurrencia_mismo_mes(session):
    """Mismo descripcion dos veces en el mismo mes calendario → NO es recurrencia."""
    _add(session, "u1", date(2026, 6, 1), "DuplPago", -5000, None)
    _add(session, "u1", date(2026, 6, 15), "DuplPago", -5000, None)

    result = detectar_suscripciones(session, "u1")
    # no categoria Suscripciones, only 1 calendar month → not detected
    descs = [i["descripcion"] for i in result["items"]]
    assert "DuplPago" not in descs


def test_recurrencia_monto_similar_tolerancia_10(session):
    """Monto que varía dentro de ±10% → detectado."""
    _add(session, "u1", date(2026, 5, 1), "iCloud", -3990, None)
    _add(session, "u1", date(2026, 6, 1), "iCloud", -3899, None)  # ~2.3% diff

    result = detectar_suscripciones(session, "u1")
    descs = [i["descripcion"] for i in result["items"]]
    assert "iCloud" in descs


def test_recurrencia_monto_muy_distinto_no_detecta(session):
    """Monto que varía más de 10% → NO detectado como recurrencia."""
    _add(session, "u1", date(2026, 5, 1), "PagoVariable", -10000, None)
    _add(session, "u1", date(2026, 6, 1), "PagoVariable", -5000, None)  # 50% diff

    result = detectar_suscripciones(session, "u1")
    descs = [i["descripcion"] for i in result["items"]]
    assert "PagoVariable" not in descs


def test_dedup_por_descripcion_normalizada(session):
    """Descripcion aparece 3 veces en 3 meses → deduplicada a 1 item."""
    for month in [4, 5, 6]:
        _add(session, "u1", date(2026, month, 1), "Disney+", -8990, "Suscripciones")

    result = detectar_suscripciones(session, "u1")
    items = [i for i in result["items"] if i["descripcion"] == "Disney+"]
    assert len(items) == 1


def test_total_mensual_es_suma_de_items(session):
    _add(session, "u1", date(2026, 5, 1), "Netflix", -15990, "Suscripciones")
    _add(session, "u1", date(2026, 6, 1), "Netflix", -15990, "Suscripciones")
    _add(session, "u1", date(2026, 5, 1), "Spotify", -6990, "Suscripciones")
    _add(session, "u1", date(2026, 6, 1), "Spotify", -6990, "Suscripciones")

    result = detectar_suscripciones(session, "u1")
    # Both are deduplicated to 1 each → total = 15990 + 6990 = 22980
    assert result["total_mensual"] == pytest.approx(22980)


def test_aislado_por_user_id(session):
    _add(session, "u1", date(2026, 6, 1), "Netflix", -15990, "Suscripciones")
    result = detectar_suscripciones(session, "u2")
    assert result["items"] == []


# ---------------------------------------------------------------------------
# comparativo_mensual
# ---------------------------------------------------------------------------

def _today_ym():
    today = date.today()
    return today.year, today.month


def _prev_ym():
    today = date.today()
    if today.month == 1:
        return today.year - 1, 12
    return today.year, today.month - 1


def test_comparativo_separa_meses(session):
    y, m = _today_ym()
    py, pm = _prev_ym()

    _add(session, "u1", date(y, m, 1), "Lider", -40000, "Supermercado")
    _add(session, "u1", date(py, pm, 15), "Lider", -30000, "Supermercado")

    result = comparativo_mensual(session, "u1")
    assert result["gastos_actual"] == pytest.approx(40000)
    assert result["gastos_anterior"] == pytest.approx(30000)


def test_comparativo_delta_correcto(session):
    y, m = _today_ym()
    py, pm = _prev_ym()

    _add(session, "u1", date(y, m, 5), "Uber", -12000, "Transporte")
    _add(session, "u1", date(py, pm, 5), "Uber", -10000, "Transporte")

    result = comparativo_mensual(session, "u1")
    assert result["delta"] == pytest.approx(2000)  # 12000 - 10000


def test_comparativo_mes_labels(session):
    y, m = _today_ym()
    py, pm = _prev_ym()

    result = comparativo_mensual(session, "u1")
    assert result["mes_actual"] == f"{y:04d}-{m:02d}"
    assert result["mes_anterior"] == f"{py:04d}-{pm:02d}"


def test_comparativo_sin_gastos_devuelve_ceros(session):
    result = comparativo_mensual(session, "u1")
    assert result["gastos_actual"] == 0.0
    assert result["gastos_anterior"] == 0.0
    assert result["delta"] == 0.0


def test_comparativo_top_cambios_max_3(session):
    y, m = _today_ym()
    py, pm = _prev_ym()

    categorias = ["Comida y delivery", "Transporte", "Supermercado", "Salud"]
    for i, cat in enumerate(categorias):
        _add(session, "u1", date(y, m, i + 1), f"gasto{i}", -(i + 1) * 1000, cat)
        _add(session, "u1", date(py, pm, i + 1), f"gasto{i}", -(i + 1) * 500, cat)

    result = comparativo_mensual(session, "u1")
    assert len(result["top_cambios"]) <= 3


def test_comparativo_ingresos_no_cuentan(session):
    """Ingresos (monto>0) no deben sumarse en los gastos."""
    y, m = _today_ym()
    _add(session, "u1", date(y, m, 1), "Sueldo", 2500000, None)
    _add(session, "u1", date(y, m, 5), "Uber", -12000, "Transporte")

    result = comparativo_mensual(session, "u1")
    assert result["gastos_actual"] == pytest.approx(12000)
