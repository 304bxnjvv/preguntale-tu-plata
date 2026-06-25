# Presupuestos + Metas, Alertas, y Categorización que aprende — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Agregar tres features (topes de presupuesto + metas de ahorro, alertas in-app + notificación local, y categorización que aprende de correcciones) a la app de finanzas chilena, reusando los patrones existentes.

**Architecture:** Backend FastAPI + SQLAlchemy sobre Supabase (migraciones SQL aplicadas con script psycopg2). Frontend Flutter + Riverpod (`FutureProvider`) + go_router + fl_chart. Cada feature es un grupo de tareas independiente y testeable. Orden: **C (categoriza) → A (presupuestos+metas) → B (alertas)**.

**Tech Stack:** Python 3.11, FastAPI, SQLAlchemy 2.0, Pydantic, pytest (sqlite in-memory). Flutter 3.8, flutter_riverpod, go_router, fl_chart, shared_preferences, flutter_local_notifications, mocktail.

## Global Constraints
- Mobile-first, español chileno, tono cálido, mensajes cortos.
- Montos con `formatCLP` del front ("$1.234.567") y `f"${x:,.0f}".replace(",", ".")` en el back.
- Categorías = las 11 de `app/services/categorias.py::CATEGORIAS`. Validar contra esa lista.
- Prefijo API `/api/v1`. Endpoints nuevos cuelgan de él (tests usan `/api/v1/...`).
- Tests: LLM siempre mockeado, fixtures sintéticos. **Nunca** datos personales reales en tests ni repo.
- No romper flujos existentes (upload, límite, dedup, RAG, tarjeta, finscore).
- Modelos SQLAlchemy: ids `String(36)` con `default=lambda: str(uuid.uuid4())` (las migraciones SQL usan `uuid`/`gen_random_uuid()` para Postgres; sqlite de tests usa los modelos).
- RLS en cada tabla nueva (mismo patrón que `005_tarjeta_estado.sql`).
- Migraciones se aplican con el script psycopg2 existente leyendo `POSTGRES_URL` del `.env`.
- Lint/type: `ruff check .` y `mypy app` deben pasar; front `flutter analyze` sin issues.

---

# GRUPO C — Categorización que aprende

### Task C1: `comercio_key` (clave de comercio normalizada)

**Files:**
- Modify: `backend/app/services/categorias.py`
- Test: `backend/tests/services/test_categorias.py` (crear si no existe)

**Interfaces:**
- Produces: `comercio_key(descripcion: str) -> str` — minúsculas, sin tildes, sin dígitos ni puntuación, espacios colapsados, trim.

- [ ] **Step 1: Test que falla**

```python
# backend/tests/services/test_categorias.py
from app.services.categorias import comercio_key

def test_comercio_key_normaliza():
    assert comercio_key("UBER EATS *1234 STGO") == "uber eats stgo"
    assert comercio_key("Líder  Express 0098") == "lider express"
    assert comercio_key("  NETFLIX.COM  ") == "netflix com"

def test_comercio_key_vacio():
    assert comercio_key("12345 ****") == ""
```

- [ ] **Step 2: Correr y ver fallar**

Run: `cd backend && pytest tests/services/test_categorias.py -v`
Expected: FAIL `ImportError: cannot import name 'comercio_key'`

- [ ] **Step 3: Implementar**

```python
# en categorias.py, reusa _strip_accents ya existente
def comercio_key(descripcion: str) -> str:
    """Clave de comercio para overrides: sin tildes, sin dígitos/puntuación, espacios colapsados."""
    s = _strip_accents(descripcion).lower()
    s = re.sub(r"[^a-z\s]", " ", s)   # quita dígitos y puntuación
    s = re.sub(r"\s+", " ", s).strip()
    return s
```

- [ ] **Step 4: Correr y ver pasar**

Run: `cd backend && pytest tests/services/test_categorias.py -v`
Expected: PASS

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(categorias): comercio_key para overrides"`

---

### Task C2: Modelos override + columna `categoria_manual` + migración 007 + service

**Files:**
- Modify: `backend/app/db/models.py` (nuevo `CategoriaOverride`; columna `categoria_manual` en `Transaction`; importar `Boolean`)
- Create: `backend/migrations/007_categoria_override.sql`
- Create: `backend/app/services/categoria_override_service.py`
- Test: `backend/tests/services/test_categoria_override.py`

**Interfaces:**
- Produces:
  - `CategoriaOverride` (tabla `categoria_overrides`, UNIQUE user_id+comercio_key).
  - `Transaction.categoria_manual: bool` (default False).
  - `get_override(session, user_id, descripcion) -> str | None` (match: el `comercio_key` guardado es substring del `comercio_key(descripcion)`).
  - `upsert_override(session, user_id, comercio_key, categoria) -> None`.

- [ ] **Step 1: Test que falla**

