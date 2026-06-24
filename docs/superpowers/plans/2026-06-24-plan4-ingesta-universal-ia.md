# Plan 4 — Ingesta universal con IA — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reemplazar los parsers por banco por un único pipeline de ingesta con IA: un archivo (PDF/CSV/imagen) se convierte en transacciones estructuradas con gpt-4o-mini, sin código por banco.

**Architecture:** El contenido del archivo se extrae genéricamente (pdfplumber para PDF, decode para CSV, visión para imágenes) y se le pasa a gpt-4o-mini con salida estructurada (Pydantic) que devuelve las transacciones. Se mapean a `Transaccion`, se deduplican y se insertan. Un límite de ~20 subidas/mes por usuario (tabla `uploads`) frena el abuso.

**Tech Stack:** FastAPI, langchain-openai (gpt-4o-mini `.with_structured_output`), pdfplumber, SQLAlchemy, pgvector.

## Global Constraints

- Python 3.11; ruff line-length 100; mypy.
- LLM: **OpenAI gpt-4o-mini** (`settings.openai_api_key`, `settings.llm_model`), `temperature=0`.
- Extracción con salida estructurada Pydantic (`.with_structured_output`).
- `monto` negativo = gasto/cargo; positivo = ingreso/abono. `tipo` = "cargo"/"abono" según el signo. `moneda` = "CLP".
- Endpoint nuevo: **`POST /api/v1/transactions/upload`** (autenticado, SIN parámetro `banco`).
- Límite: **20 subidas por mes calendario** por usuario → 429 al exceder.
- Tests: el LLM va **mockeado** (no llama a OpenAI en CI). Fixtures de texto **sintético** — NUNCA los PDFs reales del usuario.
- PDF vía `pdfplumber`; imágenes vía visión gpt-4o-mini.
- Flutter NO está en PATH → usar `C:\flutter\bin\flutter`.

---

### Task 1: extraction_service — extracción LLM desde texto + mapeo

**Files:**
- Create: `backend/app/services/extraction_service.py`
- Modify: `backend/requirements.txt` (agregar `pdfplumber`)
- Test: `backend/tests/services/test_extraction_service.py`

**Interfaces:**
- Consumes: `settings.openai_api_key`, `settings.llm_model`, `Transaccion` (schema).
- Produces:
  - `TxnExtraida(BaseModel)`: `fecha: str`, `descripcion: str`, `monto: float`, `banco: str | None`.
  - `Extraccion(BaseModel)`: `transacciones: list[TxnExtraida]`.
  - `_map(t: TxnExtraida) -> Transaccion | None` (None si la fecha no parsea).
  - `extract_from_text(texto: str) -> list[Transaccion]`.

- [ ] **Step 1: Agregar pdfplumber a requirements**

En `backend/requirements.txt`, bajo "CSV parsing", agregar:

```
pdfplumber==0.11.4
```

Instalar:

Run: `cd backend && .\.venv\Scripts\pip install pdfplumber==0.11.4`
Expected: `Successfully installed pdfplumber-0.11.4` (o ya instalado).

- [ ] **Step 2: Escribir el test que falla**

Crear `backend/tests/services/test_extraction_service.py`:

```python
from app.services.extraction_service import (
    extract_from_text, _map, TxnExtraida, Extraccion,
)


def test_map_signo_a_tipo():
    gasto = _map(TxnExtraida(fecha="2025-06-01", descripcion="LIDER", monto=-45000, banco="BCI"))
    ingreso = _map(TxnExtraida(fecha="2025-06-10", descripcion="SUELDO", monto=2500000, banco="BCI"))
    assert gasto.tipo == "cargo" and gasto.monto == -45000 and gasto.moneda == "CLP"
    assert gasto.banco == "bci"
    assert ingreso.tipo == "abono" and ingreso.monto == 2500000


def test_map_fecha_invalida_devuelve_none():
    assert _map(TxnExtraida(fecha="no-fecha", descripcion="X", monto=-1, banco=None)) is None


def test_extract_from_text_usa_el_llm_mockeado(monkeypatch):
    fake = Extraccion(transacciones=[
        TxnExtraida(fecha="2025-06-01", descripcion="LIDER", monto=-45000, banco="BCI"),
        TxnExtraida(fecha="bad", descripcion="ROTA", monto=-1, banco=None),  # se filtra
    ])

    class FakeLLM:
        def invoke(self, _):
            return fake

    monkeypatch.setattr("app.services.extraction_service._extractor", lambda: FakeLLM())
    txns = extract_from_text("texto cualquiera")
    assert len(txns) == 1  # la de fecha mala se descarta
    assert txns[0].descripcion == "LIDER"


def test_extract_from_text_vacio():
    assert extract_from_text("   ") == []
```

- [ ] **Step 3: Correr el test y verificar que falla**

Run: `cd backend && .\.venv\Scripts\python -m pytest tests/services/test_extraction_service.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'app.services.extraction_service'`

- [ ] **Step 4: Implementar extraction_service.py**

Crear `backend/app/services/extraction_service.py`:

```python
from datetime import date
from pydantic import BaseModel
from langchain_openai import ChatOpenAI
from app.config import settings
from app.models.schemas import Transaccion


class TxnExtraida(BaseModel):
    fecha: str  # YYYY-MM-DD
    descripcion: str
    monto: float  # negativo = gasto/cargo/compra, positivo = ingreso/abono
    banco: str | None = None


class Extraccion(BaseModel):
    transacciones: list[TxnExtraida]


_PROMPT = """Eres un extractor de transacciones de cartolas bancarias chilenas \
(cuenta corriente o tarjeta de credito).
Del TEXTO extrae TODAS las transacciones reales. Para cada una:
- fecha en formato YYYY-MM-DD (usa el anio del periodo de la cartola)
- descripcion = el comercio/glosa
- monto: NEGATIVO si es gasto/cargo/compra; POSITIVO si es ingreso/abono/deposito/sueldo
- banco si lo identificas (ej: "Banco de Chile", "Scotiabank", "BCI")
IGNORA: pagos de la tarjeta (MONTO CANCELADO), totales, saldos, cupos, comprobantes de pago.

TEXTO:
{texto}"""


def _extractor():
    return ChatOpenAI(
        model=settings.llm_model,
        api_key=settings.openai_api_key,
        temperature=0,
    ).with_structured_output(Extraccion)


def _map(t: TxnExtraida) -> Transaccion | None:
    try:
        fecha = date.fromisoformat(t.fecha)
    except (ValueError, TypeError):
        return None
    banco = (t.banco or "desconocido").strip().lower().replace(" ", "") or "desconocido"
    return Transaccion(
        fecha=fecha,
        descripcion=t.descripcion,
        monto=t.monto,
        tipo="cargo" if t.monto < 0 else "abono",
        banco=banco,
        moneda="CLP",
    )


def extract_from_text(texto: str) -> list[Transaccion]:
    if not texto.strip():
        return []
    result = _extractor().invoke(_PROMPT.format(texto=texto[:30000]))
    return [m for t in result.transacciones if (m := _map(t)) is not None]
```

- [ ] **Step 5: Correr los tests y verificar que pasan**

Run: `cd backend && .\.venv\Scripts\python -m pytest tests/services/test_extraction_service.py -v`
Expected: PASS (4 passed)

- [ ] **Step 6: Commit**

```bash
git add backend/app/services/extraction_service.py backend/tests/services/test_extraction_service.py backend/requirements.txt
git commit -m "feat(extraction): extracción de transacciones con gpt-4o-mini (texto)"
```

---

### Task 2: Ruteo por tipo de archivo (PDF / CSV / imagen)

**Files:**
- Modify: `backend/app/services/extraction_service.py` (agregar funciones por tipo + dispatcher)
- Test: `backend/tests/services/test_extraction_routing.py`

