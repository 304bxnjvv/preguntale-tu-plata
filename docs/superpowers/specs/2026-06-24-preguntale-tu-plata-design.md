# Pregúntale a tu plata — Diseño técnico

**Fecha:** 2026-06-24
**Estado:** Aprobado para implementación
**Autor:** Benjamín Rodríguez

---

## 1. Resumen

App **mobile-first** de finanzas personales para usuarios chilenos. El usuario se
registra, sube cartolas bancarias (CSV) de uno o más bancos y/o fotos de boletas, y le
pregunta a un chat IA sobre sus propios gastos (RAG). Cada usuario ve únicamente sus
datos.

**Objetivo de portafolio:** demostrar Flutter (mobile + web), backend Python/FastAPI,
auth multi-usuario, RAG y visión por IA — apuntando a roles Full Stack Mobile / fintech
en Chile.

### Decisiones base

| Decisión | Elegido |
|----------|---------|
| Autenticación | Supabase Auth; datos aislados por `user_id` |
| OCR de fotos | Gemini Flash visión (key gratis nueva) |
| Embeddings | sentence-transformers local (gratis, offline, multilingüe) |
| Bancos | Multi-banco; se elige al subir cada cartola |
| Plataforma | Mobile-first, web para demo en entrevistas |
| Fuente de verdad | Tabla `transactions` en Postgres + pgvector solo para RAG |

---

## 2. Arquitectura

```
┌─────────────────────────┐
│   Flutter (mobile-first) │  login · dashboard · subir cartola · foto boleta · chat
└───────────┬─────────────┘
            │ HTTPS + JWT (Authorization: Bearer)
┌───────────▼─────────────┐
│      FastAPI backend     │  valida JWT · parsers · servicios
└───────────┬─────────────┘
            │
┌───────────▼──────────────────────────────────┐
│   Supabase                                    │
│   ├─ Auth (usuarios + JWT)                     │
│   ├─ Postgres: tabla `transactions` (verdad)  │
│   └─ pgvector: embeddings (índice RAG)         │
└────────────────────────────────────────────────┘

LLMs / modelos:
  · DeepSeek               → chat / RAG (deepseek-chat)
  · Gemini Flash           → leer fotos de boletas (visión → JSON)
  · sentence-transformers  → embeddings (local)
```

**Principio central:** cada request al backend lleva el JWT de Supabase. El backend lo
valida, extrae el `user_id` y **toda** query (SQL y búsqueda vectorial) filtra por ese
`user_id`. RLS en Supabase es la segunda barrera.

---

## 3. Flujo de pantallas

1. **Login / Registro** (Supabase Auth) — sin sesión no se entra.
2. **Dashboard** — resumen de gastos (total del mes, por categoría, por banco, por
   moneda) + lista de transacciones + gráfico de dona.
3. **Subir cartola** — elegir banco → subir CSV → confirmar resultado.
4. **Foto boleta** — cámara/galería → Gemini lee → muestra monto/fecha/comercio →
   usuario **confirma o edita** → guarda.
5. **Chat** — pregunta en lenguaje natural sobre sus gastos (RAG filtrado por `user_id`).

---

## 4. Modelo de datos

Supabase Auth provee `auth.users` (no se modifica). Se agrega:

```sql
create table transactions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id),
  fecha       date not null,
  descripcion text not null,
  monto       numeric not null,        -- negativo = gasto, positivo = ingreso
  moneda      text not null default 'CLP',   -- 'CLP' | 'USD' | 'UF'...
  tarjeta     text,                    -- últimos 4 dígitos, ej '4521' (nullable)
  tipo        text not null,           -- 'cargo' | 'abono'
  categoria   text,                    -- auto: 'supermercado', 'transporte'...
  banco       text not null,           -- 'bci' | 'santander' | 'bancoestado' | 'manual'
  fuente      text not null,           -- 'cartola' | 'foto'
  created_at  timestamptz default now()
);
create index on transactions (user_id, fecha);
```

**pgvector:** la colección de embeddings (LangChain) guarda en la metadata de cada
documento el `user_id`. El chat filtra por `user_id` al buscar.

**Row Level Security (RLS):** política en Supabase que solo permite a cada usuario
leer/escribir filas donde `user_id = auth.uid()`. Defensa en profundidad: aunque el
backend tuviera un bug, la DB no filtra datos de otro usuario.

**Deduplicación:** una transacción se considera duplicada si coincide
`user_id + fecha + monto + descripcion + tarjeta`. Se ignora al re-subir (evita el doble
conteo observado al subir el mismo CSV dos veces).

**Multi-moneda:** los totales del dashboard se agrupan **por moneda**; nunca se suma CLP
con USD.

---

## 5. Backend (FastAPI)

Todos los endpoints (menos `/health`) exigen JWT válido vía la dependency
`get_current_user`, que valida el token de Supabase y extrae el `user_id`.