```python
# backend/tests/services/test_categoria_override.py
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
import app.db.models  # noqa
from app.db.base import Base
from app.services.categoria_override_service import get_override, upsert_override

@pytest.fixture
def session():
    eng = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(eng)
    s = sessionmaker(bind=eng)()
    yield s
    s.close()

def test_upsert_y_get_override(session):
    upsert_override(session, "u1", "uber eats", "Comida y delivery")
    assert get_override(session, "u1", "UBER EATS *9988 STGO") == "Comida y delivery"

def test_get_override_sin_match(session):
    assert get_override(session, "u1", "FALABELLA 123") is None

def test_upsert_reemplaza(session):
    upsert_override(session, "u1", "uber eats", "Comida y delivery")
    upsert_override(session, "u1", "uber eats", "Transporte")
    assert get_override(session, "u1", "uber eats 1") == "Transporte"

def test_override_es_por_usuario(session):
    upsert_override(session, "u1", "uber eats", "Comida y delivery")
    assert get_override(session, "u2", "uber eats") is None
```

- [ ] **Step 2: Correr y ver fallar** — `pytest tests/services/test_categoria_override.py -v` → FAIL import.

- [ ] **Step 3: Implementar modelos** (en `app/db/models.py`)

```python
# añadir Boolean al import de sqlalchemy
from sqlalchemy import Column, String, Text, Numeric, Date, DateTime, Integer, Boolean, UniqueConstraint

# en class Transaction, tras `categoria`:
    categoria_manual = Column(Boolean, nullable=False, default=False)

# nueva clase
class CategoriaOverride(Base):
    __tablename__ = "categoria_overrides"
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), nullable=False, index=True)
    comercio_key = Column(String, nullable=False)
    categoria = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    __table_args__ = (UniqueConstraint("user_id", "comercio_key", name="uq_override_user_key"),)
```

- [ ] **Step 4: Implementar service**

```python
# backend/app/services/categoria_override_service.py
from __future__ import annotations
from sqlalchemy.orm import Session
from app.db.models import CategoriaOverride
from app.services.categorias import comercio_key

def upsert_override(session: Session, user_id: str, key: str, categoria: str) -> None:
    row = session.query(CategoriaOverride).filter_by(user_id=user_id, comercio_key=key).first()
    if row is None:
        session.add(CategoriaOverride(user_id=user_id, comercio_key=key, categoria=categoria))
    else:
        row.categoria = categoria
    session.commit()

def get_override(session: Session, user_id: str, descripcion: str) -> str | None:
    desc_key = comercio_key(descripcion)
    if not desc_key:
        return None
    for row in session.query(CategoriaOverride).filter_by(user_id=user_id).all():
        if row.comercio_key and row.comercio_key in desc_key:
            return row.categoria
    return None
```

- [ ] **Step 5: Migración** `backend/migrations/007_categoria_override.sql`

```sql
create table if not exists categoria_overrides (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  comercio_key text not null,
  categoria    text not null,
  created_at   timestamptz default now(),
  updated_at   timestamptz default now(),
  unique (user_id, comercio_key)
);
create index if not exists idx_cat_override_user on categoria_overrides (user_id);
alter table categoria_overrides enable row level security;
create policy "override_select" on categoria_overrides for select using (auth.uid() = user_id);
create policy "override_insert" on categoria_overrides for insert with check (auth.uid() = user_id);
create policy "override_update" on categoria_overrides for update using (auth.uid() = user_id);
create policy "override_delete" on categoria_overrides for delete using (auth.uid() = user_id);

alter table transactions add column if not exists categoria_manual boolean not null default false;
```

- [ ] **Step 6: Correr y ver pasar** — `pytest tests/services/test_categoria_override.py -v` → PASS.

- [ ] **Step 7: Commit** — `git commit -m "feat(categorias): tabla overrides + categoria_manual + migración 007"`

---

### Task C3: Aplicar override en inserción + endpoint `PATCH /transactions/{id}`

**Files:**
- Modify: el service de inserción de transacciones (buscar `def insert_transactions` con `grep -rn "def insert_transactions" backend/app`). Aplicar override antes de persistir cada txn.
- Modify: `backend/app/api/routes/upload.py` o donde estén las rutas de transactions (buscar el router que sirve `GET /transactions`). Añadir `PATCH /transactions/{id}`.
- Modify: `backend/app/models/schemas.py` (schema `EditarCategoriaIn`, `EditarCategoriaOut`).
- Test: `backend/tests/api/test_editar_categoria.py`

**Interfaces:**
- Consumes: `get_override`, `upsert_override` (C2), `comercio_key` (C1), `normalizar`/`CATEGORIAS` (existentes).
- Produces:
  - En inserción: cada txn nueva con `categoria_manual=False` recibe `categoria = get_override(...) or <categoría actual de extracción>`.
  - `PATCH /transactions/{id}` body `{"categoria": str}` → `{"actualizadas": int}`. Setea la txn (categoria + `categoria_manual=True`), upsert override, y recategoriza las pasadas mismo `comercio_key` con `categoria_manual=False`.

- [ ] **Step 1: Test que falla**