**Interfaces:**
- Consumes: `extract_from_text` (Task 1).
- Produces:
  - `extract_from_pdf(content: bytes) -> list[Transaccion]`
  - `extract_from_csv(content: bytes) -> list[Transaccion]`
  - `extract_from_image(content: bytes, ext: str) -> list[Transaccion]`
  - `extract_from_file(content: bytes, filename: str) -> list[Transaccion]` (rutea por extensión; `ValueError` si no soportado).

- [ ] **Step 1: Escribir el test que falla**

Crear `backend/tests/services/test_extraction_routing.py`:

```python
import pytest
from app.services import extraction_service as ex


def test_dispatch_pdf(monkeypatch):
    monkeypatch.setattr(ex, "extract_from_pdf", lambda c: ["PDF"])
    assert ex.extract_from_file(b"x", "cartola.PDF") == ["PDF"]


def test_dispatch_csv(monkeypatch):
    monkeypatch.setattr(ex, "extract_from_csv", lambda c: ["CSV"])
    assert ex.extract_from_file(b"x", "cartola.csv") == ["CSV"]


def test_dispatch_imagen(monkeypatch):
    monkeypatch.setattr(ex, "extract_from_image", lambda c, e: ["IMG"])
    assert ex.extract_from_file(b"x", "boleta.jpg") == ["IMG"]


def test_dispatch_no_soportado():
    with pytest.raises(ValueError):
        ex.extract_from_file(b"x", "archivo.txt")


def test_extract_from_csv_decodifica(monkeypatch):
    captured = {}
    monkeypatch.setattr(ex, "extract_from_text", lambda t: captured.setdefault("t", t) or [])
    ex.extract_from_csv("fecha;glosa\n01/06;café".encode("latin-1"))
    assert "café" in captured["t"]
```

- [ ] **Step 2: Correr el test y verificar que falla**

Run: `cd backend && .\.venv\Scripts\python -m pytest tests/services/test_extraction_routing.py -v`
Expected: FAIL — `AttributeError: module ... has no attribute 'extract_from_pdf'`

- [ ] **Step 3: Implementar las funciones por tipo + dispatcher**

Agregar al final de `backend/app/services/extraction_service.py`:

```python
import io
import base64
import pdfplumber
from langchain_core.messages import HumanMessage


def extract_from_pdf(content: bytes) -> list[Transaccion]:
    with pdfplumber.open(io.BytesIO(content)) as pdf:
        texto = "\n".join((p.extract_text() or "") for p in pdf.pages)
    return extract_from_text(texto)


def extract_from_csv(content: bytes) -> list[Transaccion]:
    for enc in ("utf-8", "latin-1"):
        try:
            return extract_from_text(content.decode(enc))
        except UnicodeDecodeError:
            continue
    return extract_from_text(content.decode("latin-1", errors="ignore"))


def extract_from_image(content: bytes, ext: str) -> list[Transaccion]:
    b64 = base64.b64encode(content).decode()
    mime = "image/jpeg" if ext in ("jpg", "jpeg") else f"image/{ext}"
    msg = HumanMessage(content=[
        {"type": "text", "text": _PROMPT.format(texto="(ver imagen adjunta)")},
        {"type": "image_url", "image_url": {"url": f"data:{mime};base64,{b64}"}},
    ])
    result = _extractor().invoke([msg])
    return [m for t in result.transacciones if (m := _map(t)) is not None]


def extract_from_file(content: bytes, filename: str) -> list[Transaccion]:
    ext = filename.lower().rsplit(".", 1)[-1] if "." in filename else ""
    if ext == "pdf":
        return extract_from_pdf(content)
    if ext == "csv":
        return extract_from_csv(content)
    if ext in ("jpg", "jpeg", "png", "webp"):
        return extract_from_image(content, ext)
    raise ValueError(f"Tipo de archivo no soportado: .{ext}")
```

- [ ] **Step 4: Correr los tests y verificar que pasan**

