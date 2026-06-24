# Plan 1 — Backend: Auth + Capa de datos multi-usuario

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convertir el backend actual (single-user, solo pgvector) en un backend multi-usuario con auth JWT de Supabase y una tabla `transactions` como fuente de verdad, manteniendo el RAG existente pero filtrado por usuario.

**Architecture:** FastAPI valida el JWT de Supabase en cada request y extrae el `user_id`. Las transacciones se guardan en una tabla Postgres (`transactions`) vía SQLAlchemy con deduplicación; los embeddings siguen en pgvector pero con `user_id` en la metadata. Totales y resúmenes salen de SQL agregado, no del LLM.

**Tech Stack:** Python 3.11, FastAPI, SQLAlchemy 2.0, PyJWT, pgvector/LangChain, DeepSeek (chat), sentence-transformers (embeddings), Supabase (Postgres + Auth).

## Global Constraints

- Python 3.11+; ruff line-length 100; mypy limpio.
- `.env` **nunca** se commitea (ya en `.gitignore`).
- Todos los endpoints menos `/health` exigen JWT válido de Supabase.
- **Toda** query (SQL y vectorial) filtra por `user_id`.
- Clave de deduplicación: `user_id + fecha + monto + descripcion(normalizada) + tarjeta`.
- Totales agrupados por `moneda` (nunca mezclar CLP con USD).
- Chat con DeepSeek (`deepseek-chat`); embeddings con sentence-transformers local.
- pgvector: cada documento lleva `user_id` en su metadata.

---

### Task 1: Auth — validación del JWT de Supabase

**Files:**
- Create: `backend/app/auth/__init__.py`
- Create: `backend/app/auth/jwt.py`
- Modify: `backend/app/config.py` (agregar `supabase_jwt_secret`)
- Modify: `backend/requirements.txt` (agregar `pyjwt`)
- Modify: `backend/.env` y `backend/.env.example` (agregar `SUPABASE_JWT_SECRET`)
- Test: `backend/tests/auth/test_jwt.py`

**Interfaces:**
- Consumes: `settings.supabase_jwt_secret` (str).
- Produces:
  - `decode_user_id(token: str, secret: str) -> str` — devuelve el `sub` (user_id) o lanza excepción.
  - `get_current_user(creds=Depends(HTTPBearer())) -> str` — dependency FastAPI; 401 si el token es inválido.

- [ ] **Step 1: Agregar dependencia PyJWT**

En `backend/requirements.txt`, bajo la sección de validación, agregar:

```
pyjwt==2.10.1
```

Instalar:

Run: `cd backend && .\.venv\Scripts\pip install pyjwt==2.10.1`
Expected: `Successfully installed pyjwt-2.10.1`

- [ ] **Step 2: Agregar el secret a config y .env**

En `backend/app/config.py`, agregar el campo dentro de `Settings`:

```python
    supabase_jwt_secret: str
```

(Va junto a `deepseek_api_key` y `postgres_url`.)

En `backend/.env` agregar la línea (el valor real está en Supabase → Project Settings → API → JWT Secret):

```
SUPABASE_JWT_SECRET=tu-jwt-secret-de-supabase
```

En `backend/.env.example` agregar:

```
SUPABASE_JWT_SECRET=...
```

- [ ] **Step 3: Escribir el test que falla**

Crear `backend/tests/auth/test_jwt.py`:

```python
import jwt
import pytest
from app.auth.jwt import decode_user_id

SECRET = "test-secret-123"


def test_decode_valid_token_returns_user_id():
    token = jwt.encode(
        {"sub": "user-abc", "aud": "authenticated"}, SECRET, algorithm="HS256"
    )
    assert decode_user_id(token, SECRET) == "user-abc"


def test_decode_token_without_sub_raises():
    token = jwt.encode({"aud": "authenticated"}, SECRET, algorithm="HS256")
    with pytest.raises(ValueError):
        decode_user_id(token, SECRET)


def test_decode_token_with_wrong_secret_raises():
    token = jwt.encode(
        {"sub": "user-abc", "aud": "authenticated"}, "otro-secret", algorithm="HS256"
    )
    with pytest.raises(jwt.InvalidTokenError):
        decode_user_id(token, SECRET)
```

Crear archivo vacío `backend/tests/__init__.py` y `backend/tests/auth/__init__.py`.

- [ ] **Step 4: Correr el test y verificar que falla**

Run: `cd backend && .\.venv\Scripts\python -m pytest tests/auth/test_jwt.py -v`
Expected: FAIL con `ModuleNotFoundError: No module named 'app.auth'`

- [ ] **Step 5: Implementar el módulo de auth**

Crear `backend/app/auth/__init__.py` (vacío).

Crear `backend/app/auth/jwt.py`:

```python
import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.config import settings


def decode_user_id(token: str, secret: str) -> str:
    """Valida un JWT de Supabase (HS256) y devuelve el user_id (claim 'sub')."""
    payload = jwt.decode(
        token,
        secret,
        algorithms=["HS256"],
        audience="authenticated",
    )
    user_id = payload.get("sub")
    if not user_id:
        raise ValueError("Token sin claim 'sub'")
    return user_id


_bearer = HTTPBearer()


def get_current_user(
    creds: HTTPAuthorizationCredentials = Depends(_bearer),
) -> str:
    try:
        return decode_user_id(creds.credentials, settings.supabase_jwt_secret)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido o expirado",
        )
```

- [ ] **Step 6: Correr el test y verificar que pasa**

Run: `cd backend && .\.venv\Scripts\python -m pytest tests/auth/test_jwt.py -v`
Expected: PASS (3 passed)

- [ ] **Step 7: Commit**

```bash
git add backend/app/auth backend/app/config.py backend/requirements.txt backend/.env.example backend/tests
git commit -m "feat(auth): validación de JWT de Supabase con get_current_user"
```

(No incluir `backend/.env` — está ignorado.)

---

### Task 2: Modelo `Transaction` + sesión DB + migración SQL

**Files:**
- Create: `backend/app/db/__init__.py`
- Create: `backend/app/db/base.py` (engine, SessionLocal, Base, get_session)
- Create: `backend/app/db/models.py` (modelo `Transaction`)
- Create: `backend/migrations/001_transactions.sql` (migración para Supabase)
- Test: `backend/tests/db/test_models.py`

**Interfaces:**
- Consumes: `settings.postgres_url`.
- Produces:
  - `Base` (declarative base de SQLAlchemy).
  - `Transaction` (modelo ORM con columnas: id, user_id, fecha, descripcion, monto, moneda, tarjeta, tipo, categoria, banco, fuente, created_at).
  - `SessionLocal` (sessionmaker) y `get_session()` (generator dependency).

- [ ] **Step 1: Escribir el test que falla**

Crear `backend/tests/db/__init__.py` (vacío) y `backend/tests/db/test_models.py`:

```python
from datetime import date
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.db.base import Base
from app.db.models import Transaction


def _memory_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    return sessionmaker(bind=engine)()


def test_insert_and_query_transaction():
    s = _memory_session()
    t = Transaction(
        user_id="u1",
        fecha=date(2025, 6, 1),
        descripcion="SUPERMERCADO LIDER",
        monto=-45000,
        tipo="cargo",
        banco="bci",
        fuente="cartola",
    )
    s.add(t)
    s.commit()

    rows = s.query(Transaction).filter_by(user_id="u1").all()
    assert len(rows) == 1
    assert rows[0].id is not None
    assert rows[0].moneda == "CLP"      # default aplicado
    assert rows[0].tarjeta is None
```

- [ ] **Step 2: Correr el test y verificar que falla**

Run: `cd backend && .\.venv\Scripts\python -m pytest tests/db/test_models.py -v`
Expected: FAIL con `ModuleNotFoundError: No module named 'app.db'`

- [ ] **Step 3: Implementar base.py y models.py**

Crear `backend/app/db/__init__.py` (vacío).

Crear `backend/app/db/base.py`:

```python
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker
from app.config import settings

engine = create_engine(settings.postgres_url, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)
Base = declarative_base()


def get_session():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

Crear `backend/app/db/models.py`:

```python
import uuid
from datetime import datetime
from sqlalchemy import Column, String, Text, Numeric, Date, DateTime
from app.db.base import Base


class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), nullable=False, index=True)
    fecha = Column(Date, nullable=False)
    descripcion = Column(Text, nullable=False)
    monto = Column(Numeric, nullable=False)
    moneda = Column(String, nullable=False, default="CLP")
    tarjeta = Column(String, nullable=True)
    tipo = Column(String, nullable=False)
    categoria = Column(String, nullable=True)
    banco = Column(String, nullable=False)
    fuente = Column(String, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
```

- [ ] **Step 4: Correr el test y verificar que pasa**

Run: `cd backend && .\.venv\Scripts\python -m pytest tests/db/test_models.py -v`
Expected: PASS (1 passed)

- [ ] **Step 5: Crear el SQL de migración para Supabase**

Crear `backend/migrations/001_transactions.sql`:

```sql
-- Aplicar en Supabase: SQL Editor → pegar y ejecutar.
create table if not exists transactions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  fecha       date not null,
  descripcion text not null,
  monto       numeric not null,
  moneda      text not null default 'CLP',
  tarjeta     text,
  tipo        text not null,
  categoria   text,
  banco       text not null,
  fuente      text not null,
  created_at  timestamptz default now()
);