```python
# backend/tests/api/test_editar_categoria.py
import pytest
from datetime import date
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
import app.db.models  # noqa
from app.main import app
from app.db.base import Base, get_session
from app.auth.jwt import get_current_user
from app.db.models import Transaction

@pytest.fixture
def ctx():
    eng = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(eng)
    TS = sessionmaker(bind=eng)
    def _ov():
        s = TS()
        try: yield s
        finally: s.close()
    app.dependency_overrides[get_session] = _ov
    app.dependency_overrides[get_current_user] = lambda: "u1"
    yield TS
    app.dependency_overrides.clear()

def _mk(s, desc, cat):
    t = Transaction(user_id="u1", fecha=date(2026, 6, 1), descripcion=desc, monto=-1000,
                    moneda="CLP", tipo="gasto", categoria=cat, banco="x", fuente="test")
    s.add(t); s.commit(); s.refresh(t); return t.id

def test_editar_categoria_marca_manual_y_recategoriza(ctx):
    s = ctx()
    id1 = _mk(s, "UBER EATS 1", "Otros")
    id2 = _mk(s, "UBER EATS 2", "Otros")   # mismo comercio, no manual
    c = TestClient(app)
    r = c.patch(f"/api/v1/transactions/{id1}", json={"categoria": "Comida y delivery"})
    assert r.status_code == 200
    assert r.json()["actualizadas"] >= 2     # la editada + la pasada
    s2 = ctx()
    assert s2.query(Transaction).filter_by(id=id1).first().categoria == "Comida y delivery"
    assert s2.query(Transaction).filter_by(id=id1).first().categoria_manual is True
    assert s2.query(Transaction).filter_by(id=id2).first().categoria == "Comida y delivery"

def test_editar_categoria_invalida_422(ctx):
    s = ctx(); idx = _mk(s, "X", "Otros")
    c = TestClient(app)
    r = c.patch(f"/api/v1/transactions/{idx}", json={"categoria": "NoExiste"})
    assert r.status_code == 422

def test_editar_categoria_no_pisa_otra_manual(ctx):
    s = ctx()
    id1 = _mk(s, "UBER EATS 1", "Salud")
    s.query(Transaction).filter_by(id=id1).update({"categoria_manual": True}); s.commit()
    id2 = _mk(s, "UBER EATS 2", "Otros")
    c = TestClient(app)
    c.patch(f"/api/v1/transactions/{id2}", json={"categoria": "Comida y delivery"})
    s2 = ctx()
    # id1 era manual con otra categoría → no se pisa
    assert s2.query(Transaction).filter_by(id=id1).first().categoria == "Salud"
```

- [ ] **Step 2: Correr y ver fallar** — `pytest tests/api/test_editar_categoria.py -v` → FAIL 404/405.

- [ ] **Step 3: Schemas** (en `schemas.py`)

```python
class EditarCategoriaIn(BaseModel):
    categoria: str

class EditarCategoriaOut(BaseModel):
    actualizadas: int
```

- [ ] **Step 4: Endpoint** (en el router de transactions; mismo prefijo que `GET /transactions`)

```python
from fastapi import HTTPException
from app.services.categorias import CATEGORIAS, comercio_key
from app.services.categoria_override_service import upsert_override
from app.db.models import Transaction
from app.models.schemas import EditarCategoriaIn, EditarCategoriaOut

@router.patch("/transactions/{txn_id}", response_model=EditarCategoriaOut)
async def editar_categoria(
    txn_id: str,
    body: EditarCategoriaIn,
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    if body.categoria not in CATEGORIAS:
        raise HTTPException(status_code=422, detail="categoría inválida")
    txn = session.query(Transaction).filter_by(id=txn_id, user_id=user_id).first()
    if txn is None:
        raise HTTPException(status_code=404, detail="transacción no encontrada")
    txn.categoria = body.categoria
    txn.categoria_manual = True
    key = comercio_key(txn.descripcion)
    upsert_override(session, user_id, key, body.categoria)
    actualizadas = 1
    if key:
        otras = (session.query(Transaction)
                 .filter(Transaction.user_id == user_id, Transaction.id != txn_id,
                         Transaction.categoria_manual.is_(False)).all())
        for o in otras:
            if key in comercio_key(o.descripcion):
                o.categoria = body.categoria
                actualizadas += 1
    session.commit()
    return EditarCategoriaOut(actualizadas=actualizadas)
```

- [ ] **Step 5: Override en inserción** — en `insert_transactions` (donde se crea cada `Transaction`), antes de persistir:

```python
from app.services.categoria_override_service import get_override
# ...por cada txn nueva (categoria_manual queda en False por default):
ov = get_override(session, user_id, descripcion)
if ov is not None:
    categoria = ov
```
(Aplica override por encima de lo que asignó la extracción regla/LLM.)

- [ ] **Step 6: Correr y ver pasar** — `pytest tests/api/test_editar_categoria.py -v` → PASS. Luego `pytest` completo verde.

- [ ] **Step 7: Commit** — `git commit -m "feat(transactions): PATCH categoria + override en inserción"`

---

### Task C4: Frontend — editar categoría desde Movimientos