Run: `cd backend && .\.venv\Scripts\python -m pytest tests/services/test_extraction_routing.py -v`
Expected: PASS (5 passed)

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/extraction_service.py backend/tests/services/test_extraction_routing.py
git commit -m "feat(extraction): ruteo por tipo (pdf/csv/imagen) + dispatcher"
```

---

### Task 3: Tabla `uploads` + servicio de límite mensual

**Files:**
- Modify: `backend/app/db/models.py` (agregar `Upload`)
- Create: `backend/app/services/upload_limit.py`
- Create: `backend/migrations/002_uploads.sql`
- Test: `backend/tests/services/test_upload_limit.py`

**Interfaces:**
- Consumes: `Base` (db).
- Produces:
  - `Upload` (modelo: id, user_id, filename, n_transacciones, fuente, created_at).
  - `LIMITE_MENSUAL = 20`, `UploadLimitError`.
  - `check_limit(session, user_id: str) -> None` (lanza `UploadLimitError` si ya hay ≥20 este mes).
  - `log_upload(session, user_id: str, filename: str, n: int, fuente: str = "cartola") -> None`.

- [ ] **Step 1: Agregar el modelo Upload**

En `backend/app/db/models.py`, agregar al import `Integer`:

```python
from sqlalchemy import Column, String, Text, Numeric, Date, DateTime, Integer
```

Y al final del archivo, la clase:

```python
class Upload(Base):
    __tablename__ = "uploads"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), nullable=False, index=True)
    filename = Column(String, nullable=False)
    n_transacciones = Column(Integer, nullable=False, default=0)
    fuente = Column(String, nullable=False, default="cartola")
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
```

(El archivo ya importa `uuid`, `datetime`, `timezone` de la Task 2 del Plan 1.)

- [ ] **Step 2: Escribir el test que falla**

Crear `backend/tests/services/test_upload_limit.py`:

```python
import pytest
from app.services.upload_limit import check_limit, log_upload, UploadLimitError, LIMITE_MENSUAL


def test_log_y_check_bajo_limite(session):
    for i in range(LIMITE_MENSUAL - 1):
        log_upload(session, "u1", f"f{i}.pdf", 3)
    check_limit(session, "u1")  # 19 < 20 → no lanza


def test_check_corta_en_el_limite(session):
    for i in range(LIMITE_MENSUAL):
        log_upload(session, "u1", f"f{i}.pdf", 1)
    with pytest.raises(UploadLimitError):
        check_limit(session, "u1")


def test_limite_es_por_usuario(session):
    for i in range(LIMITE_MENSUAL):
        log_upload(session, "u1", f"f{i}.pdf", 1)
    check_limit(session, "u2")  # otro usuario, sin subidas → no lanza
```

- [ ] **Step 3: Correr el test y verificar que falla**

Run: `cd backend && .\.venv\Scripts\python -m pytest tests/services/test_upload_limit.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'app.services.upload_limit'`

- [ ] **Step 4: Implementar upload_limit.py**

Crear `backend/app/services/upload_limit.py`:

```python
from datetime import datetime, timezone
from sqlalchemy import func
from sqlalchemy.orm import Session
from app.db.models import Upload

LIMITE_MENSUAL = 20


class UploadLimitError(Exception):
    pass


def _inicio_mes() -> datetime:
    now = datetime.now(timezone.utc)
    return now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)


def check_limit(session: Session, user_id: str) -> None:
    count = (
        session.query(func.count(Upload.id))
        .filter(Upload.user_id == user_id, Upload.created_at >= _inicio_mes())
        .scalar()
    ) or 0
    if count >= LIMITE_MENSUAL:
        raise UploadLimitError("Llegaste al límite de subidas del mes")


def log_upload(
    session: Session, user_id: str, filename: str, n: int, fuente: str = "cartola"
) -> None:
    session.add(Upload(user_id=user_id, filename=filename, n_transacciones=n, fuente=fuente))
    session.commit()
