# Chat History + Memoria — Implementation Plan (Plan 5)

> **For agentic workers:** subagent-driven. Pasos con checkbox.

**Goal:** Persistir el chat por usuario y darle memoria conversacional acotada (la IA recuerda los últimos turnos).

**Architecture:** Tabla `chat_messages` (role/content por usuario). `/chat/ask` carga los últimos N mensajes como contexto para el LLM y persiste pregunta+respuesta. `GET /chat/history` devuelve la conversación. Front carga el historial al abrir el chat.

**Tech Stack:** FastAPI + SQLAlchemy 2.0.35 + Supabase Postgres (RLS por user_id) · Flutter/Riverpod.

## Global Constraints
- Memoria acotada a **6 mensajes** (3 turnos) para controlar tokens.
- `chat_messages` con RLS por `user_id`, espejo de `transactions`/`uploads`.
- Filtrado por `user_id` en todas las queries (el backend usa el pooler postgres; la app filtra en código).
- Sin romper el diseño actual del chat (orbe, burbujas, copy chileno).
- `flutter` = `C:\flutter\bin\flutter`. Tests: `pytest` (backend, asyncio_mode=auto), `flutter test` (front).

---

### Task 1: Backend — persistencia + memoria

**Files:**
- Modify: `backend/app/db/models.py` (modelo `ChatMessage`)
- Create: `backend/migrations/003_chat_messages.sql` (espejo de `002_uploads.sql`: tabla + index user_id + RLS)
- Create: `backend/app/db/chat_repo.py` (`save_message`, `get_history`, `get_recent_for_memory`)
- Modify: `backend/app/rag/rag_service.py` (`ask(question, user_id, history=None)` → bloque "Conversación previa" en el PROMPT)
- Modify: `backend/app/api/routes/ask.py` (sesión DB; cargar memoria → ask → guardar user+assistant; nuevo `GET /chat/history`)
- Modify: `backend/app/models/schemas.py` (`ChatMessageOut`)
- Test: `backend/tests/test_chat_history.py`

**Interfaces (Produces):**
- `ChatMessage(id, user_id, role, content, created_at)`
- `save_message(session, user_id, role, content) -> ChatMessage`
- `get_history(session, user_id, limit=100) -> list[ChatMessage]` (asc)
- `get_recent_for_memory(session, user_id, limit=6) -> list[ChatMessage]` (asc)
- `ask(question, user_id, history: list[tuple[str,str]] | None = None) -> AskResponse`
- `GET /chat/history -> list[ChatMessageOut]`

- [ ] Tests: repo guarda/lee ordenado; `ask` incluye historial en el prompt; `/chat/ask` persiste 2 filas; `/chat/history` devuelve en orden. Implementar mínimo. pytest verde. Commit.

---

### Task 2: Frontend — cargar historial al abrir

**Files:**
- Modify: `frontend/lib/services/api_service.dart` (`getChatHistory() -> List<ChatMessage>`)
- Create/Modify: modelo `ChatMessage` (role, content) reutilizando el tipo del chat si existe
- Modify: `frontend/lib/providers/data_providers.dart` (`chatHistoryProvider` FutureProvider)
- Modify: `frontend/lib/screens/chat_screen.dart` (al init carga historial en `_msgs`; tras `ask` el server ya persiste)
- Test: `frontend/test/` (api parsea historial; chat_screen rendea mensajes previos)

- [ ] Tests verdes (`flutter test`), `flutter analyze` limpio. No romper el diseño (orbe/burbujas/copy). Commit.

---

### Post
- Aplicar `003_chat_messages.sql` en Supabase.
- pytest + flutter test verdes → push → deploy Pages.