**Files:**
- Modify: `frontend/lib/services/api_service.dart` (`editarCategoria`)
- Modify: `frontend/lib/widgets/transaction_tile.dart` (tap → bottom sheet con chips de categorías; convertir a `ConsumerWidget` o recibir callback)
- Modify: `frontend/lib/screens/dashboard_screen.dart` (al editar, refrescar `summaryProvider`, `transactionsProvider`, y el provider de la dona)
- Test: `frontend/test/widgets/transaction_tile_test.dart`

**Interfaces:**
- Consumes: `PATCH /transactions/{id}` (C3).
- Produces: `ApiService.editarCategoria(String id, String categoria) -> Future<int>` (devuelve `actualizadas`).

- [ ] **Step 1: api method**

```dart
Future<int> editarCategoria(String id, String categoria) async {
  final res = await _client.patch(
    Uri.parse('$baseUrl/transactions/$id'),
    headers: _headers({'Content-Type': 'application/json; charset=utf-8'}),
    body: jsonEncode({'categoria': categoria}),
  );
  if (res.statusCode == 200) {
    return (jsonDecode(utf8.decode(res.bodyBytes))['actualizadas'] as num).toInt();
  }
  throw ApiException('No se pudo cambiar la categoría', res.statusCode);
}
```

- [ ] **Step 2: Constante de categorías** — crear `frontend/lib/models/categorias.dart`:

```dart
const kCategorias = <String>[
  'Comida y delivery','Supermercado','Transporte','Cuentas y servicios',
  'Suscripciones','Salud','Entretención','Compras','Efectivo','Transferencias','Otros',
];
```

- [ ] **Step 3: tile editable** — `TransactionTile` recibe `VoidCallback? onCategoriaChanged` y un `WidgetRef`/callback; en `onTap` abre `showModalBottomSheet` con `Wrap` de `ChoiceChip` (resaltando `t.categoria`). Al elegir: `await ref.read(apiProvider).editarCategoria(t.id, cat)`, cerrar sheet, llamar `onCategoriaChanged?.call()`. Usar `AppColors`/`AppText` del theme. (Leer el archivo actual y mantener el layout del `ListTile`.)

- [ ] **Step 4: wire en dashboard** — donde se construye `TransactionTile`, pasar `onCategoriaChanged: () { ref.invalidate(summaryProvider); ref.invalidate(transactionsProvider); /* + provider de la dona si aplica */ }`.

- [ ] **Step 5: test** — widget test: dado un `TransactionTile` con categoría "Otros", `tap` abre el sheet y muestra los 11 chips. Usar `mocktail` para `ApiService`. `pump(Duration(...))` (no `pumpAndSettle`, por el Orb). 

- [ ] **Step 6: analyze + test** — `cd frontend && flutter analyze && flutter test test/widgets/transaction_tile_test.dart`

- [ ] **Step 7: Commit** — `git commit -m "feat(front): editar categoría de transacción"`

---

# GRUPO A — Presupuestos + Metas

### Task A1: Modelos `Presupuesto` + `Meta` + migración 006

**Files:**
- Modify: `backend/app/db/models.py`
- Create: `backend/migrations/006_presupuestos_metas.sql`
- Test: `backend/tests/services/test_presupuesto_meta_models.py`

**Interfaces:**
- Produces: `Presupuesto` (UNIQUE user_id+categoria), `Meta`.

- [ ] **Step 1: Test que falla** — crea un `Presupuesto` y una `Meta` en sqlite, verifica persistencia y la unique de presupuesto (insertar misma user+categoria dos veces → `IntegrityError` al commit).

- [ ] **Step 2: Ver fallar** — `pytest tests/services/test_presupuesto_meta_models.py -v`

- [ ] **Step 3: Modelos**

```python
class Presupuesto(Base):
    __tablename__ = "presupuestos"
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), nullable=False, index=True)
    categoria = Column(String, nullable=False)
    monto_tope = Column(Numeric, nullable=False, default=0)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    __table_args__ = (UniqueConstraint("user_id", "categoria", name="uq_presupuesto_user_cat"),)

class Meta(Base):
    __tablename__ = "metas"
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), nullable=False, index=True)
    nombre = Column(String, nullable=False)
    monto_objetivo = Column(Numeric, nullable=False, default=0)
    monto_actual = Column(Numeric, nullable=False, default=0)
    fecha_objetivo = Column(Date, nullable=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
```

- [ ] **Step 4: Migración** `006_presupuestos_metas.sql` — tablas `presupuestos` (unique user_id+categoria) y `metas`, ambas con índice por user_id + RLS (4 policies cada una, patrón de 005).

- [ ] **Step 5: Ver pasar** — `pytest tests/services/test_presupuesto_meta_models.py -v`

- [ ] **Step 6: Commit** — `git commit -m "feat(db): modelos presupuestos+metas + migración 006"`

---

### Task A2: `presupuesto_service`

**Files:**
- Create: `backend/app/services/presupuesto_service.py`
- Test: `backend/tests/services/test_presupuesto_service.py`

