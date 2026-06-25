# Forecast + Boletas (foto) + Resumen semanal — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) o superpowers:executing-plans para implementar task-by-task. Pasos con checkbox (`- [ ]`).

**Goal:** Tres features proactivas: (F) proyección de fin de mes, (V) registrar gastos sacando foto a la boleta (OCR), (S) resumen semanal automático en chileno.

**Architecture:** Todo read-only o reúso de la tabla `transactions` — **sin migraciones**. Backend FastAPI + SQLAlchemy sobre los servicios e insights ya existentes; frontend Flutter + Riverpod (FutureProvider) + cards en dashboard. La extracción de imagen ya existe (`extraction_service.extract_from_image`), Boletas la afina para recibos.

**Tech Stack:** Python 3.11, FastAPI, SQLAlchemy, pytest (sqlite). Flutter 3.8, flutter_riverpod, go_router, image_picker, shared_preferences, mocktail.

**Orden de construcción:** S (resumen, el más simple) → F (forecast) → V (boletas). Independientes; este orden entrega valor temprano.

## Global Constraints
- Mobile-first, español chileno, tono cálido, mensajes cortos. Montos con `formatCLP` (front) y `f"${x:,.0f}".replace(",", ".")` (back).
- Categorías = las 11 de `app/services/categorias.py::CATEGORIAS`.
- Prefijo API `/api/v1`. Endpoints nuevos cuelgan de `insights.py` o `upload.py` (mismo router que ya está incluido en `main.py`).
- Tests: LLM SIEMPRE mockeado, fixtures sintéticos. Nunca datos personales reales.
- **Sin migraciones.** No tocar el esquema. Boletas guarda en `transactions` con `fuente="boleta"`, `banco="efectivo"`.
- No romper flujos existentes. Baseline: 318 backend / 118 frontend, `flutter analyze` limpio. (ruff/mypy NO están en el venv.)
- Forecast es honesto: sin saldo bancario no se proyecta saldo de cuenta; se proyecta **gasto** (y neto solo si hay ingresos del mes).

---

# GRUPO S — Resumen semanal (plantilla determinista)

### Task S1: `resumen_semanal_service`

**Files:**
- Create: `backend/app/services/resumen_semanal_service.py`
- Test: `backend/tests/services/test_resumen_semanal.py`

**Interfaces:**
- Produces: `generar_resumen(session, user_id, hoy: date | None = None) -> dict`:
  `{ tiene_datos: bool, periodo: str, gasto_semana: float, top_categoria: str | None, top_monto: float, delta_pct: float | None, texto: str }`.
  Ventana = últimos 7 días (hoy-7 ≤ fecha < hoy+1). `delta_pct` vs los 7 días previos ([hoy-14, hoy-7)); `None` si la semana previa fue 0. `texto` = plantilla chilena determinista. `tiene_datos=False` (y texto vacío) si gasto_semana == 0.

- [ ] **Step 1: Tests que fallan**

```python
# backend/tests/services/test_resumen_semanal.py
import pytest
from datetime import date, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
import app.db.models  # noqa
from app.db.base import Base
from app.db.models import Transaction
from app.services.resumen_semanal_service import generar_resumen

HOY = date(2026, 6, 25)

@pytest.fixture
def session():
    eng = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(eng)
    s = sessionmaker(bind=eng)()
    yield s
    s.close()

def _g(s, dias_atras, monto, cat="Comida y delivery", desc="x"):
    s.add(Transaction(user_id="u1", fecha=HOY - timedelta(days=dias_atras), descripcion=desc,
                      monto=monto, moneda="CLP", tipo="gasto", categoria=cat, banco="b", fuente="test"))
    s.commit()

def test_sin_datos(session):
    r = generar_resumen(session, "u1", hoy=HOY)
    assert r["tiene_datos"] is False
    assert r["gasto_semana"] == 0

def test_gasto_y_top_categoria(session):
    _g(session, 1, -20000, "Comida y delivery")
    _g(session, 2, -5000, "Transporte")
    r = generar_resumen(session, "u1", hoy=HOY)
    assert r["tiene_datos"] is True
    assert r["gasto_semana"] == 25000
    assert r["top_categoria"] == "Comida y delivery"
    assert r["top_monto"] == 20000
    assert "25.000" in r["texto"]

def test_delta_vs_semana_anterior(session):
    _g(session, 1, -10000)          # esta semana
    _g(session, 9, -5000)           # semana pasada
    r = generar_resumen(session, "u1", hoy=HOY)
    assert r["delta_pct"] == pytest.approx(100.0)  # subió 100%

def test_delta_none_sin_semana_previa(session):
    _g(session, 1, -10000)
    r = generar_resumen(session, "u1", hoy=HOY)
    assert r["delta_pct"] is None
```

