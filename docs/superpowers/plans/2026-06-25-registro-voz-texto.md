# Registro por voz/texto en el chat (Plan 11)

**Goal:** El usuario escribe (o dicta) "gasté 5 lucas en almuerzo" en el chat y se registra como transacción del día, con confirmación cálida. Construye el hábito diario sin subir cartola.

## Diseño
El chat distingue dos intenciones: **registrar** un gasto/ingreso vs **preguntar**. Si registra → inserta transacción (fecha=hoy) + confirma. Si pregunta → RAG normal (actual).
- Chilenismos de monto: "luca"=$1.000, "5 lucas"=$5.000, "palo"/"melón"=$1.000.000, "gamba"=$100, "quina"=$500, "medio palo"=$500.000.

### Task 1 — Backend
- `app/services/chat_logger.py`: `clasificar_y_extraer(mensaje: str) -> dict | None` — UNA llamada gpt-4o-mini estructurada que devuelve `None` si es pregunta, o `{tipo: "gasto"|"ingreso", monto: float (positivo), descripcion: str, categoria: str}` si es un registro. El prompt entiende chilenismos de monto y usa la taxonomía de `categorias.py`. (Reglas de `categorizar_por_reglas` como respaldo/normalización de la categoría.)
- `app/api/routes/ask.py`: en `POST /chat/ask`, antes del RAG, llamar `clasificar_y_extraer`. Si devuelve registro → construir `Transaccion` (monto negativo si gasto, positivo si ingreso; fecha=hoy; banco="manual"; fuente="manual"), `insert_transactions` + `indexar_transacciones`, y responder `AskResponse(answer=confirmación cálida chilena ej "listo, anoté $5.000 en almuerzo 🍽️ (Comida y delivery)", citations=[])`. Guardar el intercambio en el historial igual. Si `None` → flujo RAG actual.
- Tests: "gasté 5 lucas en almuerzo" → inserta gasto $5.000 categoría Comida y delivery + confirma; "me llegaron 800 lucas de sueldo" → ingreso $800.000; "¿cuánto gasté este mes?" → NO inserta, va a RAG (mock LLM). pytest verde.

### Task 2 — Frontend
- **Refresh:** tras cada mensaje del chat, invalidar `summaryProvider`/`transactionsProvider`/`suscripcionesProvider` (por si fue un registro, que aparezca al tiro en el dashboard).
- **Hint:** en el empty state del chat, agregar ejemplo "o anota un gasto: 'gasté 5 lucas en almuerzo'".
- **Voz (mic):** botón de micrófono en el input del chat usando `speech_to_text` (agregar al pubspec). DEFENSIVO: inicializar en try/catch; si no está disponible (ej. web sin soporte), ocultar el botón — NUNCA romper el build web. Al dictar, llena el TextField (no envía solo).
- Tests + analyze verdes; no romper diseño.

## Post
pytest + flutter test → deploy HF + Pages.
