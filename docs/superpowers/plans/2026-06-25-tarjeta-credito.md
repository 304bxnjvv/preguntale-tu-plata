# Leer estado de cuenta de tarjeta de crédito (Plan 13)

**Goal:** Al subir el PDF de la tarjeta, detectar que es un estado de cuenta y mostrar: total a pagar, fecha de vencimiento, y "comprometido próximo mes" (suma de la próxima cuota de cada compra en cuotas).

## Contrato API
- `GET /insights/tarjeta` → `{tiene_datos: bool, total_a_pagar: float, monto_minimo: float, fecha_vencimiento: str|null (ISO), cupo_total: float, cupo_utilizado: float, comprometido_proximo_mes: float, cuotas: [{descripcion, valor_cuota, cuotas_restantes}]}`

### Task 1 — Backend
- `app/services/extraction_service.py`: nueva `extraer_estado_tarjeta(content: bytes, filename: str) -> dict | None`. SOLO para PDF: pdfplumber→texto→`_mask_sensitive`→gpt-4o-mini `.with_structured_output(EstadoTarjeta)`. `EstadoTarjeta`: `es_tarjeta: bool`, `total_a_pagar: float=0`, `monto_minimo: float=0`, `fecha_vencimiento: str|None`, `cupo_total: float=0`, `cupo_utilizado: float=0`, `cuotas_pendientes: list[{descripcion, valor_cuota, cuotas_restantes}]`. Devuelve None si `es_tarjeta` False. Prompt: detecta estados de cuenta de tarjeta de crédito chilena (Banco de Chile, Scotiabank, etc.), extrae "monto a pagar"/"total facturado", "fecha de pago"/"vencimiento", "cupo", y las compras en cuotas ("3 de 12" → cuotas_restantes=9, valor_cuota=el valor mensual).
- Modelo `TarjetaEstado` (user_id UNIQUE, total_a_pagar, monto_minimo, fecha_vencimiento Date, cupo_total, cupo_utilizado, cuotas Text(JSON), comprometido_proximo_mes, created_at) + migración `005_tarjeta_estado.sql` (RLS por user_id).
- `app/services/tarjeta_service.py`: `guardar_estado(session, user_id, dict)` (UPSERT por user_id; calcula `comprometido_proximo_mes = sum(valor_cuota for c in cuotas_pendientes)`); `get_estado(session, user_id) -> dict` (tiene_datos False si no hay).
- `routes/upload.py`: tras insertar transacciones, si el archivo es PDF, llamar `extraer_estado_tarjeta`; si no es None → `guardar_estado`. No romper el flujo actual (límite/422/dedup).
- `routes/insights.py`: `GET /insights/tarjeta`.
- `rag_service`/`_build_resumen_block`: inyectar el resumen de tarjeta (total a pagar + vencimiento + comprometido) para que el chat responda "¿cuánto debo de la tarjeta?".
- Tests (mock LLM): detecta tarjeta y guarda; no-tarjeta → None; comprometido = suma de cuotas; endpoint 200; upsert reemplaza. pytest verde.

### Task 2 — Frontend
- `models/tarjeta.dart` (TarjetaEstado + Cuota + fromJson), `getTarjeta()` en api_service, `tarjetaProvider`.
- `widgets/tarjeta_card.dart`: glass card "Tu tarjeta de crédito" — **total a pagar** grande (`formatCLP`, salmón) + "antes del [fecha_vencimiento]" + línea "comprometido próximo mes: $X" (ámbar) + barra de cupo (cupo_utilizado/cupo_total) si hay datos. Si `tiene_datos` false → SizedBox.shrink.
- `dashboard_screen.dart`: insertar `TarjetaCard` (cerca del resumen). Incluir `tarjetaProvider` en `_refrescarDatos`.
- Tests + analyze verdes; no romper diseño.

## Post
Aplicar migración 005 → pytest + flutter test → deploy HF + Pages. (Validación real: usuario sube su PDF de tarjeta.)