- [ ] **Step 2: Ver fallar** — `cd backend && .venv/Scripts/python.exe -m pytest tests/services/test_resumen_semanal.py -v`

- [ ] **Step 3: Implementar**

```python
# backend/app/services/resumen_semanal_service.py
from __future__ import annotations
from datetime import date, timedelta
from collections import defaultdict
from sqlalchemy import func
from sqlalchemy.orm import Session
from app.db.models import Transaction

def _fmt(x: float) -> str:
    return f"${x:,.0f}".replace(",", ".")

def generar_resumen(session: Session, user_id: str, hoy: date | None = None) -> dict:
    hoy = hoy or date.today()
    ini = hoy - timedelta(days=7)
    ini_prev = hoy - timedelta(days=14)

    def _gastos(desde, hasta):
        return (session.query(Transaction)
                .filter(Transaction.user_id == user_id, Transaction.monto < 0,
                        Transaction.fecha >= desde, Transaction.fecha < hasta).all())

    sem = _gastos(ini, hoy + timedelta(days=1))
    gasto_semana = sum(abs(float(t.monto)) for t in sem)
    if gasto_semana == 0:
        return {"tiene_datos": False, "periodo": f"{ini.isoformat()}..{hoy.isoformat()}",
                "gasto_semana": 0.0, "top_categoria": None, "top_monto": 0.0,
                "delta_pct": None, "texto": ""}

    por_cat: dict[str, float] = defaultdict(float)
    for t in sem:
        por_cat[t.categoria or "Otros"] += abs(float(t.monto))
    top_categoria, top_monto = max(por_cat.items(), key=lambda kv: kv[1])

    prev = _gastos(ini_prev, ini)
    gasto_prev = sum(abs(float(t.monto)) for t in prev)
    delta_pct = ((gasto_semana - gasto_prev) / gasto_prev * 100) if gasto_prev > 0 else None

    # Plantilla chilena determinista
    partes = [f"Esta semana se te fueron {_fmt(gasto_semana)}."]
    partes.append(f"Lo más fuerte fue {top_categoria} ({_fmt(top_monto)}).")
    if delta_pct is not None:
        if delta_pct > 5:
            partes.append(f"Gastaste un {abs(delta_pct):.0f}% más que la semana pasada, ojo 👀.")
        elif delta_pct < -5:
            partes.append(f"Bajaste un {abs(delta_pct):.0f}% vs la semana pasada, ¡bien ahí! 👏.")
        else:
            partes.append("Te mantuviste parecido a la semana pasada.")
    texto = " ".join(partes)

    return {"tiene_datos": True, "periodo": f"{ini.isoformat()}..{hoy.isoformat()}",
            "gasto_semana": gasto_semana, "top_categoria": top_categoria, "top_monto": top_monto,
            "delta_pct": delta_pct, "texto": texto}
```

- [ ] **Step 4: Ver pasar.** **Step 5: Commit** — `git commit -m "feat(resumen): resumen_semanal_service (plantilla determinista)"`

---

### Task S2: Endpoint `GET /insights/resumen-semanal`

**Files:**
- Modify: `backend/app/api/routes/insights.py`
- Modify: `backend/app/models/schemas.py` (`ResumenSemanalResponse`)
- Test: `backend/tests/api/test_resumen_semanal_endpoint.py`

**Interfaces:** `GET /insights/resumen-semanal` → `ResumenSemanalResponse` (mismos campos del dict de S1).

- [ ] **Step 1: Test que falla** (patrón de `test_insights.py`): 200 + shape (`tiene_datos`, `texto`, `gasto_semana`); sin auth → 401/403.
- [ ] **Step 2: Ver fallar.**
- [ ] **Step 3: Schema + endpoint** (mirror `get_finscore`):

