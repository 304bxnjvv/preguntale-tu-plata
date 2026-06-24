# Plan 4 — Ingesta universal con IA — Diseño técnico

**Fecha:** 2026-06-24
**Estado:** Aprobado para implementación (approach validado contra cartolas reales).
**Depende de:** Plans 1-3 (backend + frontend + deploy + LLM en OpenAI).

---

## 1. Resumen

Reemplazar los parsers por banco (frágiles, uno por banco × formato) por **un único
pipeline de ingesta con IA**: el usuario sube un archivo (PDF, CSV o foto) y **gpt-4o-mini**
extrae las transacciones estructuradas, **sin código específico por banco**. Funciona con
cualquier banco, cuenta corriente o tarjeta de crédito, y se adapta solo a cambios de formato.

**Validado:** probado contra cartolas reales de Banco de Chile (28 txns) y Scotiabank
(101 txns) — extracción correcta de fecha, comercio, monto (signo correcto), saltando
pagos/totales/saldos. Costo ~$1,5-6 CLP por cartola.

### Decisiones

| Tema | Elegido |
|------|---------|
| Motor de extracción | **gpt-4o-mini** (OpenAI, ya en el stack) con salida estructurada (Pydantic) |
| Extracción de contenido | PDF → `pdfplumber` (texto); CSV → texto; foto/imagen → visión gpt-4o-mini |
| Endpoint | **`POST /api/v1/transactions/upload`** (universal, sin parámetro `banco`) |
| Parsers por banco | **Eliminados** como ruta principal (los CSV se procesan por el mismo LLM) |
| Límite de subidas | **~20 por mes** por usuario (anti-abuso, no por costo) |
| Confirmación | El backend inserta directo (dedup). El paso "revisar antes de guardar" = mejora UI posterior |

---

## 2. Arquitectura

```
Usuario sube archivo (PDF / CSV / imagen)
        │
        ▼
 detectar tipo por extensión/MIME
        │
        ├─ PDF/CSV  → extraer TEXTO (pdfplumber / decode)
        └─ imagen   → pasar la imagen a gpt-4o-mini (visión)
        │
        ▼
 gpt-4o-mini .with_structured_output(Extraccion)  →  list[TxnExtraida]
        │
        ▼
 mapear a Transaccion (fuente="cartola"/"foto") → dedup → insert_transactions → indexar pgvector
```

**`TxnExtraida`** (salida del LLM): `fecha (YYYY-MM-DD)`, `descripcion`, `monto` (negativo =
gasto/cargo/compra, positivo = ingreso/abono), `banco` (opcional, inferido).

**Prompt del extractor:** instruye extraer TODAS las transacciones reales, normalizar fecha,
inferir el signo (gasto vs ingreso), e IGNORAR pagos de tarjeta (MONTO CANCELADO), totales,
saldos, cupos y comprobantes.

---

## 3. Componentes (backend)

### 3.1 `app/services/extraction_service.py` (nuevo)
- `extract_from_text(texto: str) -> list[Transaccion]` — gpt-4o-mini estructurado sobre texto.
- `extract_from_image(image_bytes: bytes, mime: str) -> list[Transaccion]` — gpt-4o-mini visión.
- `extract_from_pdf(content: bytes) -> list[Transaccion]` — `pdfplumber` → texto → `extract_from_text`. Si el PDF no tiene texto (escaneado) → render a imagen + `extract_from_image` (refinamiento posterior; por ahora soporta PDF con texto).
- `extract_from_csv(content: bytes) -> list[Transaccion]` — decodifica (latin-1/utf-8) → `extract_from_text`.
- Mapea cada `TxnExtraida` a `Transaccion` (tipo "cargo"/"abono" según signo, moneda "CLP",
  banco inferido o "desconocido").
- `temperature=0` para determinismo.

### 3.2 `app/services/upload_limit.py` (nuevo) + tabla `uploads`
- Tabla `uploads (id, user_id, created_at, filename, n_transacciones, fuente)`.
- `check_and_log_upload(session, user_id, filename, n, fuente)`:
  - Cuenta uploads del usuario en el **mes calendario actual**.
  - Si `>= 20` → lanza `UploadLimitError` (el endpoint responde 429).
  - Si no → registra el upload y deja pasar.
- Migración SQL `002_uploads.sql`.

### 3.3 `app/api/routes/upload.py` (modificar)
- Nuevo `POST /api/v1/transactions/upload` (auth):
  - Recibe `file: UploadFile` (PDF/CSV/imagen, detecta por extensión/MIME).
  - Chequea límite (429 si excede).
  - Llama al extractor según tipo → `list[Transaccion]`.
  - Si vacío → 422 "no se detectaron transacciones".
  - `insert_transactions` (dedup) → `indexar_transacciones` (solo las nuevas) → registra upload.
  - Devuelve `UploadResponse` (banco "varios"/inferido, count, mensaje).
- El viejo `upload-csv?banco=` + parsers por banco quedan **deprecados** (se pueden borrar en
  un commit aparte; no son la ruta principal).

---

## 4. Frontend (cambios mínimos)
- `upload_screen.dart`: el `file_picker` acepta ahora **pdf, csv, jpg, png** (no solo csv);
  quita el dropdown de banco (ya no se necesita). Llama a `POST /transactions/upload`.
- `api_service.dart`: `uploadCsv(...)` → renombrar a `uploadFile(bytes, filename)` apuntando a
  `/transactions/upload` (sin `banco`).
- Mensaje de límite: si 429 → "Llegaste al límite de subidas del mes".

---

## 5. Manejo de errores

| Caso | Respuesta |
|------|-----------|
| Límite de subidas alcanzado | 429 + mensaje claro |
| Archivo no soportado | 400 |
| PDF escaneado sin texto | (por ahora) 422 "no pudimos leer; intenta una foto" (visión en refinamiento) |
| LLM no detecta transacciones | 422 |
| LLM falla / timeout OpenAI | 502 + reintentar |

---

## 6. Testing
- **`extraction_service`:** tests con el LLM **mockeado** (no llama a OpenAI en CI) —
  verifican el mapeo `TxnExtraida → Transaccion` (signo, tipo, moneda) y el ruteo por tipo de
  archivo. Fixtures de **texto sanitizado** (inventado, NO las cartolas reales del usuario).
- **`upload_limit`:** test del conteo mensual y el corte en 20 (sqlite in-memory).
- **Endpoint `/transactions/upload`:** test con extractor + límite mockeados (auth override,
  sqlite) — verifica 201 con dedup, 429 al exceder, 422 sin transacciones.
- Suite existente sigue verde.

> Los PDFs reales del usuario (Banco de Chile, Scotiabank) son datos personales: **NO se
> commitean**; se usaron solo para validar localmente. Los fixtures de test son sintéticos.

---

## 7. Fuera de scope (después)
- PDF escaneado (sin capa de texto) → render a imagen + visión.
- Paso "revisar/editar antes de guardar" en la UI (confirmación visual de lo extraído).
- Validar el total extraído contra el total declarado en la cartola (chequeo de confianza).
- Borrar definitivamente los parsers por banco y el endpoint `upload-csv`.
- Categorización automática (otro slice).