create index if not exists idx_transactions_user_fecha
  on transactions (user_id, fecha);

-- RLS: protege el acceso directo de clientes Supabase.
-- (El backend FastAPI se conecta con el rol postgres y filtra por user_id él mismo.)
alter table transactions enable row level security;

create policy "ver_propias" on transactions
  for select using (auth.uid() = user_id);

create policy "insertar_propias" on transactions
  for insert with check (auth.uid() = user_id);
```

> **Nota manual:** este SQL se ejecuta una vez en el SQL Editor de Supabase. No es un test automatizado; se valida que la tabla existe corriendo el backend contra Supabase en la Task 5.

- [ ] **Step 6: Commit**

```bash
git add backend/app/db backend/migrations backend/tests/db
git commit -m "feat(db): modelo Transaction, sesión SQLAlchemy y migración SQL"
```

---

### Task 3: Schema con moneda/tarjeta + servicio de inserción con dedup

**Files:**
- Modify: `backend/app/models/schemas.py` (agregar `moneda`, `tarjeta` a `Transaccion`)
- Create: `backend/app/services/__init__.py`
- Create: `backend/app/services/transaction_service.py`
- Create: `backend/tests/conftest.py` (fixture de sesión sqlite)
- Test: `backend/tests/services/test_transaction_service.py`

**Interfaces:**
- Consumes: `Transaction` (Task 2), `Transaccion` (schema).
- Produces:
  - `_dedup_key(user_id, fecha, monto, descripcion, tarjeta) -> tuple`
  - `insert_transactions(session, user_id: str, transacciones: list[Transaccion], fuente: str = "cartola") -> int` — inserta solo las nuevas (dedup), devuelve cuántas insertó.

- [ ] **Step 1: Agregar moneda y tarjeta al schema Transaccion**

En `backend/app/models/schemas.py`, modificar la clase `Transaccion`:

```python
class Transaccion(BaseModel):
    fecha: date
    descripcion: str
    monto: float          # negativo = gasto, positivo = ingreso
    tipo: str             # "cargo" | "abono"
    categoria: Optional[str] = None
    banco: str
    moneda: str = "CLP"
    tarjeta: Optional[str] = None
```

- [ ] **Step 2: Crear el fixture de sesión y escribir el test que falla**

Crear `backend/tests/conftest.py`:

```python
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.db.base import Base
import app.db.models  # noqa: F401  (registra el modelo en Base.metadata)


@pytest.fixture
def session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    s = sessionmaker(bind=engine)()
    yield s
    s.close()
```

Crear `backend/tests/services/__init__.py` (vacío) y `backend/tests/services/test_transaction_service.py`:

```python
from datetime import date
from app.models.schemas import Transaccion
from app.services.transaction_service import insert_transactions
from app.db.models import Transaction


def _txn(desc="LIDER", monto=-45000.0, tarjeta=None):
    return Transaccion(
        fecha=date(2025, 6, 1),
        descripcion=desc,
        monto=monto,
        tipo="cargo",
        banco="bci",
        tarjeta=tarjeta,
    )


def test_insert_returns_count(session):
    n = insert_transactions(session, "u1", [_txn(), _txn("UBER", -12500)])
    assert n == 2
    assert session.query(Transaction).filter_by(user_id="u1").count() == 2


def test_insert_dedups_repeated(session):
    txns = [_txn()]
    assert insert_transactions(session, "u1", txns) == 1
    assert insert_transactions(session, "u1", txns) == 0  # duplicado, no inserta
    assert session.query(Transaction).filter_by(user_id="u1").count() == 1


def test_same_desc_distinct_card_not_dedup(session):
    assert insert_transactions(session, "u1", [_txn(tarjeta="4521")]) == 1
    assert insert_transactions(session, "u1", [_txn(tarjeta="9988")]) == 1
    assert session.query(Transaction).filter_by(user_id="u1").count() == 2


def test_isolation_between_users(session):
    insert_transactions(session, "u1", [_txn()])
    insert_transactions(session, "u2", [_txn()])
    assert session.query(Transaction).filter_by(user_id="u1").count() == 1
    assert session.query(Transaction).filter_by(user_id="u2").count() == 1
```

- [ ] **Step 3: Correr el test y verificar que falla**

Run: `cd backend && .\.venv\Scripts\python -m pytest tests/services/test_transaction_service.py -v`
Expected: FAIL con `ModuleNotFoundError: No module named 'app.services.transaction_service'`

- [ ] **Step 4: Implementar el servicio**

Crear `backend/app/services/__init__.py` (vacío).

Crear `backend/app/services/transaction_service.py`:

```python
from sqlalchemy.orm import Session
from app.db.models import Transaction
from app.models.schemas import Transaccion