**Interfaces:**
- Produces:
  - `set_tope(session, user_id, categoria, monto_tope) -> dict` (UPSERT; ValueError si categoria ∉ CATEGORIAS).
  - `delete_tope(session, user_id, categoria) -> bool`.
  - `estado_presupuestos(session, user_id) -> list[dict]`: `[{categoria, monto_tope, gastado, pct, estado}]`. `gastado` = Σ|monto| del mes actual (monto<0, esa categoría). `estado`: `ok`(<0.8) / `cerca`(0.8–1.0) / `excedido`(>1.0).

- [ ] **Step 1: Tests que fallan**

```python
def test_set_tope_y_estado_ok(session):
    set_tope(session, "u1", "Comida y delivery", 100000)
    # gasto 50.000 este mes en esa categoría → pct 0.5, estado ok
    _mk_gasto(session, "u1", "Comida y delivery", -50000)   # helper con fecha = hoy
    est = estado_presupuestos(session, "u1")
    fila = next(e for e in est if e["categoria"] == "Comida y delivery")
    assert fila["gastado"] == 50000
    assert fila["estado"] == "ok"

def test_estado_excedido(session):
    set_tope(session, "u1", "Compras", 10000)
    _mk_gasto(session, "u1", "Compras", -15000)
    fila = estado_presupuestos(session, "u1")[0]
    assert fila["estado"] == "excedido"

def test_set_tope_categoria_invalida(session):
    with pytest.raises(ValueError):
        set_tope(session, "u1", "NoExiste", 1000)

def test_delete_tope(session):
    set_tope(session, "u1", "Salud", 5000)
    assert delete_tope(session, "u1", "Salud") is True
    assert estado_presupuestos(session, "u1") == []
```

- [ ] **Step 2: Ver fallar.**

- [ ] **Step 3: Implementar** — usar la lógica de rango de mes de `comparativo_mensual` (curr_start / next_month_start) para sumar gastos. `set_tope` valida `categoria in CATEGORIAS` y hace upsert por (user_id, categoria). `estado` por umbrales.

- [ ] **Step 4: Ver pasar.**

- [ ] **Step 5: Commit** — `git commit -m "feat(presupuestos): presupuesto_service"`

---

### Task A3: `meta_service`

**Files:**
- Create: `backend/app/services/meta_service.py`
- Test: `backend/tests/services/test_meta_service.py`

**Interfaces:**
- Produces:
  - `crear_meta(session, user_id, nombre, monto_objetivo, fecha_objetivo: str|None) -> dict`
  - `actualizar_meta(session, user_id, meta_id, **campos) -> dict | None`
  - `eliminar_meta(session, user_id, meta_id) -> bool`
  - `listar_metas(session, user_id) -> list[dict]`: cada meta `{id, nombre, monto_objetivo, monto_actual, fecha_objetivo, progreso, aporte_mensual_necesario}`. `progreso` = clamp(actual/objetivo, 0, 1) (0 si objetivo 0). `aporte_mensual_necesario` = `(objetivo-actual)/meses` si hay fecha futura (meses = max(1, round(días/30))), si no `null`; nunca negativo.

- [ ] **Step 1: Tests que fallan** — crear meta, listar (progreso correcto), actualizar monto_actual, calcular aporte con fecha futura, `null` sin fecha, eliminar.

- [ ] **Step 2: Ver fallar. Step 3: Implementar. Step 4: Ver pasar.**

- [ ] **Step 5: Commit** — `git commit -m "feat(metas): meta_service"`

---

### Task A4: Endpoints presupuestos + metas

**Files:**
- Create: `backend/app/api/routes/presupuestos.py` (router con presupuestos y metas)
- Modify: `backend/app/main.py` (registrar el router con prefijo `/api/v1`, como los demás)
- Modify: `backend/app/models/schemas.py` (schemas in/out)
- Test: `backend/tests/api/test_presupuestos.py`

**Interfaces (endpoints, todos auth + session):**
- `GET /presupuestos` → `{items: [PresupuestoEstadoOut]}`
- `POST /presupuestos` body `{categoria, monto_tope}` → `PresupuestoEstadoOut` (422 si categoria inválida)
- `DELETE /presupuestos/{categoria}` → `{ok: bool}`
- `GET /metas` → `{items: [MetaOut]}`
- `POST /metas` body `{nombre, monto_objetivo, fecha_objetivo?}` → `MetaOut`
- `PATCH /metas/{id}` body parcial `{nombre?, monto_objetivo?, monto_actual?, fecha_objetivo?}` → `MetaOut` (404 si no existe)
- `DELETE /metas/{id}` → `{ok: bool}`

- [ ] **Step 1: Tests que fallan** — replicar el patrón de `test_insights.py` (fixture sqlite + overrides). Cubrir: POST presupuesto 200 + shape; categoria inválida 422; GET lista; DELETE 200; POST meta + GET metas con progreso; PATCH monto_actual; DELETE meta; los GET sin auth → 401/403.

- [ ] **Step 2: Ver fallar.**

- [ ] **Step 3: Schemas + router + registrar en main.** (Mirar cómo se incluye `insights.router` en `main.py` y replicar con `app.include_router(presupuestos.router, prefix="/api/v1")` o el patrón existente.)

