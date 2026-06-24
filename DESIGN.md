# DESIGN.md — Pregúntale a tu plata

> Sistema de diseño (impeccable). Vibe: **"un confidente premium que habla en chileno"** — alma cálida/cercana, ejecución minimal/premium. Mobile-first, **dark cálido por defecto**, claro secundario.

## Paleta (dark cálido)

| Token | HEX | Rol |
|-------|-----|-----|
| `bg` Tinta nocturna | `#15131F` | Fondo principal (casi negro con sesgo violeta/cálido — NO `#0D1117`) |
| `surface` | `#1E1B2B` | Cards / superficies elevadas |
| `surfaceGlass` | `rgba(255,255,255,0.05)` | Glass cards (borde `rgba(255,255,255,0.10)`) |
| `primary` Índigo conversación | `#6C5CE7` | Héroe, IA, CTA, burbuja del usuario |
| `accent` Ámbar confianza | `#F4B860` | Acento cálido, orbe, highlights |
| `positive` Verde salvia | `#7FB496` | Montos OK / ingresos (apagado, NO neón) |
| `negative` Salmón suave | `#E8836B` | Gastos altos / déficit (**nunca rojo puro**) |
| `text` Blanco roto | `#F5F2EC` | Texto principal (cálido, NO `#FFFFFF`) |
| `textMuted` | `#A59FB5` | Texto secundario (lila grisáceo, NO gris azulado) |
| `border` | `rgba(255,255,255,0.10)` | Bordes sutiles |

**Reglas de color:**
- Estados (positivo/negativo) SIEMPRE con ícono además del color (~8% daltonismo).
- Nunca rojo puro para gastos → salmón. Nunca verde neón → salvia.
- Negros y grises **tintados** (violeta/cálido), nunca puros.

## Modo claro (secundario)
`bg #F5F2EC`, `surface #FFFFFF`, `text #211D2B`, mismos acentos índigo/ámbar. En Perfil, no en onboarding.

## Tipografía
- **Display (montos, titulares):** **Clash Display** (bundle asset) o **Hanken Grotesk** (vía google_fonts) — geométrica con carácter, pesos 600–800.
- **Texto/UI/chat:** **Plus Jakarta Sans** (google_fonts), 400–800, con `fontFeatures: tabular figures`.
- **Prohibidos:** Inter, Arial, Roboto, system-ui, serifs.
- **Reglas:** montos 700–800 @ 28–32px con `tabular-nums` y miles chilenos `$1.990` (punto, no coma). Body chat 16px/400. Labels categoría 12px/500, mayúsculas, `letter-spacing 0.05em`.

## Componentes
- **Burbujas de chat:** usuario = índigo `#6C5CE7` (esquina inferior-derecha recta); plata/IA = glass card. Gráficos dona/barra **inline** en las respuestas.
- **Orbe presencia:** pequeño orbe abstracto ámbar→índigo que **pulsa** cuando la IA piensa/responde. La *voz de tu plata* hecha forma — NO mascota.
- **Cards de resumen:** glass, esquinas 16–20px, sin anidar cards dentro de cards.
- **Montos:** Clash/Hanken bold, signo y color por estado, con ícono.
- **Botones:** primario índigo lleno; touch targets ≥ 48px.

## Motion
- Easing suave (`Curves.easeOutCubic`), nunca bounce/elastic.
- El orbe pulsa al pensar; reveal de transacciones con fade+slide corto. Respetar reduce-motion.

## Layout
- Mobile-first, una columna, jerarquía clara. Padding generoso (≥16px). Sin anidar cards. Heading hierarchy sin saltos.

## Ilustración
Solo geométrica/abstracta (líneas de datos, dona/barra). Cero stock photos, cero edificios corporativos.
