# Go-to-market: competencia · nombre · legal CL · Play Store · crítica · plan

> Investigación multi-agente (24-jun-2026). Producto: app CL de finanzas con chat IA sobre cartolas propias. Modelo: trial → $3.990/mes. Founder solo, Chile primero.

## ⚠️ Dos hallazgos que cambian el tablero
1. **Kuanto** (competidor CL directo) ya no es "early": lanzó ago-2025, +2.000 usuarios en el 1er mes, cobra **$6.990/mes** (promo $4.990), **ya está en Play Store** (`cl.kuanto.kuantoapp`), levantó ronda dic-2025, planea Colombia 2026. Lee correos del banco (auto). Tu ventaja: más barato ($3.990) + no conectas banco.
2. **ChatGPT finanzas** lanzó 15-may-2026 (USA, Pro, vía Plaid conectando banco). Hoy NO en Chile y conecta banco (lo opuesto a tu pitch). Llega.

---

## Nombre — recomendado: **Velu**
Top 3 (todos `.cl` libres SOLO por DNS → **verificar en NIC.cl + INAPI antes de registrar**; `.com` ocupados → usar `.app`):
- **Velu** — mayor limpieza de marca, sin colisión fintech/LatAm. *(menor riesgo)*
- **Filu** — sin colisión finanzas; solo una veterinaria alemana.
- **Plei** — memorable pero hay app de fútbol Plei.io con penetración LatAm (riesgo medio).
Descartados por dominio/colisión: Nomi, Lota, Poka, Komi, Kiku (startup IA), Yala (¡app finanzas peruana!), Fixi.

---

## Competencia — qué robarle a cada una
- **Cleo** (chat IA, $280M ARR): el TONO de amigo + insights proactivos + memoria de conversación.
- **Rocket Money**: onboarding WOW — "¿cuánto crees que gastas en suscripciones?" → revela el número real. Copiar al subir 1ª cartola.
- **Fintonic**: FinScore (número 0-1000 de salud financiera) → gamifica retención sin conectar banco.
- **YNAB**: trial 34 días SIN tarjeta.
- **Mobills**: leer estado de cuenta de tarjeta → proyectar "cuánto pagarás el próximo mes".
- **MonAi/Organizze**: registro rápido por voz/texto ("gasté 5 lucas en almuerzo").
- **Tenpo/Kuanto**: categorías chilenas reales (Líder→Super, Copec→Bencina).
- **Patrón ganador onboarding**: WOW en <3 min con datos reales del usuario, antes de pedir esfuerzo.

---

## Crítica: por qué un chileno NO pagaría $3.990 (top, priorizado)
1. **"Ya lo veo gratis en la app del banco/Tenpo"** ← killer #1. Fix: el valor pagable es el CHAT que explica + multi-banco + suscripciones. Copy: *"Tu banco te muestra. Esta te explica."* El AHA debe ser conversacional, NO un gráfico de torta.
2. **Miedo a subir cartolas a marca desconocida.** Fix: privacidad como prueba técnica visible (auto-borrado 30d, tachar RUT/N°cuenta antes de OpenAI, cifrado), no eslogan.
3. **Esfuerzo manual de subir PDF cada mes.** Fix: registro por voz/texto + (opcional) reenvío de correos del banco (vector Kuanto).
4. **Trial 3 días NO alcanza a generar hábito** → cancela. Fix: **subir a 7-14 días sin tarjeta** + cartolas demo precargadas.
5. **Sin prueba social/respaldo = ¿scam?** Fix: cara del founder, T&C/privacidad CL, primeros testimonios.
6. **Chat genérico sin personalidad** (= pegar PDF en ChatGPT). Fix: nombre + tono chileno + insights sin que pregunten.
7. **Sin loop de retorno post-trial.** Fix: FinScore + push ("tu Spotify subió de precio").
8. **Categorías que no reconocen comercios CL.** Fix: diccionario chileno (alto impacto, barato).
9-12: gancho WOW onboarding · leer tarjeta de crédito · ChatGPT/Kuanto erosionan "IA conversacional" (tu foso = privacidad + chileno real + más barato + hábito) · ofrecer plan anual.

---