- [ ] **Step 4: Ver pasar** — `pytest tests/api/test_presupuestos.py -v`, luego suite completa.

- [ ] **Step 5: Commit** — `git commit -m "feat(api): endpoints presupuestos + metas"`

---

### Task A5: Inyección al chat (resumen)

**Files:**
- Modify: `backend/app/rag/rag_service.py` (`_build_resumen_block`)
- Test: `backend/tests/services/test_resumen_presupuestos.py` (o extender el test de rag existente)

**Interfaces:**
- Consumes: `estado_presupuestos` (A2), `listar_metas` (A3).
- Produces: líneas extra en el resumen para presupuestos en `cerca`/`excedido` y metas con progreso.

- [ ] **Step 1: Test que falla** — con un presupuesto excedido en la DB, `_build_resumen_block(session, "u1")` contiene el nombre de la categoría y "excedido"/"%"; con una meta, contiene su nombre.

- [ ] **Step 2: Ver fallar.**

- [ ] **Step 3: Implementar** — dentro del `try` de `_build_resumen_block`, tras la tarjeta, agregar bloque `try/except` que liste presupuestos `cerca`/`excedido` y metas (mismo estilo defensivo que el bloque de tarjeta).

- [ ] **Step 4: Ver pasar. Step 5: Commit** — `git commit -m "feat(chat): inyectar presupuestos y metas al resumen"`

---

### Task A6: Frontend — modelos, api, providers

**Files:**
- Create: `frontend/lib/models/presupuesto.dart`, `frontend/lib/models/meta.dart`
- Modify: `frontend/lib/services/api_service.dart` (getPresupuestos, setTope, deleteTope, getMetas, crearMeta, actualizarMeta, eliminarMeta)
- Modify: `frontend/lib/providers/data_providers.dart` (`presupuestosProvider`, `metasProvider` + exports)
- Test: `frontend/test/models/presupuesto_meta_test.dart`

**Interfaces:**
- `PresupuestoEstado.fromJson` ({categoria, montoTope, gastado, pct, estado}); `Meta.fromJson` ({id, nombre, montoObjetivo, montoActual, fechaObjetivo, progreso, aporteMensualNecesario}).
- Providers `FutureProvider` que llaman las api methods (patrón `tarjetaProvider`).

- [ ] **Step 1: Modelos + fromJson + tests** (mirror `tarjeta.dart`). Test fromJson de ambos.
- [ ] **Step 2: api methods** (mirror `getTarjeta` / `setTope` POST como `ask`). 
- [ ] **Step 3: providers + exports** (mirror `tarjetaProvider`).
- [ ] **Step 4: analyze + test** — `flutter analyze && flutter test test/models/presupuesto_meta_test.dart`
- [ ] **Step 5: Commit** — `git commit -m "feat(front): modelos/api/providers presupuestos+metas"`

---

### Task A7: Frontend — pantalla `/presupuestos` + card en dashboard

**Files:**
- Create: `frontend/lib/screens/presupuestos_screen.dart`
- Create: `frontend/lib/widgets/presupuesto_card.dart` (card resumen para dashboard)
- Modify: `frontend/lib/router.dart` (GoRoute `/presupuestos`)
- Modify: `frontend/lib/screens/dashboard_screen.dart` (insertar card + incluir `presupuestosProvider` en `_refrescarDatos`)
- Test: `frontend/test/screens/presupuestos_screen_test.dart`

**Interfaces:**
- Consumes: `presupuestosProvider` (A6).

- [ ] **Step 1: Pantalla** — `/presupuestos`: lista de categorías con barra de progreso (`LinearProgressIndicator` o barra custom): color salvia (<0.8), ámbar (0.8–1.0), salmón (>1.0). FAB/botón "+ tope" → `showModalBottomSheet` con dropdown de `kCategorias` + campo monto → `setTope` → invalidar `presupuestosProvider`. Swipe/botón borrar → `deleteTope`. Usar theme tokens y `formatCLP`.
- [ ] **Step 2: Card dashboard** — `PresupuestoCard`: si hay ≥1 `cerca`/`excedido` muestra "N categorías cerca del tope" en ámbar/salmón, si no "vas bien con tus topes"; `onTap` → `context.push('/presupuestos')`. Vacío (sin topes) → CTA "fija tu primer presupuesto".
- [ ] **Step 3: Router + dashboard wire** — GoRoute; insertar `PresupuestoCard` en el `ListView` (cerca del resumen); añadir `ref.invalidate(presupuestosProvider)` a `_refrescarDatos`.
- [ ] **Step 4: Test** — render de la pantalla con provider override (`mocktail`), `pump(Duration)`. Verifica que pinta una barra por categoría.
- [ ] **Step 5: analyze + test. Step 6: Commit** — `git commit -m "feat(front): pantalla presupuestos + card"`

---

### Task A8: Frontend — pantalla `/metas` + card en dashboard