def _dedup_key(user_id, fecha, monto, descripcion, tarjeta):
    return (
        user_id,
        str(fecha),
        float(monto),
        descripcion.strip().lower(),
        tarjeta or "",
    )


def insert_transactions(
    session: Session,
    user_id: str,
    transacciones: list[Transaccion],
    fuente: str = "cartola",
) -> int:
    existing = session.query(Transaction).filter_by(user_id=user_id).all()
    seen = {
        _dedup_key(user_id, t.fecha, t.monto, t.descripcion, t.tarjeta)
        for t in existing
    }

    inserted = 0
    for t in transacciones:
        key = _dedup_key(user_id, t.fecha, t.monto, t.descripcion, t.tarjeta)
        if key in seen:
            continue
        seen.add(key)
        session.add(
            Transaction(
                user_id=user_id,
                fecha=t.fecha,
                descripcion=t.descripcion,
                monto=t.monto,
                moneda=t.moneda or "CLP",
                tarjeta=t.tarjeta,
                tipo=t.tipo,
                categoria=t.categoria,
                banco=t.banco,
                fuente=fuente,
            )
        )
        inserted += 1

    session.commit()
    return inserted
```

- [ ] **Step 5: Correr los tests y verificar que pasan**

Run: `cd backend && .\.venv\Scripts\python -m pytest tests/services/test_transaction_service.py -v`
Expected: PASS (4 passed)

- [ ] **Step 6: Commit**

```bash
git add backend/app/models/schemas.py backend/app/services backend/tests/conftest.py backend/tests/services
git commit -m "feat(services): insert_transactions con deduplicación por usuario"
```

---

### Task 4: Resumen agregado (summary) por SQL

**Files:**
- Modify: `backend/app/services/transaction_service.py` (agregar `get_summary`)
- Modify: `backend/app/models/schemas.py` (agregar schemas de respuesta)
- Test: `backend/tests/services/test_summary.py`

**Interfaces:**
- Consumes: `Transaction`, sesión SQLAlchemy.
- Produces:
  - `get_summary(session, user_id: str) -> dict` con forma:
    ```python
    {
      "por_moneda": {"CLP": {"ingresos": 2500000.0, "gastos": -89890.0}},
      "gastos_por_categoria": [{"categoria": "supermercado", "total": -45000.0}],
      "gastos_por_banco": [{"banco": "bci", "total": -89890.0}],
    }
    ```

- [ ] **Step 1: Escribir el test que falla**

Crear `backend/tests/services/test_summary.py`:

```python
from datetime import date
from app.models.schemas import Transaccion
from app.services.transaction_service import insert_transactions, get_summary


def _seed(session):
    txns = [
        Transaccion(fecha=date(2025, 6, 1), descripcion="LIDER", monto=-45000,
                    tipo="cargo", banco="bci", categoria="supermercado"),
        Transaccion(fecha=date(2025, 6, 5), descripcion="UBER", monto=-12500,
                    tipo="cargo", banco="bci", categoria="transporte"),
        Transaccion(fecha=date(2025, 6, 10), descripcion="SUELDO", monto=2500000,
                    tipo="abono", banco="bci", categoria=None),
    ]
    insert_transactions(session, "u1", txns)


def test_summary_groups_by_moneda(session):
    _seed(session)
    s = get_summary(session, "u1")
    assert s["por_moneda"]["CLP"]["ingresos"] == 2500000.0
    assert s["por_moneda"]["CLP"]["gastos"] == -57500.0


def test_summary_gastos_por_categoria(session):
    _seed(session)
    s = get_summary(session, "u1")
    cats = {c["categoria"]: c["total"] for c in s["gastos_por_categoria"]}
    assert cats["supermercado"] == -45000.0
    assert cats["transporte"] == -12500.0


def test_summary_isolated_per_user(session):
    _seed(session)
    s = get_summary(session, "u2")
    assert s["por_moneda"] == {}
    assert s["gastos_por_categoria"] == []
```

- [ ] **Step 2: Correr el test y verificar que falla**

Run: `cd backend && .\.venv\Scripts\python -m pytest tests/services/test_summary.py -v`
Expected: FAIL con `ImportError: cannot import name 'get_summary'`

- [ ] **Step 3: Implementar get_summary**

Agregar al final de `backend/app/services/transaction_service.py`:

```python
from sqlalchemy import func


