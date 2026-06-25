"""
Tests para app/services/categorias.py y la integración en _map (extraction_service).
"""
import pytest
from app.services.categorias import (
    CATEGORIAS,
    categorizar_por_reglas,
    normalizar,
)
from app.services.extraction_service import (
    _map,
    TxnExtraida,
    Extraccion,
    extract_from_text,
)


# ---------------------------------------------------------------------------
# Tests de categorizar_por_reglas
# ---------------------------------------------------------------------------

class TestCategorizarPorReglas:
    def test_rappi_es_comida(self):
        assert categorizar_por_reglas("RAPPI CL 12345") == "Comida y delivery"

    def test_uber_eats_es_comida(self):
        assert categorizar_por_reglas("UBER EATS ORDER") == "Comida y delivery"

    def test_pedidosya_es_comida(self):
        assert categorizar_por_reglas("PEDIDOSYA CL") == "Comida y delivery"

    def test_mcdonalds_es_comida(self):
        assert categorizar_por_reglas("MCDONALD'S LAS CONDES") == "Comida y delivery"

    def test_starbucks_es_comida(self):
        assert categorizar_por_reglas("STARBUCKS PROVIDENCIA") == "Comida y delivery"

    def test_lider_es_supermercado(self):
        assert categorizar_por_reglas("LIDER EXPRESS NUNOA") == "Supermercado"

    def test_jumbo_es_supermercado(self):
        assert categorizar_por_reglas("JUMBO COSTANERA") == "Supermercado"

    def test_santa_isabel_es_supermercado(self):
        assert categorizar_por_reglas("SANTA ISABEL LO BARNECHEA") == "Supermercado"

    def test_tottus_es_supermercado(self):
        assert categorizar_por_reglas("TOTTUS BILBAO") == "Supermercado"

    def test_unimarc_es_supermercado(self):
        assert categorizar_por_reglas("UNIMARC SAN MIGUEL") == "Supermercado"

    def test_acuenta_es_supermercado(self):
        assert categorizar_por_reglas("ACUENTA MAIPÚ") == "Supermercado"

    def test_uber_es_transporte(self):
        assert categorizar_por_reglas("UBER* TRIP") == "Transporte"

    def test_copec_es_transporte(self):
        assert categorizar_por_reglas("COPEC ESTACION") == "Transporte"

    def test_shell_es_transporte(self):
        assert categorizar_por_reglas("SHELL CHILE") == "Transporte"

    def test_latam_es_transporte(self):
        assert categorizar_por_reglas("LATAM AIRLINES") == "Transporte"

    def test_jetsmart_es_transporte(self):
        assert categorizar_por_reglas("JETSMART SCL") == "Transporte"

    def test_autopista_es_transporte(self):
        assert categorizar_por_reglas("AUTOPISTA CENTRAL PEAJE") == "Transporte"

    def test_netflix_es_suscripcion(self):
        assert categorizar_por_reglas("NETFLIX SUSCRIPCION") == "Suscripciones"

    def test_spotify_es_suscripcion(self):
        assert categorizar_por_reglas("SPOTIFY AB") == "Suscripciones"

    def test_disney_es_suscripcion(self):
        assert categorizar_por_reglas("DISNEY PLUS") == "Suscripciones"

    def test_openai_es_suscripcion(self):
        assert categorizar_por_reglas("OPENAI CHATGPT") == "Suscripciones"

    def test_icloud_es_suscripcion(self):
        assert categorizar_por_reglas("APPLE ICLOUD STORAGE") == "Suscripciones"

    def test_enel_es_cuentas(self):
        assert categorizar_por_reglas("ENEL DISTRIBUCION") == "Cuentas y servicios"

    def test_movistar_es_cuentas(self):
        assert categorizar_por_reglas("MOVISTAR CHILE") == "Cuentas y servicios"

    def test_entel_es_cuentas(self):
        assert categorizar_por_reglas("ENTEL PCS") == "Cuentas y servicios"

    def test_farmacia_es_salud(self):
        assert categorizar_por_reglas("FARMACIA CRUZ VERDE") == "Salud"

    def test_salcobrand_es_salud(self):
        assert categorizar_por_reglas("SALCOBRAND VITACURA") == "Salud"

    def test_clinica_es_salud(self):
        assert categorizar_por_reglas("CLINICA LAS CONDES CONSULTA") == "Salud"

    def test_cine_es_entretencion(self):
        assert categorizar_por_reglas("CINEMARK PARQUE ARAUCO") == "Entretención"

    def test_steam_es_entretencion(self):
        assert categorizar_por_reglas("STEAM GAMES PURCHASE") == "Entretención"

    def test_falabella_es_compras(self):
        assert categorizar_por_reglas("FALABELLA TIENDA ONLINE") == "Compras"

    def test_ripley_es_compras(self):
        assert categorizar_por_reglas("RIPLEY S.A.") == "Compras"

    def test_mercadolibre_es_compras(self):
        assert categorizar_por_reglas("MERCADO LIBRE") == "Compras"

    def test_amazon_es_compras(self):
        assert categorizar_por_reglas("AMAZON MARKETPLACE") == "Compras"

    def test_cajero_es_efectivo(self):
        assert categorizar_por_reglas("CAJERO BCI CIUDAD") == "Efectivo"

    def test_giro_es_efectivo(self):
        assert categorizar_por_reglas("GIRO BANCO CHILE") == "Efectivo"

    def test_transferencia_es_transferencias(self):
        assert categorizar_por_reglas("TRANSFERENCIA A JUAN") == "Transferencias"

    def test_traspaso_es_transferencias(self):
        assert categorizar_por_reglas("TRASPASO CTA VISTA") == "Transferencias"

    def test_desconocido_devuelve_none(self):
        assert categorizar_por_reglas("XYZ123 COMERCIO EXTRAÑO") is None

    def test_vacio_devuelve_none(self):
        assert categorizar_por_reglas("") is None

    def test_case_insensitive(self):
        assert categorizar_por_reglas("rappi delivery") == "Comida y delivery"
        assert categorizar_por_reglas("LIDER SUPER") == "Supermercado"

    def test_accent_insensitive(self):
        # "líder" con tilde
        assert categorizar_por_reglas("Líder Express") == "Supermercado"


