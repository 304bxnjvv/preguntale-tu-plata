# Categorización automática + dona por categoría (Plan 7)

**Goal:** Toda transacción queda categorizada (LLM en la extracción + reglas por comercio CL); la dona del dashboard pasa de "Por banco" a "Por categoría". Backfill de lo existente.

**Taxonomía fija (11):** Comida y delivery · Supermercado · Transporte · Cuentas y servicios · Suscripciones · Salud · Entretención · Compras · Efectivo · Transferencias · Otros.

### Task 1 — Backend (categorización)
- `app/services/categorias.py`: `CATEGORIAS` (lista fija); `categorizar_por_reglas(desc) -> str|None` (mapa de keywords de comercios chilenos: rappi/uber eats→Comida; lider/jumbo/tottus→Supermercado; uber/copec/metro→Transporte; enel/entel/movistar→Cuentas y servicios; netflix/spotify/openai→Suscripciones; farmacia/cruz verde→Salud; cine/steam→Entretención; falabella/mercadolibre/sodimac→Compras; giro/cajero→Efectivo; transferencia/transf→Transferencias); `normalizar(cat) -> str|None` (mapea salida del LLM a la taxonomía).
- `app/services/extraction_service.py`: `TxnExtraida` gana `categoria: str|None`; el `_PROMPT` instruye elegir UNA categoría de la lista. En `_map`: `categoria = categorizar_por_reglas(desc) or normalizar(t.categoria) or "Otros"` (nunca null).
- `scripts/backfill_categorias.py`: conecta a la DB (lee `.env`), aplica reglas a las filas con categoría vacía; para las no resueltas hace UNA llamada LLM batch sobre descripciones únicas; actualiza filas. (Se corre una vez.)
- Tests: reglas mapean comercios; `_map` siempre setea categoría; `normalizar` ok. `python -m pytest` verde.

### Task 2 — Frontend (dona por categoría)
- `lib/widgets/gastos_dona.dart`: cambia `porBanco: List<BancoTotal>` → `porCategoria: List<CategoriaTotal>`; label "Por categoría"; leyenda usa `.categoria`.
- `lib/screens/dashboard_screen.dart`: `GastosDona(porCategoria: s.gastosPorCategoria)`.
- (Modelo `Summary.gastosPorCategoria` ya existe.)
- Tests verdes (`C:\flutter\bin\flutter test`) + `analyze` limpio. No romper diseño.

## Post
Correr backfill → pytest + flutter test verdes → deploy backend (HF) + frontend (Pages).