```python
# schemas.py
class ResumenSemanalResponse(BaseModel):
    tiene_datos: bool
    periodo: str
    gasto_semana: float
    top_categoria: Optional[str]
    top_monto: float
    delta_pct: Optional[float]
    texto: str
```
```python
# insights.py
from app.services.resumen_semanal_service import generar_resumen
from app.models.schemas import ResumenSemanalResponse

@router.get("/insights/resumen-semanal", response_model=ResumenSemanalResponse)
async def get_resumen_semanal(user_id: str = Depends(get_current_user), session: Session = Depends(get_session)):
    return generar_resumen(session, user_id)
```
- [ ] **Step 4: Ver pasar (archivo + suite). Step 5: Commit** — `git commit -m "feat(api): GET /insights/resumen-semanal"`

---

### Task S3: Frontend — card "Tu semana en plata" (semanal, descartable)

**Files:**
- Create: `frontend/lib/models/resumen_semanal.dart`
- Create: `frontend/lib/services/resumen_seen.dart` (shared_preferences: timestamp de última vez mostrado/descartado)
- Create: `frontend/lib/widgets/resumen_semanal_card.dart`
- Modify: `frontend/lib/services/api_service.dart` (`getResumenSemanal`)
- Modify: `frontend/lib/providers/data_providers.dart` (`resumenSemanalProvider`)
- Modify: `frontend/lib/screens/dashboard_screen.dart` (mostrar la card si `tiene_datos` y pasaron ≥7 días desde el último descarte; botón "ya lo vi" guarda timestamp; incluir provider en `_refrescarDatos`)
- Test: `frontend/test/widgets/resumen_semanal_card_test.dart`

**Interfaces:**
- `ResumenSemanal.fromJson` ({tieneDatos, periodo, gastoSemana, topCategoria, topMonto, deltaPct, texto}).
- `ResumenSeen`: `Future<bool> debeMostrar()` (true si nunca se mostró o pasaron ≥7 días), `Future<void> marcarVisto()`.

- [ ] **Step 1: modelo + fromJson + test** (mirror `tarjeta.dart`).
- [ ] **Step 2: ResumenSeen** (mirror `alertas_seen.dart` de la task B2; usa `shared_preferences`, guarda epoch millis bajo una key; `debeMostrar` compara con 7 días). Como no hay `Date.now` en tests, inyecta `DateTime` por parámetro opcional para testear.
- [ ] **Step 3: card** — glass card cálida "Tu semana en plata 💸" con `resumen.texto`, botón "ya lo vi" → `marcarVisto()` + ocultar. Si `!tieneDatos` o `!debeMostrar` → `SizedBox.shrink`. Usa theme tokens.
- [ ] **Step 4: api + provider + wire en dashboard** (provider en `_refrescarDatos`).
- [ ] **Step 5: test** — render con override: muestra `texto`; tap "ya lo vi" llama `marcarVisto`. `pump(Duration)`.
- [ ] **Step 6: analyze + test. Commit** — `git commit -m "feat(front): card resumen semanal"`

---

# GRUPO F — Forecast de fin de mes

### Task F1: `forecast_service`

**Files:**
- Create: `backend/app/services/forecast_service.py`
- Test: `backend/tests/services/test_forecast_service.py`

**Interfaces:**
- Consumes: `presupuesto_service.estado_presupuestos` (gastado por categoría del mes).
- Produces: `proyectar_mes(session, user_id, hoy: date | None = None) -> dict`:
  ```
  { tiene_datos, dias_restantes, dia_del_mes,
    gasto_actual, gasto_proyectado,
    ingresos_mes, neto_proyectado | None,
    categorias_en_riesgo: [{categoria, tope, proyectado, pct}],
    confianza: 'baja'|'media'|'alta', caveat: str }
  ```
  Cálculo: `dia = hoy.day`; `dias_mes` = días del mes; `dias_restantes = dias_mes - dia`.
  `gasto_actual` = Σ|monto| (monto<0) del mes hasta hoy. `ritmo = gasto_actual / dia`.
  `gasto_proyectado = gasto_actual + ritmo * dias_restantes` (proyección lineal honesta).
  `ingresos_mes` = Σ monto (monto>0) del mes. `neto_proyectado = ingresos_mes - gasto_proyectado` **solo si ingresos_mes>0**, si no `None`.
  Por cada presupuesto con tope: `proy_cat = gastado_cat + (gastado_cat/dia)*dias_restantes`; riesgo si `proy_cat/tope > 1`.
  `confianza`: `dia < 5` → 'baja' (caveat "aún es temprano en el mes, la proyección puede cambiar"); `dia < 12` → 'media'; si no 'alta'. `tiene_datos=False` si `gasto_actual==0`.