**Files:**
- Create: `frontend/lib/screens/metas_screen.dart`
- Create: `frontend/lib/widgets/meta_card.dart`
- Modify: `frontend/lib/router.dart` (`/metas`)
- Modify: `frontend/lib/screens/dashboard_screen.dart` (card + `metasProvider` en `_refrescarDatos`)
- Test: `frontend/test/screens/metas_screen_test.dart`

- [ ] **Step 1: Pantalla** — lista de metas con barra de progreso + "necesitas $X/mes" (si hay aporte) + monto actual/objetivo. "+ meta" → sheet (nombre, objetivo, fecha opcional). Editar meta → sheet (incluye actualizar `monto_actual` "ya llevo $…"). Borrar.
- [ ] **Step 2: Card dashboard** — `MetaCard`: muestra la meta más cercana a cumplirse o un resumen ("2 metas activas, vas en 40%"); `onTap` → `/metas`. Sin metas → CTA.
- [ ] **Step 3: Router + dashboard wire + `metasProvider` en `_refrescarDatos`.**
- [ ] **Step 4: Test render. Step 5: analyze+test. Step 6: Commit** — `git commit -m "feat(front): pantalla metas + card"`

---

# GRUPO B — Alertas

### Task B1: `alertas_service` + endpoint `GET /alertas`

**Files:**
- Create: `backend/app/services/alertas_service.py`
- Modify: `backend/app/api/routes/insights.py` (añadir `GET /insights/alertas`)
- Modify: `backend/app/models/schemas.py` (`AlertaOut`, `AlertasResponse`)
- Test: `backend/tests/services/test_alertas_service.py`, `backend/tests/api/test_alertas_endpoint.py`

**Interfaces:**
- Produces: `evaluar_alertas(session, user_id) -> list[dict]`. Cada alerta: `{key, tipo, severidad, titulo, detalle, fecha}`. Reglas:
  - `tarjeta_vence` (urgent): `get_estado` con `tiene_datos` y `fecha_vencimiento` ≤ 5 días desde hoy.
  - `presupuesto` (warning): por cada `estado_presupuestos` en `cerca`/`excedido`.
  - `cuotas_proximo_mes` (warning): `comprometido_proximo_mes` > 0.
  - `gasto_inusual` (info): gasto últimos 7 días con |monto| > 3× mediana de |gastos| de 90 días **y** > 50000.
  - `key` determinístico (`f"tarjeta_vence:{fecha}"`, `f"presupuesto:{categoria}"`, `"cuotas_proximo_mes"`, `f"gasto:{txn_id}"`).
- `GET /insights/alertas` → `AlertasResponse {items: [AlertaOut]}`.

- [ ] **Step 1: Tests que fallan**

```python
# test_alertas_service.py (sqlite fixture como los demás)
def test_alerta_tarjeta_vence(session):
    # guardar_estado con fecha_vencimiento dentro de 3 días
    from app.services.tarjeta_service import guardar_estado
    from datetime import date, timedelta
    venc = (date.today() + timedelta(days=3)).isoformat()
    guardar_estado(session, "u1", {"total_a_pagar": 200000, "fecha_vencimiento": venc, "cuotas_pendientes": []})
    alertas = evaluar_alertas(session, "u1")
    assert any(a["tipo"] == "tarjeta_vence" and a["severidad"] == "urgent" for a in alertas)

def test_alerta_presupuesto_excedido(session):
    from app.services.presupuesto_service import set_tope
    set_tope(session, "u1", "Compras", 10000)
    _mk_gasto(session, "u1", "Compras", -15000)   # hoy
    alertas = evaluar_alertas(session, "u1")
    assert any(a["tipo"] == "presupuesto" for a in alertas)

def test_sin_datos_sin_alertas(session):
    assert evaluar_alertas(session, "u1") == []

def test_gasto_inusual(session):
    # varios gastos chicos + uno enorme reciente
    for _ in range(6): _mk_gasto(session, "u1", "almuerzo", -5000, dias_atras=30)
    _mk_gasto(session, "u1", "notebook", -800000, dias_atras=1)
    alertas = evaluar_alertas(session, "u1")
    assert any(a["tipo"] == "gasto_inusual" for a in alertas)
```

```python
# test_alertas_endpoint.py
def test_alertas_200_y_shape(client):   # fixture igual a test_insights.py
    r = client.get("/api/v1/insights/alertas")
    assert r.status_code == 200
    assert "items" in r.json()

def test_alertas_requires_auth():
    app.dependency_overrides.clear()
    c = TestClient(app)
    assert c.get("/api/v1/insights/alertas").status_code in (401, 403)
```

- [ ] **Step 2: Ver fallar.**
- [ ] **Step 3: Implementar service** (mediana con `statistics.median`; reusar `get_estado`, `estado_presupuestos`).
- [ ] **Step 4: Schemas + endpoint** en `insights.py`.
- [ ] **Step 5: Ver pasar** — ambos archivos + suite completa.
- [ ] **Step 6: Commit** — `git commit -m "feat(alertas): alertas_service + GET /insights/alertas"`

---

### Task B2: Frontend — campana + badge + pantalla `/alertas`