## Legal CL — lo BLOQUEANTE antes de cobrar
- **SERNAC**: consentimiento del cobro con clic separado de los T&C, texto visible ANTES de la tarjeta: *"Autorizo cobro de $3.990/mes desde [fecha], cancelable cuando quieras"*; **botón de cancelar en la app**; **derecho a retracto 10 días**; precio sin letra chica.
- **SII**: partir **persona natural 2ª categoría** (costo $0); **Inicio de Actividades** (F4415 online, cód. 620100); **Boleta de Honorarios Electrónica por cada cobro** (automatizar vía API SII); PPM 17%. ⚠️ **Confirmar con contador si es honorarios (sin IVA) o servicio afecto a IVA** (Ley 21.713 oct-2025 amplió IVA a servicios).
- **Privacidad**: Ley 19.628 hoy (consentimiento explícito, datos financieros, OpenAI=transferencia internacional EE.UU., retención, derechos ARCO). **Ley 21.719 entra en vigencia 1-dic-2026** (multas hasta 20.000 UTM, cifrado en reposo, notificación de brechas).
- **T&C + Política de Privacidad** en URL pública (GitHub Pages sirve) + **limitación de responsabilidad: "informa, NO es asesoría financiera"**.
- **Eliminar mi cuenta y datos** (botón en app) — también lo exige Play Store.
- **Pasarela recomendada: Flow** (API REST español, suscripciones nativas, sin costo fijo, 2,89-3,19%+IVA, sin fricción de aprobación). En Play Store: Google Play Billing obligatorio (15%).
- **SpA después**: cuando pases ~30-50 suscriptores o ~$200-300k/mes, o quieras socio/inversión/facturar a empresas.

---

## Play Store — qué le falta (es lo ÚLTIMO; valida la web primero)
**Prerequisito:** la PWA web NO sirve para Play Store → necesitas el AAB nativo (`flutter build appbundle --release`).
Estado actual: `applicationId=com.benja.preguntale_tu_plata` (tiene tu nombre), ícono = logo Flutter por defecto, firma con **debug key** (rechazada), label técnico, targetSdk 35.

**Bloqueantes:**
- Keystore de producción + firma release (hoy firma con debug → Play rechaza).
- targetSdk/compileSdk = **36** antes del **31-ago-2026**.
- Cuenta Google Play Dev: **$25 USD** único + verificación identidad.
- **Closed testing: 12 testers reales, 14 días continuos** (cuentas personales post-nov-2023) antes de poder publicar.
- URL de política de privacidad · formulario **Data Safety** · **Content rating** IARC · **Data deletion** URL.

**Importantes:** `applicationId` definitivo (ej. `cl.velu.app`, **irreversible** post-publicación) · ícono de marca 1024×1024 + adaptativo · `android:label` al nombre comercial · botón eliminar cuenta · permiso INTERNET explícito · auditar permisos de file_picker.

---

## Plan de trabajo (secuencia)
**Fase 0 — Marca (esta semana, desbloquea todo):** elegir Velu → verificar NIC.cl + INAPI → registrar `velu.cl`/`velu.app` → decidir `applicationId` (`cl.velu.app`, irreversible).

**Fase 1 — Producto (mayor impacto, en paralelo):** 1) Onboarding WOW + trial 7-14 días sin tarjeta + cartolas demo · 2) Diccionario comercios chilenos · 3) Chat con personalidad + comparativo mes a mes proactivo · 4) Detección de suscripciones recurrentes · 5) Privacidad visible (auto-borrado, tachar RUT antes de OpenAI) · 6) FinScore + push · 7) Registro voz/texto · 8) Leer tarjeta de crédito.

**Fase 2 — Legal antes de cobrar (bloqueante, en paralelo):** contador (pregunta IVA) → Inicio Actividades SII → T&C + Política Privacidad → flujo consentimiento SERNAC → botones cancelar/eliminar cuenta → cifrado + retención.

**Fase 3 — Pago:** Flow (web) + BHE automatizada.

**Fase 4 — Play Store (ÚLTIMO):** solo cuando la PWA convierta y retenga. ~3 semanas de fricción (testing 14d + review). No quemes esto antes de validar que alguien paga.

### Regla de oro
**No publiques en Play Store antes de validar conversión en la web.** La pregunta #1 es *¿alguien paga $3.990 tras el trial?* — la respondes con la web + Flow primero.

### Inciertos a confirmar tú
1. Ningún `.cl` confirmado en NIC.cl (solo DNS). 2. Clasificación IVA depende del SII/contador. 3. Precio/modelo de Kuanto es de prensa 2025.
