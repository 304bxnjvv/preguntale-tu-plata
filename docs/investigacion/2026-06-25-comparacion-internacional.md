# Comparación internacional — Pregúntale a tu plata (2026-06-25)

> Continúa y actualiza `2026-06-24-go-to-market.md`. La app avanzó mucho desde entonces
> (categorización, FinScore, lectura de tarjeta de crédito, registro por voz/texto en chat).
> Fuente: workflow multi-agente con búsqueda web sobre 25 apps/tendencias (Cleo, Monarch,
> Copilot, YNAB, Rocket Money, Emma, Plum, Fintonic, Mobills, Organizze, Kuanto, Fintual,
> Tenpo, MACH, Destácame, Origin, Fina, etc.).

## Resumen ejecutivo

Nuestro **moat es la combinación**: chat IA en chileno (RAG) + modelado de **cuotas de tarjeta**
+ **privacidad sin login bancario** + precio bajo ($3.990 vs Kuanto $6.990). Esa mezcla **no la
tiene nadie en Chile**, y casi nadie en el mundo junta "chat conversacional" con "realidad local".

Donde el mundo nos saca ventaja: **presupuestos/metas**, **alertas push proactivas**, **forecast
(proyección de fin de mes)**, **captura de boletas/efectivo**, y **canales de bajo roce** (WhatsApp).
Casi todas son features alcanzables para un dev solo; ninguna requiere abandonar nuestro diseño.

Amenazas reales: **Kuanto** (mismo nicho, ya en Play Store, capta leyendo correos del banco) y
los gigantes de wallet **Tenpo/MACH** (millones de usuarios) si decidieran localizar gestión de
gastos con IA.

---

## 1. Qué TENEMOS (a la par o mejor que el mercado)

| Feature nuestra | Cómo quedamos vs el mundo |
|---|---|
| **Chat IA conversacional (RAG, chileno)** | Mejor que todo Chile. A la par de Cleo/Origin en concepto, pero localizado. |
| **Cuotas de tarjeta + "comprometido próximo mes"** | **Nadie lo modela así.** Ni los gringos (allá no es cultura de cuotas) ni Kuanto. Diferenciador puro. |
| **Categorización automática (LLM + reglas)** | A la par de Copilot/Monarch en concepto; ellos la tienen "que aprende", nosotros aún no. |
| **FinScore (salud financiera)** | Concepto tipo Cleo/Bright; pocos lo muestran tan simple. |
| **Privacidad: subir PDF sin login bancario** | Más privado que Kuanto (que lee correos) y que todo gringo basado en Plaid. |
| **Registro por voz/texto con slang chileno** | "gasté 5 lucas" — Cleo registra por chat pero en inglés; nadie lo hace en chileno. |
| **Detección de suscripciones** | A la par de Rocket Money/Emma (sin la parte de cancelar, que en Chile no aplica). |

---

## 2. Qué nos FALTA (gaps reales para Chile)

| Gap | Quién lo tiene | Impacto | Esfuerzo |
|---|---|---|---|
| **Presupuestos y metas de ahorro** | YNAB, Monarch, Mobills, Spendee | 🔴 Alto | 🟡 Medio |
| **Alertas push proactivas** (te pasaste, vence cuota, gasto raro) | Copilot, Monarch, Fintonic | 🔴 Alto | 🟡 Medio |
| **Forecast / proyección de fin de mes** | Copilot, Monarch | 🔴 Alto | 🔴 Alto |
| **Captura de boletas por foto (OCR) / efectivo** | Spendee, Mobills | 🟡 Medio | 🟡 Medio |
| **Categorización que aprende de tus correcciones** | Monarch, Copilot | 🟡 Medio | 🟡 Medio |
| **Modo pareja / cuenta compartida** | Monarch | 🟡 Medio | 🟡 Medio |
| **Canal de bajo roce (WhatsApp) para registrar** | Mobills (LATAM) | 🟡 Medio | 🟡 Medio |

> No copiamos features que no aplican en Chile: negociación de cuentas (Rocket Money),
> cash advances (Cleo), round-ups a inversión gringa. No hay infra local para eso.

---

## 3. Qué nos DIFERENCIA (el moat)

1. **Chat IA en chileno** — ningún competidor chileno *conversa* con tu plata. Kuanto te muestra
   dashboards; nosotros respondes "¿en qué se me fue la plata?" y te contesta.
2. **Cuotas de tarjeta** — el dolor #1 del chileno endeudado ("¿cuánto me llega el próximo mes?").
   Nadie lo resuelve. Es nuestro gancho más vendible.
3. **Sin login bancario + barato** — privacidad real (subes PDF) y la mitad del precio de Kuanto.
4. **La combinación** — cada pieza por separado es copiable; las cuatro juntas, no.

---

## 4. OPCIONES a implementar (priorizadas)

### 🟢 YA (alto valor / bajo-medio esfuerzo — refuerzan el moat)
1. **Resumen semanal push en chileno** — la IA te manda cada lunes "esta semana gastaste $X, lo
   más fuerte fue delivery". Reusa el RAG. Retención barata + IA *proactiva* (no solo reactiva).
   *Inspirado en Monarch/Origin.*
2. **Alertas de cuotas y vencimiento** — push "tu tarjeta vence en 3 días, debes pagar $X" y
   "el próximo mes te llegan $Y en cuotas". Ya leemos la tarjeta, falta el aviso. *Copilot/Fintonic.*
3. **Trial de 30 días sin tarjeta** (subir de 7) — 7 días no alcanza para que el usuario cargue
   suficientes cartolas y vea el valor. *Kuanto/YNAB.*

### 🟡 PRONTO (paridad + crecimiento)
4. **Registro de gastos por WhatsApp** — bot que registra "gasté 3 lucas en micro". Mata el roce
   (no hay que abrir la app) y WhatsApp es EL canal chileno. Reusa el parser de slang. *Mobills.*
5. **Presupuestos, metas y boletas por foto** — metas de ahorro con alerta + OCR de boleta para
   capturar gastos en efectivo. Cierra el gap más pedido y captura la plata que no pasa por banco.
   *Monarch/Spendee.*
6. **Categorización que aprende** + **tono ajustable del chat** (formal/bacán) + **referidos**.

### 🔵 DESPUÉS (caro o dependiente de tracción)
7. **Forecast de fin de mes** (proyección con histórico) — alto valor pero caro de hacer bien.
8. **Modo pareja / cuenta compartida.**

---

## 5. Amenazas

| Competidor | Riesgo | Nuestra defensa |
|---|---|---|
| **Kuanto** | Mismo nicho, ya en Play Store, capta leyendo correos del banco | Cuotas + WhatsApp + privacidad + precio. Profundizar lo chileno-real. |
| **Tenpo / MACH** | 2M+ usuarios; si localizan gestión de gastos con IA, escala instantánea | Ir *vertical* y profundo en gestión+IA donde ellos son anchos y superficiales. |
| **Fintonic u otro hispano** | Si entran a Chile con IA ya hecha | Localización extrema (RUT, cuotas, slang, courier) que un genérico no replica rápido. |

---

## Recomendación de secuencia

Las 3 de **🟢 YA** son baratas y *todas* refuerzan el moat (IA proactiva + dolor de cuotas + más
tiempo de trial para convertir). Hacerlas antes de pelear paridad genérica (presupuestos) porque
nos distancian de Kuanto en vez de solo igualar a YNAB.
