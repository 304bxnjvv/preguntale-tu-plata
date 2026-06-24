# Plan 2 — Flutter: Login + Dashboard — Diseño técnico

**Fecha:** 2026-06-24
**Estado:** Aprobado para implementación
**Depende de:** Plan 1 (backend auth + datos) — completo y mergeado a `main`.

---

## 1. Resumen

Frontend Flutter (mobile-first, web para demo) que autentica al usuario con Supabase Auth
(email + password) y le muestra un dashboard con el resumen de sus gastos. Consume el
backend del Plan 1, inyectando el JWT de la sesión Supabase en cada request.

El `frontend/` actual (chat + upload construidos antes, sin auth, apuntando a
`localhost:8000` sin token) se reorganiza: se agrega login + dashboard, y el `api.dart` se
reescribe para sacar el token de la sesión y pegar a los endpoints reales.

### Decisiones base

| Decisión | Elegido |
|----------|---------|
| State management | **Riverpod** |
| Auth | Supabase Auth, **email + password** (Google = futuro) |
| Routing | **go_router** con redirect por estado de auth |
| Token | `supabase_flutter` persiste y auto-refresca la sesión; el `access_token` se inyecta como `Bearer` |
| Target | Mobile-first; **web** para la demo (backend en `localhost:8000`) |
| Gráfico | `fl_chart` dona — por **banco** en este plan (por categoría = Plan 4) |

---

## 2. Arquitectura

```
main() → Supabase.initialize(SUPABASE_URL, anonKey)  [ambos públicos]
       → ProviderScope (Riverpod)
       → MaterialApp.router (go_router)

Providers:
  authProvider         StreamProvider — supabase.auth.onAuthStateChange (Session | null)
  apiProvider          Provider<ApiService> — lee el access_token de la sesión actual
  summaryProvider      FutureProvider — GET /api/v1/transactions/summary
  transactionsProvider FutureProvider — GET /api/v1/transactions

go_router redirect:
  sin sesión → /login
  con sesión → /dashboard
```

**Flujo:** abrir app → sin sesión, Login. Login OK → Supabase guarda la sesión (auto-refresh)
→ redirige a Dashboard. Cada request al backend lleva `Authorization: Bearer <access_token>`
de la sesión Supabase (el mismo esquema validado en vivo contra el backend del Plan 1).

**Conectividad:** en web (demo) el backend en `localhost:8000` funciona directo. En celular
físico/emulador habría que usar la IP de la máquina o un backend desplegado — fuera de scope.

---

## 3. Estructura de archivos

```
lib/
├── main.dart                     init Supabase + ProviderScope + router
├── config.dart                   SUPABASE_URL, anonKey, backendBaseUrl
├── router.dart                   go_router + redirect por auth
├── services/
│   └── api_service.dart          HTTP con JWT inyectado (reescribe el api.dart actual)
├── providers/
│   ├── auth_provider.dart        stream de sesión Supabase
│   └── data_providers.dart       summaryProvider, transactionsProvider, apiProvider
├── models/
│   ├── transaction.dart          Transaction.fromJson
│   └── summary.dart              Summary.fromJson (por_moneda, gastos_por_banco, ...)
├── screens/
│   ├── login_screen.dart         email+password, modos Entrar / Registrarse
│   ├── dashboard_screen.dart     cards + dona + lista + accesos + logout
│   ├── chat_screen.dart          el chat actual, detrás de auth
│   └── upload_screen.dart        elegir banco + subir CSV
└── widgets/
    ├── summary_card.dart         gastos del mes / ingresos / balance
    ├── gastos_dona.dart          fl_chart por banco
    ├── transaction_tile.dart
    └── message_bubble.dart       (ya existe, se mueve)
```

**config.dart:** `SUPABASE_URL` y `anonKey` son públicos por diseño (los clientes Supabase
los exponen; la seguridad está en RLS + validación de JWT del backend). `backendBaseUrl`
default `http://localhost:8000` para la demo web.

---

## 4. Pantallas

### LoginScreen
- Dos modos en tabs: **Entrar** / **Registrarse**.
- Campos: email + password. Validación: email con formato válido, password ≥ 6 caracteres.
- Botón con spinner durante la llamada. Errores de Supabase traducidos a español bajo el
  form: "Email o contraseña incorrectos", "Este email ya está registrado".
- Al autenticar, `go_router` redirige a `/dashboard` automáticamente (vía `authProvider`).

### DashboardScreen
- **Cards** arriba (del `summaryProvider`): gastos del mes, ingresos, balance — por moneda
  (CLP). Los gastos vienen negativos del backend; se muestran como monto con signo claro.
- **Dona `fl_chart`:** gastos por banco (`gastos_por_banco`). En Plan 4 pasa a categoría.
- **Lista** de transacciones recientes (`transactionsProvider`), `transaction_tile`.
- **Acciones:** botones **Subir cartola** (→ upload_screen) y **Preguntar** (→ chat_screen).
- **Pull-to-refresh** (invalida summary + transactions providers) y **logout**
  (`supabase.auth.signOut()` → redirige a login).
- **Empty state** (usuario nuevo sin transacciones): "Sube tu primera cartola" + botón.

### ChatScreen y UploadScreen
- Reutilizan el chat y el upload construidos antes; se mueven a estas pantallas y se conectan
  al `api_service` con JWT. Endpoints: `/chat/ask` y `/transactions/upload-csv`.

---

## 5. ApiService

Reescribe el `api.dart` actual. Responsabilidad única: HTTP al backend con el JWT.

- Lee el `access_token` de `Supabase.instance.client.auth.currentSession`. Si no hay sesión,
  las llamadas no se hacen (el router ya evita llegar acá sin sesión).
- Inyecta `Authorization: Bearer <token>` y `Content-Type` en cada request.
- Métodos: `uploadCsv(bytes, filename, banco)` → `POST /transactions/upload-csv`;
  `ask(question)` → `POST /chat/ask`; `getSummary()` → `GET /transactions/summary`;
  `getTransactions()` → `GET /transactions`.
- Errores HTTP (401, 5xx, timeout) se propagan como excepción tipada que la UI traduce a
  mensajes/snackbars.

---

## 6. Manejo de errores

| Caso | Manejo |
|------|--------|
| Login inválido | Mensaje en español bajo el form |
| Email ya registrado | Mensaje en el modo Registrarse |
| Sin conexión al backend | Snackbar "No se pudo conectar" + reintentar |
| Token expirado | `supabase_flutter` auto-refresca; si falla → login |
| Dashboard sin datos | Empty state que guía a subir cartola |
| Cargando | Spinners/skeletons en cards y lista |

---

## 7. Testing

- **Widget tests:** `LoginScreen` (validación de email/password, muestra error de auth);
  `DashboardScreen` con `ApiService` mockeado vía `ProviderScope` overrides (Riverpod facilita
  inyectar un fake) — verifica que rendea cards y lista con datos de ejemplo, y el empty state
  sin datos.
- **Smoke test:** sesión simulada → el router lleva a Dashboard y rendea.
- No se testea integración real con Supabase en unit tests (eso fue la prueba en vivo del
  backend); los providers se mockean con overrides.

---

## 8. Fuera de scope (otros planes)

- OCR de fotos de boletas con Gemini Flash → **Plan 3**.
- Categorización automática + dona por categoría → **Plan 4**.
- Login con Google (OAuth) → futuro.
- Deploy del backend / conectividad mobile real → futuro.

La dona del dashboard arranca **por banco**; migra a categoría cuando el Plan 4 popule
`categoria`.