```

- [ ] **Step 5: Crear la migración SQL**

Crear `backend/migrations/002_uploads.sql`:

```sql
create table if not exists uploads (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  filename        text not null,
  n_transacciones integer not null default 0,
  fuente          text not null default 'cartola',
  created_at      timestamptz default now()
);
create index if not exists idx_uploads_user_created on uploads (user_id, created_at);

alter table uploads enable row level security;
create policy "ver_propias_uploads" on uploads for select using (auth.uid() = user_id);
create policy "insertar_propias_uploads" on uploads for insert with check (auth.uid() = user_id);
```

> **Nota manual:** este SQL se ejecuta una vez en el SQL Editor de Supabase.

- [ ] **Step 6: Correr los tests y verificar que pasan**

Run: `cd backend && .\.venv\Scripts\python -m pytest tests/services/test_upload_limit.py -v`
Expected: PASS (3 passed)

- [ ] **Step 7: Commit**

```bash
git add backend/app/db/models.py backend/app/services/upload_limit.py backend/migrations/002_uploads.sql backend/tests/services/test_upload_limit.py
git commit -m "feat(uploads): tabla uploads + límite de 20 subidas por mes"
```

---

### Task 4: Endpoint `POST /transactions/upload` (universal)

**Files:**
- Modify: `backend/app/api/routes/upload.py`
- Test: `backend/tests/api/test_upload_universal.py`

**Interfaces:**
- Consumes: `get_current_user`, `get_session`, `extract_from_file` (Task 2), `check_limit`/`log_upload`/`UploadLimitError` (Task 3), `insert_transactions`, `indexar_transacciones`.
- Produces: `POST /api/v1/transactions/upload` autenticado (PDF/CSV/imagen, sin `banco`).

- [ ] **Step 1: Agregar la ruta**

Agregar al final de `backend/app/api/routes/upload.py` (los imports `Depends`, `Session`, `get_current_user`, `get_session`, `UploadFile`, `File`, `HTTPException`, `insert_transactions`, `indexar_transacciones`, `UploadResponse` ya están del Plan 1):

```python
from app.services.extraction_service import extract_from_file
from app.services.upload_limit import check_limit, log_upload, UploadLimitError