# ---------------------------------------------------------------------------
# Tests de normalizar
# ---------------------------------------------------------------------------

class TestNormalizar:
    def test_none_devuelve_none(self):
        assert normalizar(None) is None

    def test_junk_devuelve_none(self):
        assert normalizar("xyz_no_existe_zyx") is None

    def test_exact_lowercase(self):
        assert normalizar("comida y delivery") == "Comida y delivery"

    def test_exact_uppercase(self):
        assert normalizar("COMIDA Y DELIVERY") == "Comida y delivery"

    def test_accent_insensitive_full(self):
        # sin tilde en "Entretención"
        assert normalizar("entretencion") == "Entretención"

    def test_alias_comida(self):
        assert normalizar("comida") == "Comida y delivery"

    def test_alias_streaming(self):
        assert normalizar("streaming") == "Suscripciones"

    def test_alias_shopping(self):
        assert normalizar("shopping") == "Compras"

    def test_alias_cash(self):
        assert normalizar("cash") == "Efectivo"

    def test_alias_transfer(self):
        assert normalizar("transfer") == "Transferencias"

    def test_canonical_supermercado(self):
        assert normalizar("Supermercado") == "Supermercado"

    def test_canonical_salud(self):
        assert normalizar("Salud") == "Salud"

    def test_all_categorias_normalizan(self):
        for cat in CATEGORIAS:
            assert normalizar(cat) == cat, f"Falló normalizar({cat!r})"

    def test_mixed_case_accent(self):
        assert normalizar("SUSCRIPCIONES") == "Suscripciones"


# ---------------------------------------------------------------------------
# Tests de _map: categoria nunca es None, reglas ganan sobre LLM
# ---------------------------------------------------------------------------