def get_summary(session: Session, user_id: str) -> dict:
    rows = (
        session.query(
            Transaction.moneda,
            func.sum(Transaction.monto),
        )
        .filter(Transaction.user_id == user_id)
        .filter(Transaction.monto < 0)
        .group_by(Transaction.moneda)
        .all()
    )
    ingresos_rows = (
        session.query(Transaction.moneda, func.sum(Transaction.monto))
        .filter(Transaction.user_id == user_id)
        .filter(Transaction.monto >= 0)
        .group_by(Transaction.moneda)
        .all()
    )

    por_moneda: dict = {}
    for moneda, total in rows:
        por_moneda.setdefault(moneda, {"ingresos": 0.0, "gastos": 0.0})
        por_moneda[moneda]["gastos"] = float(total)
    for moneda, total in ingresos_rows:
        por_moneda.setdefault(moneda, {"ingresos": 0.0, "gastos": 0.0})
        por_moneda[moneda]["ingresos"] = float(total)

    cat_rows = (
        session.query(Transaction.categoria, func.sum(Transaction.monto))
        .filter(Transaction.user_id == user_id)
        .filter(Transaction.monto < 0)
        .filter(Transaction.categoria.isnot(None))
        .group_by(Transaction.categoria)
        .all()
    )
    gastos_por_categoria = [
        {"categoria": c, "total": float(t)} for c, t in cat_rows
    ]

    banco_rows = (
        session.query(Transaction.banco, func.sum(Transaction.monto))
        .filter(Transaction.user_id == user_id)
        .filter(Transaction.monto < 0)
        .group_by(Transaction.banco)
        .all()
    )
    gastos_por_banco = [{"banco": b, "total": float(t)} for b, t in banco_rows]

    return {
        "por_moneda": por_moneda,
        "gastos_por_categoria": gastos_por_categoria,
        "gastos_por_banco": gastos_por_banco,
    }
```

- [ ] **Step 4: Correr el test y verificar que pasa**

Run: `cd backend && .\.venv\Scripts\python -m pytest tests/services/test_summary.py -v`
Expected: PASS (3 passed)

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/transaction_service.py backend/tests/services/test_summary.py
git commit -m "feat(services): get_summary agregado por moneda, categoria y banco"
```

---

### Task 5: Endpoint upload-csv multi-usuario + indexado con user_id

**Files:**
- Modify: `backend/app/rag/rag_service.py` (`indexar_transacciones` recibe `user_id`)
- Modify: `backend/app/api/routes/upload.py` (auth + DB + dedup)
- Test: `backend/tests/api/test_upload.py`

**Interfaces:**
- Consumes: `get_current_user` (Task 1), `get_session` (Task 2), `insert_transactions` (Task 3).
- Produces:
  - `indexar_transacciones(transacciones: list[Transaccion], user_id: str) -> int` (metadata con `user_id`).
  - `POST /api/v1/transactions/upload-csv?banco=` autenticado.

- [ ] **Step 1: Modificar indexar_transacciones para llevar user_id**

En `backend/app/rag/rag_service.py`, reemplazar `_transaccion_to_document` e `indexar_transacciones`:

```python
def _transaccion_to_document(t: Transaccion, user_id: str) -> Document:
    tipo_str = "gasto" if t.monto < 0 else "ingreso"
    monto_abs = abs(t.monto)
    categoria = f" Categoría: {t.categoria}." if t.categoria else ""
    content = (
        f"El {t.fecha.strftime('%d/%m/%Y')}, {tipo_str} de "
        f"${monto_abs:,.0f} CLP por '{t.descripcion}'.{categoria} Banco: {t.banco}."
    )
    return Document(
        page_content=content,
        metadata={
            "user_id": user_id,
            "fecha": str(t.fecha),
            "monto": t.monto,
            "descripcion": t.descripcion,
            "banco": t.banco,
        },
    )


def indexar_transacciones(transacciones: list[Transaccion], user_id: str) -> int:
    docs = [_transaccion_to_document(t, user_id) for t in transacciones]
    vs = get_vector_store()
    vs.add_documents(docs)
    return len(docs)
```

- [ ] **Step 2: Reescribir el endpoint upload**

Reemplazar el contenido de `backend/app/api/routes/upload.py`:

```python
from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from sqlalchemy.orm import Session
from app.parsers.bci_parser import BciParser
from app.parsers.santander_parser import SantanderParser
from app.parsers.banco_estado_parser import BancoEstadoParser
from app.services.transaction_service import insert_transactions
from app.rag.rag_service import indexar_transacciones
from app.models.schemas import UploadResponse
from app.auth.jwt import get_current_user
from app.db.base import get_session

router = APIRouter()

PARSERS = {
    "bci": BciParser(),
    "santander": SantanderParser(),
    "bancoestado": BancoEstadoParser(),
}


@router.post("/transactions/upload-csv", response_model=UploadResponse, status_code=201)
async def upload_csv(
    file: UploadFile = File(...),
    banco: str = "bci",
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    banco = banco.lower().replace(" ", "")
    if banco not in PARSERS:
        raise HTTPException(
            status_code=400,
            detail=f"Banco '{banco}' no soportado. Opciones: {list(PARSERS.keys())}",
        )
    if not file.filename.endswith(".csv"):
        raise HTTPException(status_code=400, detail="Solo se aceptan archivos CSV.")

    content = await file.read()
    transacciones = PARSERS[banco].parse(content)
    if not transacciones:
        raise HTTPException(
            status_code=422, detail="No se pudieron parsear transacciones del archivo."
        )

    nuevas = insert_transactions(session, user_id, transacciones, fuente="cartola")
    if nuevas:
        indexar_transacciones(transacciones, user_id)

    return UploadResponse(
        banco=banco,
        transacciones_procesadas=nuevas,
        message=f"{nuevas} transacciones nuevas indexadas ({len(transacciones) - nuevas} duplicadas omitidas).",
    )
```

