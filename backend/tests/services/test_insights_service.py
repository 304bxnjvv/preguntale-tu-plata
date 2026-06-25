"""Tests for app.services.insights_service."""
from datetime import date, timedelta
from unittest.mock import patch

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

import app.db.models  # noqa: F401
from app.db.base import Base
from app.db.models import Transaction
from app.services.insights_service import comparativo_mensual, detectar_suscripciones, calcular_finscore


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


# ---------------------------------------------------------------------------
# calcular_finscore
# ---------------------------------------------------------------------------

def _today_90d():
    """Date 45 days ago — safely within the 90-day window."""
    return date.today() - timedelta(days=45)


def test_finscore_sin_ingresos_devuelve_50(session):
    """Sin transacciones → score=50, nivel='sin datos'."""
    result = calcular_finscore(session, "u1")
    assert result["score"] == 50
    assert result["nivel"] == "sin datos"
    assert result["factores"] == []
    assert "necesito más datos" in result["resumen"].lower()
    assert result["tasa_ahorro"] == 0.0


def test_finscore_ahorro_alto_nivel_vas_bien(session):
    """Ahorra 30% → score alto, nivel 'vas bien'."""
    d = _today_90d()
    _add(session, "u1", d, "Sueldo", 1_000_000, None)    # ingreso
    _add(session, "u1", d, "Gastos", -700_000, "Comida")  # gasto
    # tasa_ahorro = 0.30 → score = clamp(55 + 0.30*130, 5, 99) = clamp(94, …) = 94
    result = calcular_finscore(session, "u1")
    assert result["score"] >= 75
    assert result["nivel"] == "vas bien"
    assert result["tasa_ahorro"] == pytest.approx(0.30)


def test_finscore_gasta_mas_que_ingresa_nivel_alerta(session):
    """Gasta más de lo que ingresa → score bajo, nivel 'alerta'."""
    d = _today_90d()
    _add(session, "u1", d, "Sueldo", 500_000, None)
    _add(session, "u1", d, "Gastos", -700_000, "Comida")  # tasa_ahorro = -0.40
    # score = clamp(55 + (-0.40)*130, 5, 99) = clamp(3, …) = 5
    result = calcular_finscore(session, "u1")
    assert result["score"] < 50
    assert result["nivel"] == "alerta"
    assert result["tasa_ahorro"] < 0


def test_finscore_nivel_ojo_rango_medio(session):
    """Ahorra 0% exacto → score=55, nivel 'ojo'."""
    d = _today_90d()
    _add(session, "u1", d, "Sueldo", 800_000, None)
    _add(session, "u1", d, "Gastos", -800_000, "Comida")  # tasa_ahorro = 0.0
    # score = clamp(55 + 0*130, 5, 99) = 55
    result = calcular_finscore(session, "u1")
    assert 50 <= result["score"] < 75
    assert result["nivel"] == "ojo"


def test_finscore_suscripciones_altas_bajan_score(session):
    """Suscripciones >15% del ingreso restan 8 puntos."""
    d = _today_90d()
    # Ingreso = 100_000; suscripciones = 20_000 (20% > 15%) → -8
    _add(session, "u1", d, "Sueldo", 100_000, None)
    _add(session, "u1", d, "Netflix", -20_000, "Suscripciones")

    # Without subscription penalty
    result = calcular_finscore(session, "u1")

    # gastos=20000, ingresos=100000, tasa_ahorro=0.80
    # base = clamp(55+0.80*130,5,99) = clamp(159,5,99) = 99
    # susc/ingresos = 20000/100000 = 0.20 > 0.15 → -8 → 91
    assert result["score"] == 91
    # Check factores contain a subscription penalty
    signos_negativos = [f for f in result["factores"] if f["signo"] == "-"]
    assert any("suscripci" in f["texto"].lower() for f in signos_negativos)


def test_finscore_suscripciones_bajas_no_penalizan(session):
    """Suscripciones <=15% del ingreso → sin penalización."""
    d = _today_90d()
    _add(session, "u1", d, "Sueldo", 1_000_000, None)
    _add(session, "u1", d, "Netflix", -10_000, "Suscripciones")  # 1% < 15%

    result_sin = calcular_finscore(session, "u1")

    # Base score sin penalización:
    # gastos=10_000, ingresos=1_000_000, tasa_ahorro=0.99
    # clamp(55+0.99*130,5,99)=clamp(183.7,5,99)=99; susc ratio=0.01 → no penalty
    assert result_sin["score"] == 99


def test_finscore_factores_no_vacios_con_datos(session):
    """Con datos reales, factores debe tener al menos 1 elemento."""
    d = _today_90d()
    _add(session, "u1", d, "Sueldo", 500_000, None)
    _add(session, "u1", d, "Gastos", -300_000, "Comida")
    result = calcular_finscore(session, "u1")
    assert len(result["factores"]) >= 1
    for f in result["factores"]:
        assert "texto" in f
        assert f["signo"] in ("+", "-")


def test_finscore_solo_considera_ultimos_90_dias(session):
    """Transacciones fuera de los 90 días no cuentan."""
    old_date = date.today() - timedelta(days=120)
    recent_date = date.today() - timedelta(days=10)

    # Old transactions (outside window) — huge income, big spend
    _add(session, "u1", old_date, "Sueldo antiguo", 10_000_000, None)
    _add(session, "u1", old_date, "Gastos antiguos", -9_000_000, "Comida")

    # Recent transactions (inside window) — good savings
    _add(session, "u1", recent_date, "Sueldo reciente", 1_000_000, None)
    _add(session, "u1", recent_date, "Gastos recientes", -200_000, "Comida")

    result = calcular_finscore(session, "u1")
    # tasa_ahorro should be based only on recent: (1M-200k)/1M = 0.80, not the old ones
    assert result["tasa_ahorro"] == pytest.approx(0.80)


def test_finscore_aislado_por_user_id(session):
    """Datos de otro user no afectan el score."""
    d = _today_90d()
    _add(session, "u2", d, "Sueldo", 1_000_000, None)
    _add(session, "u2", d, "Gastos", -900_000, "Comida")

    result = calcular_finscore(session, "u1")  # u1 has no data
    assert result["score"] == 50
    assert result["nivel"] == "sin datos"


def test_finscore_score_clamped_at_5_minimum(session):
    """Score nunca baja de 5 aunque gaste muchísimo más de lo que ingresa."""
    d = _today_90d()
    _add(session, "u1", d, "Sueldo", 100_000, None)
    _add(session, "u1", d, "Gastos", -1_000_000, "Comida")  # tasa_ahorro = -9.0
    # score = clamp(55 + (-9)*130, 5, 99) = clamp(-1115, 5, 99) = 5
    result = calcular_finscore(session, "u1")
    assert result["score"] == 5


def test_finscore_score_clamped_at_99_maximum(session):
    """Score nunca supera 99 aunque ahorre casi todo."""
    d = _today_90d()
    _add(session, "u1", d, "Sueldo", 1_000_000, None)
    _add(session, "u1", d, "Gastos", -1_000, "Comida")  # tasa_ahorro ≈ 0.999
    result = calcular_finscore(session, "u1")
    assert result["score"] <= 99


def test_finscore_resumen_presente(session):
    """resumen siempre es una cadena no vacía."""
    d = _today_90d()
    _add(session, "u1", d, "Sueldo", 500_000, None)
    _add(session, "u1", d, "Gastos", -250_000, "Comida")
    result = calcular_finscore(session, "u1")
    assert isinstance(result["resumen"], str)
    assert len(result["resumen"]) > 0
