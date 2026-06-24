# Plan 3 — Deploy de validación — Diseño técnico

**Fecha:** 2026-06-24
**Estado:** Aprobado para implementación
**Depende de:** Plans 1 y 2 (backend + frontend) completos y mergeados.

---

## 1. Resumen

Desplegar el producto para **validar con usuarios reales** al menor costo: backend en
**Fly.io** (región São Paulo), frontend Flutter web como **PWA en GitHub Pages**, **Supabase
free** (validación), embeddings con **fastembed** (ONNX liviano). El objetivo es tener un
**link público** (para el CV y para compartir), no aún una app en las tiendas.

Basado en la investigación de mercado (workflow 24-jun-2026): el stack es correcto para
mobile, el riesgo es distribución (no técnico), y la prioridad es validar barato antes de
invertir en parsers extra, Supabase Pro, robustez de LLM y publicación en stores.

### Decisiones

| Tema | Elegido | Por qué |
|------|---------|---------|
| Embeddings | **fastembed** (ONNX) | ~150MB RAM vs ~450MB de torch → entra en host chico |
| Backend host | **Fly.io, región `gru`** (São Paulo) | Datacenter LatAm (latencia), always-on barato (~$3-5/mes) |
| `min_machines_running` | **1** | fastembed carga el modelo en RAM; sin cold start de 3-8s |
| DB / Auth | **Supabase FREE** (proyecto actual) | Suficiente para validar; subir a Pro cuando haya usuarios reales con datos reales |
| Frontend | **GitHub Pages** (PWA) | Gratis, mismo repo, build por GitHub Actions; routing por hash (sin rewrites) |
| Bancos | **3 CSV** (BCI, Santander, BancoEstado) | Alcanzan para validar; PDF (Banco de Chile, Scotiabank) = slice aparte |

---

## 2. Arquitectura

```
┌──────────────────────────────┐
│ GitHub Pages (PWA)           │  Flutter web, build por GitHub Action
│ 304bxnjvv.github.io/preg...   │
└───────────────┬──────────────┘
                │ HTTPS + JWT (Bearer de la sesión Supabase)
┌───────────────▼──────────────┐
│ Fly.io — región GRU          │  FastAPI + fastembed (ONNX). 1 máquina 512MB always-on
│ <app>.fly.dev                 │  min_machines_running=1
└───────────────┬──────────────┘
                │
┌───────────────▼──────────────┐
│ Supabase FREE (bwjupd...)    │  Auth JWKS + Postgres + pgvector
└──────────────────────────────┘
   DeepSeek ── chat (directo por ahora)
```

**Cadena de despliegue:** backend a Fly.io → se obtiene la URL `<app>.fly.dev` → se pone en
`config.dart` (`backendBaseUrl`) → push → la Action publica el frontend en Pages.

---

## 3. Cambios de código (los hace el agente)

### 3.1 fastembed (backend)
- `backend/app/rag/vector_store.py`: reemplazar `HuggingFaceEmbeddings` por la integración
  de **fastembed** (`langchain_community.embeddings.FastEmbedEmbeddings`), con un modelo
  multilingüe chico (se confirma el nombre exacto soportado por fastembed en implementación;
  candidato: `intfloat/multilingual-e5-small`, 384-dim, ~120MB).
- `backend/requirements.txt`: quitar `sentence-transformers`, agregar `fastembed`.
- **Re-indexado:** si la dimensión del nuevo modelo difiere de la actual (384), las 5
  transacciones de prueba en pgvector quedan incompatibles → se borra la colección y se
  re-suben (trivial). Documentar el paso.

### 3.2 Contenedor para Fly.io
- `backend/Dockerfile`: base `python:3.11-slim`, instala `requirements.txt`, copia `app/`,
  expone el puerto e inicia `uvicorn app.main:app --host 0.0.0.0 --port 8080`.
- `backend/fly.toml`: `primary_region = "gru"`, `internal_port = 8080`,
  `min_machines_running = 1`, `memory = "512mb"`, sin `auto_stop_machines` (always-on).
- `backend/.dockerignore`: excluir `.venv`, `tests`, `.env`, `__pycache__`, etc.

### 3.3 Frontend
- `frontend/lib/config.dart`: `backendBaseUrl` → `https://<app>.fly.dev/api/v1` (se setea
  cuando exista la URL).
- `.github/workflows/deploy-web.yml`: en push a `main`, setup Flutter (subosito oficial),
  `flutter build web --release --base-href "/preguntale-tu-plata/"`, publicar `build/web`
  a GitHub Pages (vía `actions/deploy-pages` o `peaceiris/actions-gh-pages`).
- CORS del backend ya es `allow_origins=["*"]` → la PWA en Pages puede llamar a Fly.io.
  (Restringir al dominio de Pages = mejora posterior.)

---

## 4. Pasos manuales (los hace el usuario, con guía exacta)

1. **Crear cuenta Fly.io** (https://fly.io/app/sign-up, con GitHub). Verifica con tarjeta.
2. **Instalar flyctl** (PowerShell: `iwr https://fly.io/install.ps1 -useb | iex`) + `fly auth login`.
3. **`fly launch`** desde `backend/` (sin deploy aún) para crear la app y el `fly.toml`
   (el agente ajusta el `fly.toml` resultante a los valores de 3.2).
4. **Setear secrets** (no van al repo):
   `fly secrets set DEEPSEEK_API_KEY=... SUPABASE_URL=... POSTGRES_URL=...`
5. **`fly deploy`** → obtiene la URL `<app>.fly.dev`.
6. **Activar GitHub Pages** (repo → Settings → Pages → Source: GitHub Actions).

El agente prepara todo el código/config; el usuario ejecuta cuenta + flyctl + secrets +
deploy con comandos exactos.

---

## 5. Manejo de errores / operación

| Caso | Manejo |
|------|--------|
| fastembed baja el modelo en el primer arranque | `min_machines_running=1` evita re-bajarlo por cold start; primer boot tarda más |
| Secrets faltantes en Fly.io | el backend falla al iniciar (pydantic-settings exige los campos) → revisar `fly logs` |
| CORS desde Pages | cubierto con `allow_origins=["*"]` |
| Embeddings dim distinta | re-indexar la colección pgvector (paso documentado) |
| Pages con base-href incorrecto | la app no carga assets → usar `--base-href "/preguntale-tu-plata/"` |

---

## 6. Testing / verificación

- **Local antes de deploy:** correr el backend con fastembed (`uvicorn` local), subir el
  CSV de prueba y preguntar → confirmar que el RAG funciona con el nuevo embedder.
- **Suite existente:** `pytest` del backend sigue verde (los tests mockean el vector store,
  así que el cambio de embedder no los rompe; verificar igual).
- **Prod smoke:** abrir el link de Pages → login → dashboard → subir CSV → preguntar, todo
  contra el backend en Fly.io.

---

## 7. Fuera de scope (slices siguientes)

- **Parsers PDF** (Banco de Chile + Scotiabank, ambos tarjeta de crédito, text-based, sin
  OCR). Samples reales ya en mano (no se commitean; se usan fixtures sanitizados). = **Plan 4**.
- **Supabase Pro** ($25/mes) + backups → cuando haya usuarios reales con datos reales.
- **Robustez LLM:** DeepSeek → Together/Fireworks + fallback Gemini/Haiku.
- **Stores:** Google Play ($25), luego Apple ($99/año).
- **Tope de uso por usuario** (anti-abuso del LLM).
- Restringir CORS al dominio de Pages.