@router.post("/transactions/upload", response_model=UploadResponse, status_code=201)
async def upload_universal(
    file: UploadFile = File(...),
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    try:
        check_limit(session, user_id)
    except UploadLimitError as e:
        raise HTTPException(status_code=429, detail=str(e))

    content = await file.read()
    filename = file.filename or "archivo"
    try:
        transacciones = extract_from_file(content, filename)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    if not transacciones:
        raise HTTPException(
            status_code=422, detail="No detectamos transacciones en el archivo."
        )

    nuevas = insert_transactions(session, user_id, transacciones, fuente="cartola")
    if nuevas:
        indexar_transacciones(nuevas, user_id)
    log_upload(session, user_id, filename, len(nuevas))

    return UploadResponse(
        banco=transacciones[0].banco,
        transacciones_procesadas=len(nuevas),
        message=f"{len(nuevas)} transacciones nuevas ({len(transacciones) - len(nuevas)} duplicadas).",
    )
```

- [ ] **Step 2: Escribir el test que falla**

Crear `backend/tests/api/test_upload_universal.py`:

```python
import io
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from datetime import date
from app.main import app
from app.db.base import Base, get_session
from app.auth.jwt import get_current_user
from app.models.schemas import Transaccion
import app.db.models  # noqa: F401
import app.api.routes.upload as upload_mod


@pytest.fixture
def client(monkeypatch):
    engine = create_engine(
        "sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    Base.metadata.create_all(engine)
    TestSession = sessionmaker(bind=engine)

    def _override_session():
        s = TestSession()
        try:
            yield s
        finally:
            s.close()

    # extracción mockeada: 2 transacciones fijas, sin tocar OpenAI ni pgvector
    monkeypatch.setattr(upload_mod, "extract_from_file", lambda c, f: [
        Transaccion(fecha=date(2025, 6, 1), descripcion="LIDER", monto=-45000,
                    tipo="cargo", banco="bci"),
        Transaccion(fecha=date(2025, 6, 10), descripcion="SUELDO", monto=2500000,
                    tipo="abono", banco="bci"),
    ])
    monkeypatch.setattr(upload_mod, "indexar_transacciones", lambda txns, uid: len(txns))

    app.dependency_overrides[get_session] = _override_session
    app.dependency_overrides[get_current_user] = lambda: "u1"
    yield TestClient(app)
    app.dependency_overrides.clear()


def _file():
    return {"file": ("cartola.pdf", io.BytesIO(b"%PDF-fake"), "application/pdf")}


def test_upload_inserta_y_dedup(client):
    r = client.post("/api/v1/transactions/upload", files=_file())
    assert r.status_code == 201
    assert r.json()["transacciones_procesadas"] == 2
    r2 = client.post("/api/v1/transactions/upload", files=_file())
    assert r2.json()["transacciones_procesadas"] == 0  # dedup


def test_upload_sin_transacciones_422(client, monkeypatch):
    monkeypatch.setattr(upload_mod, "extract_from_file", lambda c, f: [])
    r = client.post("/api/v1/transactions/upload", files=_file())
    assert r.status_code == 422


def test_upload_limite_429(client, monkeypatch):
    from app.services.upload_limit import UploadLimitError
    def _raise(s, u):
        raise UploadLimitError("Llegaste al límite de subidas del mes")
    monkeypatch.setattr(upload_mod, "check_limit", _raise)
    r = client.post("/api/v1/transactions/upload", files=_file())
    assert r.status_code == 429
```

- [ ] **Step 3: Correr el test y verificar que falla**

Run: `cd backend && .\.venv\Scripts\python -m pytest tests/api/test_upload_universal.py -v`
Expected: FAIL → 404 (la ruta aún no existe) en la primera corrida antes de implementar; tras implementar el Step 1, re-correr.

- [ ] **Step 4: Correr los tests y verificar que pasan**

Run: `cd backend && .\.venv\Scripts\python -m pytest tests/api/test_upload_universal.py -v`
Expected: PASS (3 passed)

- [ ] **Step 5: Correr toda la suite**

Run: `cd backend && .\.venv\Scripts\python -m pytest -q`
Expected: todos verde.

- [ ] **Step 6: Commit**

```bash
git add backend/app/api/routes/upload.py backend/tests/api/test_upload_universal.py
git commit -m "feat(api): POST /transactions/upload universal (extracción IA + límite + dedup)"
```

---

### Task 5: Frontend — subir cualquier archivo al endpoint universal

**Files:**
- Modify: `frontend/lib/services/api_service.dart`
- Modify: `frontend/lib/screens/upload_screen.dart`
- Test: `frontend/test/api_service_upload_test.dart`

**Interfaces:**
- Consumes: el endpoint `POST /transactions/upload`.
- Produces: `ApiService.uploadFile(Uint8List bytes, String filename) -> Future<UploadResult>`.

- [ ] **Step 1: Escribir el test que falla**

Crear `frontend/test/api_service_upload_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:preguntale_tu_plata/services/api_service.dart';

void main() {
  test('uploadFile pega a /transactions/upload con Bearer', () async {
    late http.BaseRequest captured;
    final mock = MockClient.streaming((req, body) async {
      captured = req;
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(
            {'banco': 'bci', 'transacciones_procesadas': 2, 'message': 'ok'}))),
        201,
      );
    });
    final api = ApiService(client: mock, token: () => 'T', baseUrl: 'http://x/api/v1');

    final r = await api.uploadFile(Uint8List.fromList([1, 2, 3]), 'cartola.pdf');

    expect(captured.url.path, contains('/transactions/upload'));
    expect(captured.headers['Authorization'], 'Bearer T');
    expect(r.count, 2);
  });
}
```

- [ ] **Step 2: Correr el test y verificar que falla**

Run: `cd frontend && C:\flutter\bin\flutter test test/api_service_upload_test.dart`
Expected: FAIL — `ApiService` no tiene `uploadFile`.

- [ ] **Step 3: Agregar uploadFile a ApiService**

En `frontend/lib/services/api_service.dart`, reemplazar el método `uploadCsv(...)` por:

```dart
  Future<UploadResult> uploadFile(Uint8List bytes, String filename) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/transactions/upload'),
    );
    req.headers.addAll(_headers());
    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await _client.send(req);
    final body = await streamed.stream.bytesToString();
    final j = jsonDecode(body);
    if (streamed.statusCode == 201) {
      return UploadResult(banco: j['banco'] as String, count: j['transacciones_procesadas'] as int);
    }
    throw ApiException(j['detail']?.toString() ?? 'Error al subir el archivo', streamed.statusCode);
  }
