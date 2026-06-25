# Presupuestos + Metas, Alertas, y Categorización que aprende — Design (2026-06-25)

Tres features del gap analysis internacional (#1, #2, #5 de `docs/investigacion/2026-06-25-comparacion-internacional.md`).
Un solo esfuerzo, tres grupos independientes y testeables por separado.

**Decisiones del usuario (aprobadas):**
- Alertas: **in-app feed + notificación local móvil** (no FCM/push real por ahora).
- Presupuestos: **topes por categoría** (no YNAB base-cero).
- Metas de ahorro: **incluidas en este plan**.
- Categorización que aprende: **futuras + recategorizar pasadas** (sin pisar correcciones manuales).

**Stack:** FastAPI + SQLAlchemy 2.0 + Supabase Postgres (migraciones psycopg2). Flutter + Riverpod + go_router + fl_chart.

**Orden de construcción:** C (categorización) → A (presupuestos+metas) → B (alertas, usa topes de A).

---

## Constraints globales
- Mobile-first, español chileno, tono cálido, mensajes cortos.
- Montos con `formatCLP` ("$1.234.567"). Categorías = las 11 de `app/services/categorias.py` (`CATEGORIAS`).
- Tests con LLM mockeado / fixtures sintéticos. Nunca datos personales reales en tests ni en el repo.
- No romper flujos existentes (upload, límite, dedup, RAG, tarjeta).
- Migraciones aplicadas a Supabase vía script psycopg2 (`POSTGRES_URL` del `.env`), igual que 003-005.

---

## A) Presupuestos + Metas

### Datos
- Tabla `presupuestos`: `id, user_id, categoria, monto_tope (Numeric), created_at, updated_at`. UNIQUE(`user_id`, `categoria`).
- Tabla `metas`: `id, user_id, nombre, monto_objetivo (Numeric), monto_actual (Numeric default 0), fecha_objetivo (Date nullable), created_at, updated_at`.

### Backend
- `presupuesto_service`:
  - `set_tope(session, user_id, categoria, monto_tope) -> dict` (UPSERT; valida categoria ∈ CATEGORIAS).
  - `delete_tope(session, user_id, categoria) -> bool`.
  - `estado_presupuestos(session, user_id) -> list[dict]`: para cada tope, `gastado` = Σ monto de transactions del **mes actual** (tipo gasto, esa categoría), `pct` = gastado/tope, `estado` ∈ {`ok` (<0.8), `cerca` (0.8–1.0), `excedido` (>1.0)}.
- `meta_service`:
  - `crear_meta`, `actualizar_meta` (nombre/objetivo/actual/fecha), `eliminar_meta`, `listar_metas(session, user_id) -> list[dict]`. Cada meta: `progreso` = actual/objetivo (clamp 0–1), `aporte_mensual_necesario` = `(objetivo-actual)/meses_restantes` si hay `fecha_objetivo` y meses>0, si no `null`.
- Endpoints: `GET/POST /presupuestos`, `DELETE /presupuestos/{categoria}`; `GET/POST /metas`, `PATCH/DELETE /metas/{id}`.
- Chat: `_build_resumen_block` inyecta presupuestos en estado `cerca`/`excedido` y metas con su progreso.

### Front
- `models/presupuesto.dart`, `models/meta.dart` + fromJson; métodos en `api_service`; `presupuestosProvider`, `metasProvider` (en `_refrescarDatos`).
- Pantalla `/presupuestos`: lista de categorías con barra de progreso (salvia <0.8, ámbar 0.8–1, salmón >1) + bottom sheet para fijar/editar/borrar tope.
- Pantalla `/metas`: lista con barra de progreso + "necesitas $X/mes"; bottom sheet crear/editar/borrar; editar `monto_actual`.
- Dashboard: card "Presupuestos" (resumen: N cerca/excedidas → push a `/presupuestos`) y card "Metas" (progreso → push a `/metas`).

---

## B) Alertas

### Backend (sin tabla nueva, sin scheduler)
- `alertas_service.evaluar_alertas(session, user_id) -> list[dict]`. Cada alerta: `{key, tipo, severidad ('urgent'|'warning'|'info'), titulo, detalle, fecha}`. Reglas:
  - `tarjeta_vence` (urgent): `TarjetaEstado.fecha_vencimiento` ≤ 5 días → "Tu tarjeta vence en N días, debes pagar $X".
  - `presupuesto` (warning): por cada presupuesto `cerca`/`excedido` → "Vas en P% de tu presupuesto de {categoria}".
  - `cuotas_proximo_mes` (warning): `comprometido_proximo_mes` > 0 → "El próximo mes te llegan $Y en cuotas".
  - `gasto_inusual` (info): gasto de los últimos 7 días con `monto` > 3× la mediana de gastos de los últimos 90 días **y** > $50.000 → "Gasto grande: $Z en {desc}".
  - `key` determinístico (ej. `f"tarjeta_vence:{fecha}"`, `f"presupuesto:{categoria}"`, `f"gasto:{txn_id}"`) para dedup y "leído" client-side.
- Endpoint `GET /alertas`.

### Front
- 🔔 Campana en app bar del dashboard con badge = nº de alertas cuya `key` no está en el set "vistas" (persistido local con `shared_preferences`). Tap a `/alertas` marca todas como vistas.
- Pantalla `/alertas`: lista de tarjetas, color por severidad (urgent=salmón, warning=ámbar, info=índigo/salvia). Vacío → estado "todo en orden".
- `alertasProvider` (en `_refrescarDatos`).
- **Notificación local** (`flutter_local_notifications`, solo `!kIsWeb`): al refrescar tarjeta, agenda una notif local para `fecha_vencimiento − 3 días`. Cancela/reagenda si cambia. Setup Android (canal) + permiso iOS. En web es no-op.

---

## C) Categorización que aprende

### Datos
- Tabla `categoria_overrides`: `id, user_id, comercio_key, categoria, created_at, updated_at`. UNIQUE(`user_id`, `comercio_key`).
- Columna `transactions.categoria_manual` (Boolean, default False).

### Backend
- `categorias.comercio_key(descripcion) -> str`: strip accents, lower, quita dígitos y puntuación, colapsa espacios, trim. ("UBER EATS *1234 STGO" → "uber eats stgo"). Match de override: `override.comercio_key` es substring del `comercio_key` de la txn nueva.
- `categoria_override_service`:
  - `get_override(session, user_id, descripcion) -> str | None`.
  - `upsert_override(session, user_id, comercio_key, categoria)`.
- Pipeline de categorización (donde hoy se aplica reglas+LLM): **1) override → 2) reglas → 3) LLM → 4) "Otros"**. Nunca recategoriza una txn con `categoria_manual=True`.
- `PATCH /transactions/{id}` `{categoria}`:
  1. valida categoria ∈ CATEGORIAS y ownership; set `categoria`, `categoria_manual=True`.
  2. `upsert_override(comercio_key(desc), categoria)`.
  3. recategoriza las txns del user con mismo `comercio_key` match y `categoria_manual=False` → categoria.
  - Devuelve `{actualizadas: N}`.

### Front
- En Movimientos, tap a una transacción → bottom sheet con chips de las 11 categorías (resalta la actual) → `editarCategoria(id, categoria)` → refresca `summary`, dona, `transactions`.
- `api_service.editarCategoria(id, categoria)`.

---

## Migraciones
- `006_presupuestos_metas.sql`: tablas `presupuestos` + `metas` (RLS por user_id como las demás).
- `007_categoria_override.sql`: tabla `categoria_overrides` + `ALTER TABLE transactions ADD COLUMN categoria_manual boolean NOT NULL DEFAULT false`.

## Post
Aplicar migraciones → `pytest` (backend) + `flutter test` + `flutter analyze` → deploy HF + Pages. Validación real: usuario fija topes, corrige categorías, revisa la campana.