- [ ] **Step 3: Escribir el test que falla**

Crear `backend/tests/api/__init__.py` (vacío) y `backend/tests/api/test_upload.py`:

```python
import io
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.main import app
from app.db.base import Base, get_session
from app.auth.jwt import get_current_user
import app.db.models  # noqa: F401


@pytest.fixture
def client(monkeypatch):
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    TestSession = sessionmaker(bind=engine)

    def _override_session():
        s = TestSession()
        try:
            yield s
        finally:
            s.close()

    # Evita llamar a pgvector/red en el test.
    monkeypatch.setattr(
        "app.api.routes.upload.indexar_transacciones", lambda txns, user_id: len(txns)
    )

    app.dependency_overrides[get_session] = _override_session
    app.dependency_overrides[get_current_user] = lambda: "u1"
    yield TestClient(app)
    app.dependency_overrides.clear()


CSV = (
    "fecha;descripción;cargo;abono;saldo\n"
    "01/06/2025;SUPERMERCADO LIDER;45000;;1500000\n"
    "05/06/2025;UBER EATS;12500;;1487500\n"
).encode("latin-1")


def test_upload_requires_auth():
    # Sin override de auth → 403 (sin credenciales bearer).
    c = TestClient(app)
    r = c.post("/api/v1/transactions/upload-csv?banco=bci",
               files={"file": ("c.csv", io.BytesIO(CSV), "text/csv")})
    assert r.status_code in (401, 403)


def test_upload_inserts_and_dedups(client):
    files = {"file": ("c.csv", io.BytesIO(CSV), "text/csv")}
    r = client.post("/api/v1/transactions/upload-csv?banco=bci", files=files)
    assert r.status_code == 201
    assert r.json()["transacciones_procesadas"] == 2

    # Re-subir el mismo CSV → 0 nuevas (dedup).
    r2 = client.post("/api/v1/transactions/upload-csv?banco=bci",
                     files={"file": ("c.csv", io.BytesIO(CSV), "text/csv")})
    assert r2.json()["transacciones_procesadas"] == 0
```

- [ ] **Step 4: Correr el test y verificar que falla**

Run: `cd backend && .\.venv\Scripts\python -m pytest tests/api/test_upload.py -v`
Expected: FAIL (el endpoint viejo estaba en `/upload`, no `/transactions/upload-csv`) → 404 o error de ruta.

- [ ] **Step 5: Verificar el prefijo del router en main.py**

Confirmar que `backend/app/main.py` incluye el router así (la ruta queda `/api/v1/transactions/upload-csv`):

```python
app.include_router(upload.router, prefix="/api/v1", tags=["transactions"])
```

Si decía `tags=["upload"]`, cambiarlo a `tags=["transactions"]` (cosmético, no afecta la ruta).

- [ ] **Step 6: Correr los tests y verificar que pasan**

Run: `cd backend && .\.venv\Scripts\python -m pytest tests/api/test_upload.py -v`
Expected: PASS (2 passed)

- [ ] **Step 7: Commit**

```bash
git add backend/app/rag/rag_service.py backend/app/api/routes/upload.py backend/app/main.py backend/tests/api
git commit -m "feat(api): upload-csv autenticado, persiste en DB con dedup e indexa por user_id"
```

---

### Task 6: RAG filtrado por user_id + endpoint chat autenticado

**Files:**
- Modify: `backend/app/rag/rag_service.py` (`ask` recibe `user_id` y filtra)
- Modify: `backend/app/api/routes/ask.py` (auth + ruta `/chat/ask`)
- Test: `backend/tests/api/test_ask.py`

**Interfaces:**
- Consumes: `get_current_user` (Task 1), `get_vector_store`.
- Produces:
  - `ask(question: str, user_id: str) -> AskResponse` (similarity_search con `filter={"user_id": user_id}`).
  - `POST /api/v1/chat/ask` autenticado.

- [ ] **Step 1: Modificar ask() para filtrar por user_id**

