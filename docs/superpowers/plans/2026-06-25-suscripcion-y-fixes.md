# Suscripción (trial+paywall+Flow scaffold) + fixes confirmados (Plan 10)

**Goal:** Sistema de suscripción completo listo para enchufar Flow (prueba 7d → $3.990/mes), consentimiento SERNAC, cancelar; + 3 fixes confirmados por el usuario.

## Decisiones del usuario
- Onboarding pregunta = delivery (ya está).
- Demo se auto-borra al subir 1ª cartola real.
- Borrar datos = escribir "borrar" en casilla.
- Retención = **1 año** (no 30 días) → actualizar copy + legales.
- Trial = **7 días**. Flow = pasarela (NO se puede ir a producción sin Inicio de Actividades SII + cuenta Flow → integración queda lista pero gateada por config).
- Paywall SOFT por ahora (banner + pantalla alcanzable, NO bloquea la app duro hasta activar).

## Contrato API (nuevo)
- `GET /subscription` → `{estado, dias_restantes, trial_ends_at, precio_clp}` (crea trial lazy si no existe).
- `POST /subscription/checkout` → `{url}` (URL de pago Flow) o **503** `{detail:"pago no configurado"}` si faltan llaves Flow.
- `POST /subscription/webhook` → callback Flow (stub: marca estado=activa).
- `POST /subscription/cancel` → `{estado:"cancelada"}`.

### Task 1 — Backend
- **Demo auto-clear:** en `routes/upload.py` (endpoint universal `/transactions/upload`), tras un upload REAL exitoso (fuente="cartola"), llamar `clear_demo(session, user_id)` antes de responder.
- **Subscription:** modelo `Subscription` (user_id PK/unique, estado: trial|activa|cancelada|vencida, trial_ends_at, periodo_fin, created_at) + migración `004_subscriptions.sql` (RLS por user_id). `subscription_service.py`: `get_or_create(session, user_id, trial_dias=7)`, `estado_actual` (calcula vencida si trial_ends_at < hoy y no activa), `cancelar`. Trial 7d.
- **Flow scaffold:** `config.py` agrega `flow_api_key:str=""`, `flow_secret:str=""`. `flow_service.py`: `crear_orden_suscripcion(user_id, email)` → si no hay llaves, `raise FlowNoConfigurado`; estructura la llamada (documentada) pero no requiere red en tests. `verificar_webhook(payload)` stub.
- **Endpoints** arriba en `routes/subscription.py`, registrados en main `/api/v1`. checkout → 503 si FlowNoConfigurado.
- **Schemas** correspondientes.
- Tests: trial se crea lazy 7d; vencida tras fecha; cancelar; checkout 503 sin llaves; demo se borra tras upload real (mock extract). `pytest` verde.

### Task 2 — Frontend
- **Borrar datos:** en `SettingsScreen`, el confirm pide **escribir "borrar"** en un TextField (botón habilitado solo si el texto == "borrar") → `deleteAccountData()` → signOut.
- **Retención copy:** cambiar "30 días" → "1 año" donde aparezca (onboarding/settings/privacidad UI).
- **Suscripción:** `subscriptionProvider` (GET /subscription). 
  - **Banner** en dashboard: "Te quedan N días de prueba" (ámbar) o "Prueba vencida — suscríbete" (salmón) con botón → PaywallScreen.
  - **PaywallScreen** (`/suscripcion`): precio $3.990/mes, beneficios, botón "suscribirme" → ConsentScreen.
  - **ConsentScreen** (SERNAC): texto explícito *"Autorizo el cobro automático de $3.990/mes a partir del [fecha fin trial]. Puedo cancelar cuando quiera desde la app."* + checkbox/botón "autorizo" → `POST /subscription/checkout` → abre URL Flow (o muestra "el cobro estará disponible pronto" si 503).
  - **Cancelar** en SettingsScreen (POST /subscription/cancel + confirm).
  - SOFT: banner + paywall alcanzable, NO redirect que bloquee la app.
- Tests + analyze verdes; no romper diseño.

### Task 3 — Legales
- `docs/legal/politica-privacidad.md`: retención 30d → **1 año**.

## Post
Aplicar migración 004 → pytest + flutter test → deploy HF + Pages. Dudas/blockers al usuario.