- [ ] **Step 1: Tests que fallan**

```python
# backend/tests/services/test_forecast_service.py
import pytest
from datetime import date
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
import app.db.models  # noqa
from app.db.base import Base
from app.db.models import Transaction
from app.services.forecast_service import proyectar_mes

@pytest.fixture
def session():
    eng = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(eng)
    s = sessionmaker(bind=eng)()
    yield s
    s.close()

def _t(s, dia, monto, cat="Otros"):
    s.add(Transaction(user_id="u1", fecha=date(2026, 6, dia), descripcion="x", monto=monto,
                      moneda="CLP", tipo="gasto" if monto < 0 else "ingreso", categoria=cat, banco="b", fuente="test"))
    s.commit()

def test_proyeccion_lineal(session):
    # día 10, gastó 100.000 → ritmo 10.000/día, quedan 20 días → proyectado 300.000
    _t(session, 5, -50000); _t(session, 9, -50000)
    r = proyectar_mes(session, "u1", hoy=date(2026, 6, 10))
    assert r["tiene_datos"] is True
    assert r["gasto_actual"] == 100000
    assert r["gasto_proyectado"] == pytest.approx(300000)
    assert r["dias_restantes"] == 20

def test_neto_con_ingresos(session):
    _t(session, 5, -50000); _t(session, 9, -50000)
    _t(session, 1, 500000, "Otros")  # ingreso
    r = proyectar_mes(session, "u1", hoy=date(2026, 6, 10))
    assert r["ingresos_mes"] == 500000
    assert r["neto_proyectado"] == pytest.approx(200000)  # 500k - 300k

def test_neto_none_sin_ingresos(session):
    _t(session, 5, -50000)
    r = proyectar_mes(session, "u1", hoy=date(2026, 6, 10))
    assert r["neto_proyectado"] is None

def test_confianza_baja_temprano(session):
    _t(session, 1, -10000)
    r = proyectar_mes(session, "u1", hoy=date(2026, 6, 2))
    assert r["confianza"] == "baja"

def test_sin_datos(session):
    r = proyectar_mes(session, "u1", hoy=date(2026, 6, 10))
    assert r["tiene_datos"] is False
```

- [ ] **Step 2: Ver fallar. Step 3: Implementar** (usa `calendar.monthrange` para días del mes; reusa `estado_presupuestos`). **Step 4: Ver pasar.**
- [ ] **Step 5: Commit** — `git commit -m "feat(forecast): forecast_service (proyección lineal + neto)"`

---

### Task F2: Endpoint `GET /insights/forecast` + inyección al chat

**Files:**
- Modify: `backend/app/api/routes/insights.py`
- Modify: `backend/app/models/schemas.py` (`ForecastResponse`, `CategoriaRiesgo`)
- Modify: `backend/app/rag/rag_service.py` (`_build_resumen_block`: línea de proyección)
- Test: `backend/tests/api/test_forecast_endpoint.py`, extender `tests/services/test_resumen_presupuestos.py` o crear `test_resumen_forecast.py`

**Interfaces:** `GET /insights/forecast` → `ForecastResponse`. Chat: línea tipo "Proyección de junio: vas a gastar ~$X (neto proyectado $Y)".

- [ ] **Step 1: Tests que fallan** — endpoint 200 + shape; sin auth 401/403; `_build_resumen_block` con datos incluye "Proyección".
- [ ] **Step 2: Ver fallar.**
- [ ] **Step 3: Schemas + endpoint + inyección** (la inyección, dentro del `try` de `_build_resumen_block`, en bloque `try/except` defensivo como el de tarjeta; solo si `tiene_datos`).
- [ ] **Step 4: Ver pasar. Step 5: Commit** — `git commit -m "feat(forecast): endpoint + inyección al chat"`

---

### Task F3: Frontend — ForecastCard en dashboard

**Files:**
- Create: `frontend/lib/models/forecast.dart`
- Create: `frontend/lib/widgets/forecast_card.dart`
- Modify: `frontend/lib/services/api_service.dart` (`getForecast`)
- Modify: `frontend/lib/providers/data_providers.dart` (`forecastProvider`)
- Modify: `frontend/lib/screens/dashboard_screen.dart` (card + provider en `_refrescarDatos`)
- Test: `frontend/test/widgets/forecast_card_test.dart`