En `backend/app/rag/rag_service.py`, reemplazar la función `ask`:

```python
def ask(question: str, user_id: str) -> AskResponse:
    vs = get_vector_store()
    docs = vs.similarity_search(
        question, k=settings.rag_top_k, filter={"user_id": user_id}
    )

    context = "\n".join(f"- {d.page_content}" for d in docs)
    chain = PROMPT | _llm()
    answer = chain.invoke({"context": context, "question": question})

    citations = [
        TransaccionCitada(
            fecha=d.metadata.get("fecha", ""),
            descripcion=d.metadata.get("descripcion", ""),
            monto=d.metadata.get("monto", 0),
        )
        for d in docs
    ]
    return AskResponse(answer=answer.content, citations=citations)
```

- [ ] **Step 2: Reescribir el endpoint ask**

Reemplazar el contenido de `backend/app/api/routes/ask.py`:

```python
from fastapi import APIRouter, HTTPException, Depends
from app.rag.rag_service import ask
from app.models.schemas import AskRequest, AskResponse
from app.auth.jwt import get_current_user

router = APIRouter()


@router.post("/chat/ask", response_model=AskResponse)
async def preguntar(
    body: AskRequest,
    user_id: str = Depends(get_current_user),
):
    if not body.question.strip():
        raise HTTPException(status_code=400, detail="La pregunta no puede estar vacía.")
    return ask(body.question, user_id)
```

- [ ] **Step 3: Escribir el test que falla**

Crear `backend/tests/api/test_ask.py`:

```python
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.auth.jwt import get_current_user
from app.models.schemas import AskResponse


@pytest.fixture
def client(monkeypatch):
    captured = {}

    def _fake_ask(question, user_id):
        captured["user_id"] = user_id
        captured["question"] = question
        return AskResponse(answer="ok", citations=[])

    monkeypatch.setattr("app.api.routes.ask.ask", _fake_ask)
    app.dependency_overrides[get_current_user] = lambda: "u1"
    yield TestClient(app), captured
    app.dependency_overrides.clear()


def test_ask_passes_user_id(client):
    c, captured = client
    r = c.post("/api/v1/chat/ask", json={"question": "cuanto gaste?"})
    assert r.status_code == 200
    assert captured["user_id"] == "u1"        # el filtro por usuario llega al servicio
    assert captured["question"] == "cuanto gaste?"


def test_ask_requires_auth():
    c = TestClient(app)
    r = c.post("/api/v1/chat/ask", json={"question": "hola"})
    assert r.status_code in (401, 403)
```

- [ ] **Step 4: Correr el test y verificar que falla**

Run: `cd backend && .\.venv\Scripts\python -m pytest tests/api/test_ask.py -v`
Expected: FAIL (ruta vieja `/ask`, nueva `/chat/ask`) → 404.

- [ ] **Step 5: Correr los tests y verificar que pasan**

Run: `cd backend && .\.venv\Scripts\python -m pytest tests/api/test_ask.py -v`
Expected: PASS (2 passed)

- [ ] **Step 6: Correr toda la suite**

Run: `cd backend && .\.venv\Scripts\python -m pytest -v`
Expected: PASS (todos: auth, db, services, api)

- [ ] **Step 7: Commit**

```bash
git add backend/app/rag/rag_service.py backend/app/api/routes/ask.py backend/tests/api/test_ask.py
git commit -m "feat(api): chat/ask autenticado con RAG filtrado por user_id"
```

---

### Task 7: Endpoints GET /transactions y GET /transactions/summary

**Files:**
- Modify: `backend/app/services/transaction_service.py` (agregar `list_transactions`)
- Modify: `backend/app/models/schemas.py` (agregar `TransactionOut`)
- Modify: `backend/app/api/routes/upload.py` (agregar las dos rutas GET)
- Test: `backend/tests/api/test_transactions_read.py`

**Interfaces:**
- Consumes: `get_current_user`, `get_session`, `get_summary` (Task 4), `Transaction`.
- Produces:
  - `list_transactions(session, user_id, banco=None, limit=100, offset=0) -> list[Transaction]`
  - `GET /api/v1/transactions` → `list[TransactionOut]`
  - `GET /api/v1/transactions/summary` → dict del `get_summary`.

- [ ] **Step 1: Agregar list_transactions al servicio**

Agregar al final de `backend/app/services/transaction_service.py`:

```python
def list_transactions(
    session: Session,
    user_id: str,
    banco: str | None = None,
    limit: int = 100,
    offset: int = 0,
) -> list[Transaction]:
    q = session.query(Transaction).filter(Transaction.user_id == user_id)
    if banco:
        q = q.filter(Transaction.banco == banco)
    return q.order_by(Transaction.fecha.desc()).limit(limit).offset(offset).all()
```