class TestMapCategoria:
    def test_map_asigna_categoria_por_reglas(self):
        txn = _map(TxnExtraida(
            fecha="2025-06-01", descripcion="RAPPI CL", monto=-5000, banco="BCI"
        ))
        assert txn is not None
        assert txn.categoria == "Comida y delivery"

    def test_map_categoria_nunca_es_none_con_regla(self):
        txn = _map(TxnExtraida(
            fecha="2025-06-01", descripcion="NETFLIX", monto=-15000, banco="BCI"
        ))
        assert txn is not None
        assert txn.categoria is not None

    def test_map_llm_categoria_cuando_no_hay_regla(self):
        # Sin regla, debe usar la categoria del LLM normalizada
        txn = _map(TxnExtraida(
            fecha="2025-06-01",
            descripcion="COMERCIO_RARO_SIN_REGLA",
            monto=-1000,
            banco="BCI",
            categoria="Salud",
        ))
        assert txn is not None
        assert txn.categoria == "Salud"

    def test_map_fallback_otros_cuando_llm_es_none(self):
        txn = _map(TxnExtraida(
            fecha="2025-06-01",
            descripcion="ALGO_TOTALMENTE_DESCONOCIDO_XYZ",
            monto=-1000,
            banco="BCI",
            categoria=None,
        ))
        assert txn is not None
        assert txn.categoria == "Otros"

    def test_map_fallback_otros_cuando_llm_es_junk(self):
        txn = _map(TxnExtraida(
            fecha="2025-06-01",
            descripcion="ALGO_DESCONOCIDO_XYZ",
            monto=-1000,
            banco="BCI",
            categoria="CATEGORIA_INVENTADA_QUE_NO_EXISTE",
        ))
        assert txn is not None
        assert txn.categoria == "Otros"

    def test_map_regla_gana_sobre_llm(self):
        # Descripcion matchea Supermercado pero el LLM dice Transporte — regla gana
        txn = _map(TxnExtraida(
            fecha="2025-06-01",
            descripcion="JUMBO LAS CONDES",
            monto=-50000,
            banco="BCI",
            categoria="Transporte",
        ))
        assert txn is not None
        assert txn.categoria == "Supermercado"

    def test_map_categoria_nunca_es_none_fallback(self):
        """Ningún path de _map debe dejar categoria=None."""
        casos = [
            TxnExtraida(fecha="2025-01-01", descripcion="LIDER", monto=-1, banco=None),
            TxnExtraida(fecha="2025-01-01", descripcion="XYZ RARO", monto=-1, banco=None, categoria=None),
            TxnExtraida(fecha="2025-01-01", descripcion="XYZ RARO", monto=-1, banco=None, categoria="junk"),
            TxnExtraida(fecha="2025-01-01", descripcion="XYZ RARO", monto=-1, banco=None, categoria="Salud"),
        ]
        for caso in casos:
            txn = _map(caso)
            assert txn is not None
            assert txn.categoria is not None, f"categoria es None para {caso.descripcion!r}"


# ---------------------------------------------------------------------------
# Test de integración: extract_from_text con LLM mockeado
# ---------------------------------------------------------------------------

def test_extract_from_text_categoria_correcta(monkeypatch):
    """El extractor completo debe setear categoria siempre."""
    fake = Extraccion(transacciones=[
        TxnExtraida(fecha="2025-06-01", descripcion="RAPPI DELIVERY", monto=-5000,
                    banco="BCI", categoria="Comida y delivery"),
        TxnExtraida(fecha="2025-06-02", descripcion="COMERCIO_RARO_XYZ", monto=-2000,
                    banco="BCI", categoria="Otros"),
        TxnExtraida(fecha="2025-06-03", descripcion="COMERCIO_SIN_CATEG", monto=-3000,
                    banco="BCI", categoria=None),
    ])

    class FakeLLM:
        def invoke(self, _):
            return fake

    monkeypatch.setattr("app.services.extraction_service._extractor", lambda: FakeLLM())
    txns = extract_from_text("texto cualquiera")

    assert len(txns) == 3
    assert all(t.categoria is not None for t in txns)
    # RAPPI → regla gana incluso si LLM ya dijo Comida y delivery
    rappi = next(t for t in txns if "RAPPI" in t.descripcion)
    assert rappi.categoria == "Comida y delivery"
    # Sin categoría LLM → fallback "Otros"
    sin_cat = next(t for t in txns if "SIN_CATEG" in t.descripcion)
    assert sin_cat.categoria == "Otros"