**Files:**
- Modify: `frontend/pubspec.yaml` (`shared_preferences: ^2.3.2`)
- Create: `frontend/lib/models/alerta.dart`
- Create: `frontend/lib/screens/alertas_screen.dart`
- Create: `frontend/lib/services/alertas_seen.dart` (set de keys vistas en `shared_preferences`)
- Modify: `frontend/lib/services/api_service.dart` (`getAlertas`)
- Modify: `frontend/lib/providers/data_providers.dart` (`alertasProvider`)
- Modify: `frontend/lib/router.dart` (`/alertas`)
- Modify: `frontend/lib/screens/dashboard_screen.dart` (campana en app bar con badge = nº keys no vistas; tap → `/alertas` y marcar vistas; `alertasProvider` en `_refrescarDatos`)
- Test: `frontend/test/models/alerta_test.dart`, `frontend/test/screens/alertas_screen_test.dart`

**Interfaces:**
- `Alerta.fromJson` ({key, tipo, severidad, titulo, detalle, fecha}).
- `ApiService.getAlertas() -> Future<List<Alerta>>`.
- `AlertasSeen`: `Future<Set<String>> seenKeys()`, `Future<void> markSeen(Iterable<String>)`.

- [ ] **Step 1: dep + modelo + test fromJson.**
- [ ] **Step 2: api + provider.**
- [ ] **Step 3: pantalla `/alertas`** — lista de tarjetas, color por severidad (urgent=salmón, warning=ámbar, info=índigo/salvia), icono por tipo. Vacío → "todo en orden" con Orb suave.
- [ ] **Step 4: campana en dashboard** — `IconButton` con `Badge` (count = alertas cuya `key` ∉ `seenKeys`). `onTap`: `await context.push('/alertas')`, luego `markSeen(keys)` + `ref.invalidate(alertasProvider)`. Añadir `alertasProvider` a `_refrescarDatos`.
- [ ] **Step 5: tests** — fromJson; render pantalla con override (lista pinta N tarjetas). `pump(Duration)`.
- [ ] **Step 6: analyze + test. Commit** — `git commit -m "feat(front): campana de alertas + pantalla"`

---

### Task B3: Frontend — notificación local de vencimiento de tarjeta (solo móvil)

**Files:**
- Modify: `frontend/pubspec.yaml` (`flutter_local_notifications: ^17.2.3`)
- Create: `frontend/lib/services/notif_service.dart`
- Modify: `frontend/lib/main.dart` (init notif en arranque, `!kIsWeb`)
- Modify: `frontend/lib/screens/dashboard_screen.dart` (al cargar `tarjetaProvider` con datos, agendar la notif)
- Modify: `android/app/src/main/AndroidManifest.xml` (permiso `POST_NOTIFICATIONS`) — si el implementer no puede tocar Android nativo, dejar la llamada cableada y documentarlo.
- Test: `frontend/test/services/notif_service_test.dart` (en web/CI el service es no-op; el test verifica que `agendarVencimiento` no lanza cuando `kIsWeb`)

**Interfaces:**
- `NotifService.init()`, `NotifService.agendarVencimiento(DateTime fecha, double monto)` — agenda para `fecha - 3 días`; cancela la previa; **no-op si `kIsWeb`**.

> ⚠️ Mobile-only: no se puede verificar disparo en web. `flutter analyze` y el test no-op deben pasar. La notif real se valida al compilar el APK (post Play Store setup). Si esta task agrega fricción al build web, está OK entregarla al final y por separado.

- [ ] **Step 1: dep + service** (guard `kIsWeb` en todos los métodos).
- [ ] **Step 2: init en main + agendar desde dashboard** cuando `tarjeta.tieneDatos && tarjeta.fechaVencimiento != null`.
- [ ] **Step 3: test no-op + analyze.**
- [ ] **Step 4: Commit** — `git commit -m "feat(front): notificación local de vencimiento (móvil)"`

---

## Post-implementación (tras todas las tasks)
1. Aplicar migraciones 006 y 007 a Supabase con el script psycopg2 (`POSTGRES_URL` del `.env`).
2. Backend: `cd backend && pytest && ruff check . && mypy app` — todo verde.
3. Front: `cd frontend && flutter analyze && flutter test` — todo verde.
4. Deploy: subir backend a HF Space (upload_folder) + push para Pages. Verificar HF `RUNNING`, Pages `success`, `GET /api/v1/insights/alertas` y `/api/v1/presupuestos` responden 401/403 (auth-gated, existen).
5. Validación real (usuario): fija un tope y excédelo → revisa la campana; corrige una categoría en Movimientos → verifica que la dona se actualiza y que el mismo comercio queda recategorizado; crea una meta.

## Self-review (cobertura del spec)
- A) Presupuestos topes ✓ (A1–A4,A7), Metas ✓ (A1,A3,A4,A8), chat ✓ (A5). 
- B) Alertas in-app ✓ (B1,B2), notif local móvil ✓ (B3).
- C) Override + recategorizar pasadas sin pisar manual ✓ (C2,C3), comercio_key ✓ (C1), UI editar ✓ (C4).
- Migraciones 006/007 ✓. RLS ✓. Tests por task ✓.