```

- [ ] **Step 4: Correr el test y verificar que pasa**

Run: `cd frontend && C:\flutter\bin\flutter test test/api_service_upload_test.dart`
Expected: PASS (1 passed)

- [ ] **Step 5: Actualizar UploadScreen (acepta pdf/csv/imagen, sin banco)**

Reemplazar el contenido de `frontend/lib/screens/upload_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/data_providers.dart';
import '../services/api_service.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});
  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  bool _cargando = false;
  String? _msg;

  Future<void> _subir() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'csv', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (res == null || res.files.single.bytes == null) return;
    setState(() {
      _cargando = true;
      _msg = null;
    });
    try {
      final r = await ref.read(apiProvider).uploadFile(
            res.files.single.bytes!, res.files.single.name);
      ref.invalidate(summaryProvider);
      ref.invalidate(transactionsProvider);
      setState(() => _msg = '${r.count} transacciones cargadas');
    } on ApiException catch (e) {
      setState(() => _msg = e.statusCode == 429
          ? 'Llegaste al límite de subidas del mes'
          : e.message);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subir cartola o boleta')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Sube tu cartola (PDF/CSV) o una foto de boleta. La leemos con IA.',
                style: TextStyle(color: Color(0xFF8B949E))),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _cargando ? null : _subir,
              icon: const Icon(Icons.upload_file),
              label: Text(_cargando ? 'Procesando...' : 'Elegir archivo'),
            ),
            if (_msg != null) ...[
              const SizedBox(height: 16),
              Text(_msg!, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Verificar suite + analyze**

Run: `cd frontend && C:\flutter\bin\flutter test`
Expected: todos verde (incluye el nuevo test).

Run: `cd frontend && C:\flutter\bin\flutter analyze`
Expected: sin errores. (Si `uploadCsv` se referenciaba en otro lado, el analyze lo marca → reemplazar esa llamada por `uploadFile`.)

- [ ] **Step 7: Commit**

```bash
git add frontend/lib/services/api_service.dart frontend/lib/screens/upload_screen.dart frontend/test/api_service_upload_test.dart
git commit -m "feat(frontend): subir PDF/CSV/imagen al endpoint universal (sin elegir banco)"
```

---

## Verificación manual final

1. Aplicar `002_uploads.sql` en el SQL Editor de Supabase.
2. Redeploy del backend a HF (upload_folder con el código nuevo) — el secret `OPENAI_API_KEY` ya está.
3. En la PWA: Subir → elegir un **PDF de cartola** real → debe extraer las transacciones y aparecer en el dashboard.
4. Subir 21 veces en el mes → la 21ª debe responder 429.

## Notas para después
- PDF escaneado (sin texto) → render a imagen + visión (refinamiento).
- Paso "revisar/editar antes de guardar" en la UI.
- Borrar definitivamente los parsers por banco (`bci_parser.py`, etc.) y el endpoint `upload-csv`.