- [ ] **Step 1: modelo + fromJson + test** (incluye `categoriasEnRiesgo`).
- [ ] **Step 2: api + provider** (mirror tarjeta).
- [ ] **Step 3: ForecastCard** — "Proyección de [mes]": `gasto_proyectado` grande; si `neto_proyectado != null` mostrar "te sobran/faltan $X" (salvia si ≥0, salmón si <0); lista corta de `categorias_en_riesgo` ("te vas a pasar en {cat}"); si `confianza=='baja'` mostrar el `caveat` en chico. Si `!tieneDatos` → CTA "sube tu cartola para proyectar". Theme tokens + formatCLP.
- [ ] **Step 4: wire dashboard + provider en `_refrescarDatos`.**
- [ ] **Step 5: test render. Step 6: analyze+test. Commit** — `git commit -m "feat(front): ForecastCard"`

---

# GRUPO V — Boletas por foto (OCR)

### Task V1: `extraer_boleta` (prompt afinado para recibos)

**Files:**
- Modify: `backend/app/services/extraction_service.py` (nueva `extraer_boleta`; reusa base64 + vision LLM existente)
- Test: `backend/tests/services/test_extraer_boleta.py` (mock del LLM)

**Interfaces:**
- Produces: `extraer_boleta(content: bytes, ext: str) -> dict | None` → `{comercio, monto (float, NEGATIVO = gasto), fecha (YYYY-MM-DD str), categoria}` o `None` si la imagen no es legible / no es boleta. Usa un `BoletaExtraida` (`BaseModel`: `es_boleta: bool`, `comercio: str = ""`, `monto: float = 0`, `fecha: str | None = None`, `categoria: str | None = None`) con `.with_structured_output`. Prompt: "Eres un extractor de BOLETAS/recibos chilenos. De la imagen extrae el TOTAL pagado (monto, positivo), el comercio, la fecha (YYYY-MM-DD) y una categoría de [CATEGORIAS]. Si no es una boleta legible, es_boleta=false." En el map: `monto = -abs(total)`, `categoria = categorizar_por_reglas(comercio) or normalizar(cat) or "Otros"`.

- [ ] **Step 1: Test que falla** (mock `_extractor_boleta` para devolver un `BoletaExtraida`): boleta válida → dict con monto negativo + categoría; `es_boleta=false` → None.

```python
# patrón: monkeypatch sobre extraction_service._extractor_boleta para que .invoke devuelva un BoletaExtraida fijo
def test_extraer_boleta_ok(monkeypatch):
    from app.services import extraction_service as ex
    class _Fake:
        def invoke(self, *_a, **_k):
            return ex.BoletaExtraida(es_boleta=True, comercio="LIDER", monto=12990, fecha="2026-06-20", categoria=None)
    monkeypatch.setattr(ex, "_extractor_boleta", lambda: _Fake())
    out = ex.extraer_boleta(b"fakebytes", "jpg")
    assert out["monto"] == -12990
    assert out["categoria"] == "Supermercado"   # por reglas (LIDER)
    assert out["fecha"] == "2026-06-20"

def test_extraer_boleta_no_es_boleta(monkeypatch):
    from app.services import extraction_service as ex
    class _Fake:
        def invoke(self, *_a, **_k): return ex.BoletaExtraida(es_boleta=False)
    monkeypatch.setattr(ex, "_extractor_boleta", lambda: _Fake())
    assert ex.extraer_boleta(b"x", "jpg") is None
```

- [ ] **Step 2: Ver fallar. Step 3: Implementar** (reusa el patrón de `extract_from_image` para el `HumanMessage` con `image_url`). **Step 4: Ver pasar.**
- [ ] **Step 5: Commit** — `git commit -m "feat(boletas): extraer_boleta (visión, prompt de recibo)"`

---

### Task V2: Endpoints `POST /transactions/boleta` (draft) + `POST /transactions/manual` (guardar)

**Files:**
- Modify: `backend/app/api/routes/upload.py`
- Modify: `backend/app/models/schemas.py` (`BoletaDraftOut`, `ManualTxnIn`)
- Test: `backend/tests/api/test_boleta.py`

**Interfaces:**
- `POST /transactions/boleta` (multipart `file`) → `BoletaDraftOut {comercio, monto, fecha, categoria}` SIN guardar. Cuenta contra el límite (`check_limit`/`log_upload`) porque es una llamada de visión (costo). Si `extraer_boleta` devuelve None → 422 "No pudimos leer la boleta".
- `POST /transactions/manual` body `ManualTxnIn {comercio, monto, fecha, categoria}` → guarda una transacción (`fuente="boleta"`, `banco="efectivo"`) vía `insert_transactions` + `indexar_transacciones`; valida `categoria ∈ CATEGORIAS`. Devuelve `UploadResponse` o `{ok:true, id}`.

