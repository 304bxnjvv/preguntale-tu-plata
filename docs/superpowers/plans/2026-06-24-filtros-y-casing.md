# Filtros de dashboard + casing profesional (Plan 6)

**Goal:** Filtrar el dashboard por rango de tiempo (24h/3/7/15/30 días) y por tipo (ingresos/gastos/ambos); y subir el casing de la UI a profesional (chat mantiene su voz minúscula).

## Contrato de API
- `GET /transactions/summary?dias={int?}&tipo={ingreso|gasto?}` — filtra por `fecha >= hoy - dias`. `por_moneda` siempre trae gastos+ingresos del período; `gastos_por_banco`/`gastos_por_categoria` agregan el lado indicado por `tipo` (default = gastos). Respuesta con las MISMAS keys.
- `GET /transactions?dias={int?}&tipo={ingreso|gasto?}&limit&offset` — `tipo=ingreso`→monto≥0; `gasto`→monto<0; ambos→todo. + filtro fecha.
- `dias` ∈ {1,3,7,15,30} en la práctica (validar `ge=1,le=366`). `tipo` ∈ {ingreso,gasto}.

### Task 1 — Backend (filtros)
- `transaction_service.py`: `get_summary(session, user_id, desde: date|None=None, tipo: str|None=None)` y `list_transactions(..., desde=None, tipo=None)`. Filtrar por fecha y tipo.
- `upload.py`: rutas `/transactions` y `/transactions/summary` agregan `dias: int|None` + `tipo: str|None` (Query, validados), computan `desde = date.today() - timedelta(days=dias)` y pasan a service.
- Tests: summary con `desde` excluye viejas; `tipo=ingreso` hace por_banco sobre ingresos; lista filtra por tipo+fecha. `python -m pytest` verde.

### Task 2 — Frontend (filtros + casing)
- `dashboard_filter.dart`: `DashboardFilter{ int? dias; String? tipo; }` + `dashboardFilterProvider` (StateProvider).
- `api_service.dart`: `getSummary({int? dias, String? tipo})`, `getTransactions({int? dias, String? tipo})` (query params).
- `data_providers.dart`: `summaryProvider`/`transactionsProvider` observan `dashboardFilterProvider` y refetch.
- `dashboard_screen.dart`: barra de filtros arriba — chips de tiempo (24h/3d/7d/15d/30d) + segmented ingresos/gastos/ambos. Default: 30 días, ambos.
- **Casing profesional:** labels, títulos de sección, botones, datos (bancos, categorías) en Mayúscula/sentence case; `desconocido`→`Desconocido`. La voz minúscula SOLO queda en las burbujas del chat + su copy de bienvenida/empty/error.
- Tests verdes (`C:\flutter\bin\flutter test`), `analyze` limpio. No romper el diseño (orbe/paleta/tipografías).

## Post
pytest + flutter test verdes → deploy backend (HF) + frontend (Pages).