| Endpoint | Descripción |
|----------|-------------|
| `POST /api/v1/transactions/upload-csv?banco=` | Parsea CSV → dedup → inserta en `transactions` → indexa en pgvector con `user_id` |
| `POST /api/v1/transactions/upload-receipt` | Recibe imagen → Gemini Flash extrae JSON → devuelve gasto para confirmar (no guarda) |
| `POST /api/v1/transactions/confirm-receipt` | Guarda el gasto confirmado/editado por el usuario |
| `GET /api/v1/transactions` | Lista paginada del usuario (filtros: banco, fecha, categoría) |
| `GET /api/v1/transactions/summary` | Totales por categoría / mes / banco / moneda (SQL `SUM`, `GROUP BY`) |
| `POST /api/v1/chat/ask` | RAG sobre transacciones del usuario (filtra embeddings por `user_id`) |

### Servicios (responsabilidad única cada uno)

- `auth/jwt.py` — valida JWT de Supabase; expone `get_current_user`.
- `parsers/` — BCI / Santander / BancoEstado (ya existen, sin cambios de lógica).
- `services/transaction_service.py` — insertar, deduplicar, listar, agregar (summary).
- `services/receipt_service.py` — Gemini Flash visión → JSON estructurado del gasto.
- `services/categorizer.py` — reglas simples + DeepSeek para casos dudosos.
- `services/rag_service.py` — chat (ya existe; se agrega filtro por `user_id`).

### Flujo de foto en dos pasos (leer → confirmar)

Gemini puede equivocarse en una boleta borrosa o de papel térmico desvanecido. Por eso
`upload-receipt` **solo lee y devuelve** el gasto propuesto; el usuario lo revisa y recién
`confirm-receipt` lo persiste. Mejor UX y menos basura en la DB.

---

## 6. Frontend (Flutter, mobile-first)

```
lib/
├── main.dart                  app + tema + router con guard de auth
├── services/
│   ├── auth_service.dart       Supabase Auth (login, registro, logout, sesión)
│   └── api_service.dart        HTTP al backend, inyecta JWT en cada request
├── models/
│   ├── transaction.dart
│   └── summary.dart
├── screens/
│   ├── login_screen.dart       email+password / Google
│   ├── home_screen.dart        dashboard: cards de resumen + lista + gráfico
│   ├── upload_csv_screen.dart   elegir banco + file_picker
│   ├── receipt_screen.dart      cámara/galería → preview → confirmar gasto
│   └── chat_screen.dart         chat RAG (lo ya construido, movido aquí)
└── widgets/
    ├── summary_card.dart        total mes, por categoría, por banco
    ├── transaction_tile.dart
    ├── message_bubble.dart      (ya existe)
    └── upload_card.dart         (ya existe, se adapta)
```

**Plugins:** `supabase_flutter` (auth + sesión persistente), `image_picker` (cámara real
en mobile / selector en web), `file_picker` (CSV), `http` (backend), `fl_chart` (dona de
gastos por categoría).

**Navegación con guard:** sin sesión → Login; con sesión → Dashboard. El token se guarda
y se inyecta en cada llamada al backend.

**Reutilización:** el chat, las burbujas y el tema fintech oscuro ya construidos no se
botan; se reorganizan. El chat pasa a ser una pantalla más; el tema se mantiene en toda la
app.

---

## 7. Manejo de errores

| Caso | Respuesta |
|------|-----------|
| CSV mal formado / banco no soportado | 422 con mensaje claro en español |
| Foto ilegible / Gemini no extrae | "No pudimos leer la boleta, ingrésalo a mano" → form editable |
| JWT inválido o expirado | 401 → el front redirige a login |
| Gemini sin saldo / rate limit | Fallback a entrada manual del gasto |
| Usuario sin transacciones | Empty states que guían (sube cartola / saca foto) |

---

## 8. Testing

**Backend (pytest, `asyncio_mode=auto`):**
- Tests de cada parser con CSV fixtures reales (BCI, Santander, BancoEstado).
- Test de `get_current_user` con JWT válido e inválido.
- Test de deduplicación.
- Test de `summary` (agregaciones SQL correctas, agrupación por moneda).
- Test de `receipt_service` con Gemini mockeado.
- Test de RAG con LLM mockeado y verificación del filtro por `user_id`.

**Frontend:**
- Widget tests de login y chat.
- Smoke test del flujo subir cartola → preguntar.

---

## 9. Seguridad

- `.env` **nunca** se commitea (ya en `.gitignore`).
- JWT validado server-side en cada request; nada confía en el cliente.
- RLS en Supabase como segunda barrera de aislamiento de datos.
- **Pendiente del usuario:** la contraseña de la base de datos se compartió en texto plano
  durante el desarrollo; debe rotarse en el dashboard de Supabase antes de exponer el
  proyecto públicamente.

---

## 10. Fases de implementación

1. **Auth** — Supabase Auth + `get_current_user` + aislamiento `user_id` en lo existente.
2. **Datos** — tabla `transactions` + RLS + migrar upload/RAG a SQL + endpoint `summary`.
3. **Pantallas base** — login + dashboard en Flutter.
4. **Fotos** — captura (cámara/galería) + Gemini Flash + flujo confirmar.
5. **Categorización + gráfico** — categorizer + dona en el dashboard.
6. **Tests + pulido** — cobertura backend/front y limpieza.

El plan de implementación detallado (pasos accionables) se genera en el siguiente paso con
la skill `writing-plans`.