- [ ] **Step 1: Tests que fallan** (mock `extraer_boleta`): boleta → 200 con draft; no-boleta → 422; `POST /transactions/manual` guarda y aparece en `GET /transactions`; categoría inválida → 422; sin auth → 401/403.
- [ ] **Step 2: Ver fallar. Step 3: Implementar** (reusa `insert_transactions(session, user_id, [Transaccion(...)], fuente="boleta")`). **Step 4: Ver pasar (archivo + suite).**
- [ ] **Step 5: Commit** — `git commit -m "feat(boletas): endpoints boleta (draft) + manual (guardar)"`

---

### Task V3: Frontend — modelos, api, image_picker

**Files:**
- Modify: `frontend/pubspec.yaml` (`image_picker: ^1.1.2`)
- Create: `frontend/lib/models/boleta_draft.dart`
- Modify: `frontend/lib/services/api_service.dart` (`escanearBoleta(Uint8List, String) -> BoletaDraft`, `crearManual({comercio, monto, fecha, categoria}) -> void`)
- Test: `frontend/test/models/boleta_draft_test.dart`

- [ ] **Step 1: dep + `flutter pub get`.**
- [ ] **Step 2: modelo BoletaDraft + fromJson + test.**
- [ ] **Step 3: api methods** (`escanearBoleta` = multipart como `uploadFile`; `crearManual` = POST json). 
- [ ] **Step 4: analyze + test. Commit** — `git commit -m "feat(front): image_picker + api boletas"`

---

### Task V4: Frontend — capturar boleta + pantalla de confirmación

**Files:**
- Create: `frontend/lib/screens/boleta_confirm_screen.dart`
- Modify: `frontend/lib/router.dart` (`/boleta`)
- Modify: `frontend/lib/screens/dashboard_screen.dart` (acción "Escanear boleta" — botón/FAB; tras guardar, `_refrescarDatos`)
- Test: `frontend/test/screens/boleta_confirm_screen_test.dart`

**Interfaces:** Consumes `escanearBoleta`, `crearManual` (V3).

- [ ] **Step 1: flujo de captura** — acción "Escanear boleta" usa `ImagePicker().pickImage(source: camera/gallery)` (en web cae a galería). Lee bytes → `escanearBoleta` → navega a `/boleta` con el draft. (Maneja cancelación y error con SnackBar.)
- [ ] **Step 2: pantalla de confirmación** — muestra los campos editables: comercio (TextField), monto (TextField numérico, formateado), fecha (date picker), categoría (chips de `kCategorias`). Botón "Guardar gasto" → `crearManual(...)` → volver al dashboard + refrescar. Botón "cancelar".
- [ ] **Step 3: router + wire dashboard.**
- [ ] **Step 4: test** — render de la pantalla con un draft fijo: muestra comercio/monto; tap "Guardar" llama `crearManual`. `pump(Duration)`.
- [ ] **Step 5: analyze + test. Commit** — `git commit -m "feat(front): escanear boleta + confirmación"`

---

## Post-implementación
1. Backend: `cd backend && .venv/Scripts/python.exe -m pytest -q` verde.
2. Front: `C:/flutter/bin/flutter analyze && C:/flutter/bin/flutter test` verde.
3. **Sin migraciones.** Deploy: HF (upload_folder) + push para Pages. Verificar `/insights/forecast`, `/insights/resumen-semanal`, `/transactions/boleta` responden auth-gated (401/403).
4. Validación real (usuario): subir cartola y mirar la proyección; sacar foto a una boleta y confirmarla; ver la card de resumen semanal.

## Self-review
- F (forecast) ✓ F1-F3 (gasto + neto + riesgo por presupuesto + confianza + chat). 
- V (boletas) ✓ V1-V4 (reúso visión + prompt recibo + confirmar antes de guardar + cámara/galería).
- S (resumen) ✓ S1-S3 (plantilla determinista + card semanal descartable).
- Sin migraciones. Tests por task con LLM mockeado. Reúso de servicios existentes (estado_presupuestos, insert_transactions, extract_from_image, alertas_seen pattern).