- [ ] **Step 2: Agregar el schema de salida**

Agregar a `backend/app/models/schemas.py`:

```python
class TransactionOut(BaseModel):
    id: str
    fecha: date
    descripcion: str
    monto: float
    moneda: str
    tarjeta: Optional[str] = None
    tipo: str
    categoria: Optional[str] = None
    banco: str
    fuente: str

    class Config:
        from_attributes = True
```

- [ ] **Step 3: Escribir el test que falla**

Crear `backend/tests/api/test_transactions_read.py`:

```python
import pytest
from datetime import date
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.main import app
from app.db.base import Base, get_session
from app.auth.jwt import get_current_user
from app.models.schemas import Transaccion
from app.services.transaction_service import insert_transactions
import app.db.models  # noqa: F401


@pytest.fixture
def client():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    TestSession = sessionmaker(bind=engine)
    s = TestSession()
    insert_transactions(s, "u1", [
        Transaccion(fecha=date(2025, 6, 1), descripcion="LIDER", monto=-45000,
                    tipo="cargo", banco="bci", categoria="supermercado"),
        Transaccion(fecha=date(2025, 6, 10), descripcion="SUELDO", monto=2500000,
                    tipo="abono", banco="bci"),
    ])
    s.close()

    def _override_session():
        s2 = TestSession()
        try:
            yield s2
        finally:
            s2.close()

    app.dependency_overrides[get_session] = _override_session
    app.dependency_overrides[get_current_user] = lambda: "u1"
    yield TestClient(app)
    app.dependency_overrides.clear()


def test_list_transactions(client):
    r = client.get("/api/v1/transactions")
    assert r.status_code == 200
    data = r.json()
    assert len(data) == 2
    assert data[0]["fecha"] == "2025-06-10"   # orden desc por fecha


def test_summary_endpoint(client):
    r = client.get("/api/v1/transactions/summary")
    assert r.status_code == 200
    body = r.json()
    assert body["por_moneda"]["CLP"]["ingresos"] == 2500000.0
    assert body["por_moneda"]["CLP"]["gastos"] == -45000.0
```

- [ ] **Step 4: Correr el test y verificar que falla**

Run: `cd backend && .\.venv\Scripts\python -m pytest tests/api/test_transactions_read.py -v`
Expected: FAIL → 404 (rutas aún no existen).

- [ ] **Step 5: Agregar las rutas GET al router**

Agregar al final de `backend/app/api/routes/upload.py` (los imports `Depends`, `Session`, `get_current_user`, `get_session` ya están de la Task 5):

```python
from app.services.transaction_service import list_transactions, get_summary
from app.models.schemas import TransactionOut


@router.get("/transactions", response_model=list[TransactionOut])
async def listar_transacciones(
    banco: str | None = None,
    limit: int = 100,
    offset: int = 0,
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    return list_transactions(session, user_id, banco=banco, limit=limit, offset=offset)


@router.get("/transactions/summary")
async def resumen(
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    return get_summary(session, user_id)
```

> Nota: la línea `from app.services.transaction_service import insert_transactions` de
> la Task 5 puede consolidarse con este import en una sola línea. No es obligatorio.

- [ ] **Step 6: Correr el test y verificar que pasa**

Run: `cd backend && .\.venv\Scripts\python -m pytest tests/api/test_transactions_read.py -v`
Expected: PASS (2 passed)

- [ ] **Step 7: Commit**

```bash
git add backend/app/services/transaction_service.py backend/app/models/schemas.py backend/app/api/routes/upload.py backend/tests/api/test_transactions_read.py
git commit -m "feat(api): GET /transactions y /transactions/summary autenticados"
```

---

## Verificación manual final (contra Supabase real)

Después de la Task 6, con la migración `001_transactions.sql` aplicada en Supabase y un
JWT real de un usuario de prueba:

1. Levantar: `cd backend && .\.venv\Scripts\uvicorn app.main:app --port 8000`
2. Subir CSV con header `Authorization: Bearer <jwt-real>` → 201, transacciones en la tabla.
3. `GET` a Supabase Table Editor → ver las filas con el `user_id` correcto.
4. `POST /api/v1/chat/ask` con el mismo JWT → respuesta basada solo en esas transacciones.

---

## Notas para planes siguientes

- **Plan 2 (Flutter login + dashboard):** consumirá `GET /transactions/summary` y
  `GET /transactions`, ya expuestos en la Task 7 de este plan.
- **Plan 3 (Fotos):** agregará `receipt_service` (Gemini Flash) y los endpoints
  `upload-receipt` / `confirm-receipt`, más `GEMINI_API_KEY` en config.
- **Plan 4 (Categorización):** `categorizer.py` poblará el campo `categoria` que el
  `get_summary` ya usa.
