# Plan 2 — Flutter: Login + Dashboard — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Frontend Flutter con login Supabase (email+password) y dashboard que consume el backend del Plan 1, inyectando el JWT de la sesión en cada request.

**Architecture:** Riverpod para estado (sesión auth + datos async), go_router con redirect por estado de auth, supabase_flutter para auth+sesión. `ApiService` desacoplado (recibe `http.Client` + un getter de token) para ser testeable sin Supabase. Las pantallas chat/upload construidas antes se reusan detrás del auth.

**Tech Stack:** Flutter 3.32 / Dart 3.8, flutter_riverpod, go_router, supabase_flutter, fl_chart, http, file_picker; mocktail (tests).

## Global Constraints

- Flutter SDK `^3.8.1` (ya en `pubspec.yaml`). Correr todo desde `frontend/`.
- Comandos: `flutter pub get`, `flutter test`, `flutter analyze`. NO existe pytest acá.
- Backend del Plan 1: base `http://localhost:8000/api/v1`. Endpoints exactos:
  `POST /transactions/upload-csv?banco=`, `POST /chat/ask`, `GET /transactions/summary`,
  `GET /transactions`. Todos requieren `Authorization: Bearer <access_token>`.
- Supabase (públicos por diseño): `SUPABASE_URL=https://bwjupdnnwgosivknpsoy.supabase.co`,
  anon key (la del proyecto, role=anon).
- El backend devuelve `gastos` como montos NEGATIVOS; el summary agrupa por `moneda` (CLP).
- Idioma de cara al usuario: español chileno, mensajes cortos.
- Tema oscuro fintech ya definido (fondo `#0D1117`, primario `#00C896`).

---

### Task 1: Dependencias + config

**Files:**
- Modify: `frontend/pubspec.yaml`
- Create: `frontend/lib/config.dart`
- Test: `frontend/test/config_test.dart`

**Interfaces:**
- Produces: `Config.supabaseUrl`, `Config.supabaseAnonKey`, `Config.backendBaseUrl` (todos `static const String`).

- [ ] **Step 1: Agregar dependencias**

En `frontend/pubspec.yaml`, reemplazar el bloque `dependencies:` y `dev_dependencies:` por:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  http: ^1.2.2
  file_picker: ^8.1.2
  flutter_riverpod: ^2.6.1
  go_router: ^14.6.2
  supabase_flutter: ^2.8.0
  fl_chart: ^0.69.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  mocktail: ^1.0.4
```

Run: `cd frontend && flutter pub get`
Expected: `Got dependencies!` (sin errores de resolución).

- [ ] **Step 2: Escribir el test que falla**

Crear `frontend/test/config_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:preguntale_tu_plata/config.dart';

void main() {
  test('config tiene URL de supabase y backend válidos', () {
    expect(Config.supabaseUrl, startsWith('https://'));
    expect(Config.supabaseAnonKey, isNotEmpty);
    expect(Config.backendBaseUrl, contains('/api/v1'));
  });
}
```

- [ ] **Step 3: Correr el test y verificar que falla**

Run: `cd frontend && flutter test test/config_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'preguntale_tu_plata'... config.dart` no existe.

- [ ] **Step 4: Crear config.dart**

Crear `frontend/lib/config.dart`:

```dart
/// Valores públicos por diseño: el anon key de Supabase es para clientes; la
/// seguridad real está en RLS + la validación de JWT del backend.
class Config {
  static const String supabaseUrl = 'https://bwjupdnnwgosivknpsoy.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ3anVwZG5ud2dvc2l2a25wc295Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIzMDQ2NzYsImV4cCI6MjA5Nzg4MDY3Nn0.GNiFL1gwE9utpgEhr7GBEdUYYG_QVPZfbGd9aw77MB8';

  /// En web (demo) el backend corre en localhost. En mobile real habría que usar
  /// la IP de la máquina o un backend desplegado (fuera de scope).
  static const String backendBaseUrl = 'http://localhost:8000/api/v1';
}
```

- [ ] **Step 5: Correr el test y verificar que pasa**

Run: `cd frontend && flutter test test/config_test.dart`
Expected: PASS (1 passed).

- [ ] **Step 6: Commit**

```bash
git add frontend/pubspec.yaml frontend/pubspec.lock frontend/lib/config.dart frontend/test/config_test.dart
git commit -m "feat(frontend): deps (riverpod, go_router, supabase, fl_chart) + config"
```

---

### Task 2: Modelos (Transaction, Summary)

**Files:**
- Create: `frontend/lib/models/transaction.dart`
- Create: `frontend/lib/models/summary.dart`
- Test: `frontend/test/models_test.dart`

**Interfaces:**
- Produces:
  - `Transaction.fromJson(Map<String,dynamic>)` con campos `id, fecha(String), descripcion, monto(double), moneda, tarjeta(String?), tipo, categoria(String?), banco, fuente`.
  - `Summary.fromJson(Map<String,dynamic>)` con `porMoneda: Map<String, MonedaTotales>`, `gastosPorBanco: List<BancoTotal>`, `gastosPorCategoria: List<CategoriaTotal>`.
  - `MonedaTotales(ingresos, gastos)`, `BancoTotal(banco, total)`, `CategoriaTotal(categoria, total)`.

- [ ] **Step 1: Escribir el test que falla**

Crear `frontend/test/models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:preguntale_tu_plata/models/transaction.dart';
import 'package:preguntale_tu_plata/models/summary.dart';

void main() {
  test('Transaction.fromJson parsea campos', () {
    final t = Transaction.fromJson({
      'id': 'abc', 'fecha': '2025-06-01', 'descripcion': 'LIDER',
      'monto': -45000.0, 'moneda': 'CLP', 'tarjeta': null,
      'tipo': 'cargo', 'categoria': null, 'banco': 'BCI', 'fuente': 'cartola',
    });
    expect(t.id, 'abc');
    expect(t.monto, -45000.0);
    expect(t.banco, 'BCI');
    expect(t.tarjeta, isNull);
  });

  test('Summary.fromJson parsea por_moneda y gastos_por_banco', () {
    final s = Summary.fromJson({
      'por_moneda': {'CLP': {'ingresos': 2500000.0, 'gastos': -89890.0}},
      'gastos_por_categoria': [],
      'gastos_por_banco': [{'banco': 'BCI', 'total': -89890.0}],
    });
    expect(s.porMoneda['CLP']!.gastos, -89890.0);
    expect(s.porMoneda['CLP']!.ingresos, 2500000.0);
    expect(s.gastosPorBanco.single.banco, 'BCI');
  });
}
```

- [ ] **Step 2: Correr el test y verificar que falla**

Run: `cd frontend && flutter test test/models_test.dart`
Expected: FAIL — los archivos de modelos no existen.

- [ ] **Step 3: Crear transaction.dart**

Crear `frontend/lib/models/transaction.dart`:

```dart
class Transaction {
  final String id;
  final String fecha;
  final String descripcion;
  final double monto;
  final String moneda;
  final String? tarjeta;
  final String tipo;
  final String? categoria;
  final String banco;
  final String fuente;

  const Transaction({
    required this.id,
    required this.fecha,
    required this.descripcion,
    required this.monto,
    required this.moneda,
    required this.tarjeta,
    required this.tipo,
    required this.categoria,
    required this.banco,
    required this.fuente,
  });

  factory Transaction.fromJson(Map<String, dynamic> j) => Transaction(
        id: j['id'] as String,
        fecha: j['fecha'] as String,
        descripcion: j['descripcion'] as String,
        monto: (j['monto'] as num).toDouble(),
        moneda: j['moneda'] as String,
        tarjeta: j['tarjeta'] as String?,
        tipo: j['tipo'] as String,
        categoria: j['categoria'] as String?,
        banco: j['banco'] as String,
        fuente: j['fuente'] as String,
      );
}
```

- [ ] **Step 4: Crear summary.dart**

Crear `frontend/lib/models/summary.dart`:

```dart
class MonedaTotales {
  final double ingresos;
  final double gastos; // negativo
  const MonedaTotales({required this.ingresos, required this.gastos});

  factory MonedaTotales.fromJson(Map<String, dynamic> j) => MonedaTotales(
        ingresos: (j['ingresos'] as num).toDouble(),
        gastos: (j['gastos'] as num).toDouble(),
      );
}

class BancoTotal {
  final String banco;
  final double total; // negativo
  const BancoTotal({required this.banco, required this.total});

  factory BancoTotal.fromJson(Map<String, dynamic> j) => BancoTotal(
        banco: j['banco'] as String,
        total: (j['total'] as num).toDouble(),
      );
}

class CategoriaTotal {
  final String categoria;
  final double total; // negativo
  const CategoriaTotal({required this.categoria, required this.total});

  factory CategoriaTotal.fromJson(Map<String, dynamic> j) => CategoriaTotal(
        categoria: j['categoria'] as String,
        total: (j['total'] as num).toDouble(),
      );
}

class Summary {
  final Map<String, MonedaTotales> porMoneda;
  final List<CategoriaTotal> gastosPorCategoria;
  final List<BancoTotal> gastosPorBanco;

  const Summary({
    required this.porMoneda,
    required this.gastosPorCategoria,
    required this.gastosPorBanco,
  });

  factory Summary.fromJson(Map<String, dynamic> j) => Summary(
        porMoneda: (j['por_moneda'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, MonedaTotales.fromJson(v as Map<String, dynamic>)),
        ),
        gastosPorCategoria: (j['gastos_por_categoria'] as List)
            .map((e) => CategoriaTotal.fromJson(e as Map<String, dynamic>))
            .toList(),
        gastosPorBanco: (j['gastos_por_banco'] as List)
            .map((e) => BancoTotal.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
```

- [ ] **Step 5: Correr el test y verificar que pasa**

Run: `cd frontend && flutter test test/models_test.dart`
Expected: PASS (2 passed).

- [ ] **Step 6: Commit**

```bash
git add frontend/lib/models frontend/test/models_test.dart
git commit -m "feat(frontend): modelos Transaction y Summary con fromJson"
```

---

### Task 3: ApiService (con JWT, testeable)

**Files:**
- Create: `frontend/lib/services/api_service.dart`
- Delete: `frontend/lib/services/api.dart` (reemplazado)
- Test: `frontend/test/api_service_test.dart`

**Interfaces:**
- Consumes: `Config` (Task 1), `Transaction`/`Summary` (Task 2).
- Produces: `ApiService({http.Client? client, required String? Function() token, String baseUrl})` con métodos:
  - `Future<Summary> getSummary()`
  - `Future<List<Transaction>> getTransactions()`
  - `Future<AskResult> ask(String question)`
  - `Future<UploadResult> uploadCsv(Uint8List bytes, String filename, String banco)`
  - tipos `AskResult(answer, citations)`, `Citation(fecha, descripcion, monto)`, `UploadResult(banco, count)`.

- [ ] **Step 1: Escribir el test que falla**

Crear `frontend/test/api_service_test.dart`:

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:preguntale_tu_plata/services/api_service.dart';

void main() {
  test('getSummary manda Bearer token y parsea la respuesta', () async {
    late http.Request captured;
    final mock = MockClient((req) async {
      captured = req;
      return http.Response(
        jsonEncode({
          'por_moneda': {'CLP': {'ingresos': 100.0, 'gastos': -50.0}},
          'gastos_por_categoria': [],
          'gastos_por_banco': [{'banco': 'BCI', 'total': -50.0}],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = ApiService(client: mock, token: () => 'TOKEN123', baseUrl: 'http://x/api/v1');

    final s = await api.getSummary();

    expect(captured.headers['Authorization'], 'Bearer TOKEN123');
    expect(s.porMoneda['CLP']!.gastos, -50.0);
  });

  test('getTransactions parsea lista', () async {
    final mock = MockClient((req) async => http.Response(
          jsonEncode([
            {'id': '1', 'fecha': '2025-06-01', 'descripcion': 'LIDER', 'monto': -45000.0,
             'moneda': 'CLP', 'tarjeta': null, 'tipo': 'cargo', 'categoria': null,
             'banco': 'BCI', 'fuente': 'cartola'}
          ]),
          200,
          headers: {'content-type': 'application/json'},
        ));
    final api = ApiService(client: mock, token: () => 't', baseUrl: 'http://x/api/v1');
    final list = await api.getTransactions();
    expect(list.length, 1);
    expect(list.first.descripcion, 'LIDER');
  });

  test('ask parsea answer y citations', () async {
    final mock = MockClient((req) async => http.Response(
          utf8.encode(jsonEncode({
            'answer': 'Gastaste 45000',
            'citations': [{'fecha': '2025-06-01', 'descripcion': 'LIDER', 'monto': -45000.0}],
          })),
          200,
          headers: {'content-type': 'application/json'},
        ));
    final api = ApiService(client: mock, token: () => 't', baseUrl: 'http://x/api/v1');
    final r = await api.ask('cuanto gaste');
    expect(r.answer, 'Gastaste 45000');
    expect(r.citations.single.monto, -45000.0);
  });
}
```

- [ ] **Step 2: Correr el test y verificar que falla**

Run: `cd frontend && flutter test test/api_service_test.dart`
Expected: FAIL — `api_service.dart` no existe.

- [ ] **Step 3: Crear api_service.dart**

Crear `frontend/lib/services/api_service.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/transaction.dart';
import '../models/summary.dart';

class ApiService {
  final http.Client _client;
  final String? Function() _token;
  final String baseUrl;

  ApiService({
    http.Client? client,
    required String? Function() token,
    this.baseUrl = Config.backendBaseUrl,
  })  : _client = client ?? http.Client(),
        _token = token;

  Map<String, String> _headers([Map<String, String>? extra]) => {
        'Authorization': 'Bearer ${_token() ?? ''}',
        if (extra != null) ...extra,
      };

  Future<Summary> getSummary() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/transactions/summary'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      return Summary.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException('No se pudo cargar el resumen', res.statusCode);
  }

  Future<List<Transaction>> getTransactions() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/transactions'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List;
      return list.map((e) => Transaction.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw ApiException('No se pudieron cargar las transacciones', res.statusCode);
  }

  Future<AskResult> ask(String question) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/chat/ask'),
      headers: _headers({'Content-Type': 'application/json; charset=utf-8'}),
      body: jsonEncode({'question': question}),
    );
    if (res.statusCode == 200) {
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      return AskResult(
        answer: j['answer'] as String,
        citations: (j['citations'] as List)
            .map((c) => Citation(
                  fecha: c['fecha'] as String,
                  descripcion: c['descripcion'] as String,
                  monto: (c['monto'] as num).toDouble(),
                ))
            .toList(),
      );
    }
    throw ApiException('No se pudo procesar la pregunta', res.statusCode);
  }

  Future<UploadResult> uploadCsv(Uint8List bytes, String filename, String banco) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/transactions/upload-csv?banco=$banco'),
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
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);
  @override
  String toString() => message;
}

class AskResult {
  final String answer;
  final List<Citation> citations;
  const AskResult({required this.answer, required this.citations});
}

class Citation {
  final String fecha;
  final String descripcion;
  final double monto;
  const Citation({required this.fecha, required this.descripcion, required this.monto});
}

class UploadResult {
  final String banco;
  final int count;
  const UploadResult({required this.banco, required this.count});
}
```

- [ ] **Step 4: Borrar el api.dart viejo**

```bash
git rm frontend/lib/services/api.dart
```

(El viejo apuntaba a `/upload` y `/ask` sin auth; queda obsoleto.)

- [ ] **Step 5: Correr el test y verificar que pasa**

Run: `cd frontend && flutter test test/api_service_test.dart`
Expected: PASS (3 passed).

- [ ] **Step 6: Commit**

```bash
git add frontend/lib/services/api_service.dart frontend/test/api_service_test.dart
git commit -m "feat(frontend): ApiService con JWT, endpoints del Plan 1, testeable con MockClient"
```

---

### Task 4: Providers (auth + datos)

**Files:**
- Create: `frontend/lib/providers/auth_provider.dart`
- Create: `frontend/lib/providers/data_providers.dart`
- Test: `frontend/test/providers_test.dart`

**Interfaces:**
- Consumes: `ApiService` (Task 3), supabase_flutter.
- Produces:
  - `authStateProvider` — `StreamProvider<AuthState>` desde `Supabase.instance.client.auth.onAuthStateChange`.
  - `isLoggedInProvider` — `Provider<bool>` (hay sesión actual).
  - `apiProvider` — `Provider<ApiService>` (token = `Supabase.instance.client.auth.currentSession?.accessToken`).
  - `summaryProvider` — `FutureProvider<Summary>`.
  - `transactionsProvider` — `FutureProvider<List<Transaction>>`.

- [ ] **Step 1: Escribir el test que falla**

Crear `frontend/test/providers_test.dart` (testea que summary/transactions usan el `apiProvider` inyectado, sin tocar Supabase):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preguntale_tu_plata/services/api_service.dart';
import 'package:preguntale_tu_plata/models/summary.dart';
import 'package:preguntale_tu_plata/models/transaction.dart';
import 'package:preguntale_tu_plata/providers/data_providers.dart';

class MockApi extends Mock implements ApiService {}

void main() {
  test('summaryProvider devuelve lo que da ApiService', () async {
    final api = MockApi();
    when(() => api.getSummary()).thenAnswer((_) async => const Summary(
          porMoneda: {'CLP': MonedaTotales(ingresos: 100, gastos: -50)},
          gastosPorCategoria: [],
          gastosPorBanco: [BancoTotal(banco: 'BCI', total: -50)],
        ));
    final container = ProviderContainer(overrides: [apiProvider.overrideWithValue(api)]);
    addTearDown(container.dispose);

    final s = await container.read(summaryProvider.future);
    expect(s.porMoneda['CLP']!.gastos, -50.0);
  });

  test('transactionsProvider devuelve la lista del ApiService', () async {
    final api = MockApi();
    when(() => api.getTransactions()).thenAnswer((_) async => const [
          Transaction(id: '1', fecha: '2025-06-01', descripcion: 'LIDER', monto: -45000,
              moneda: 'CLP', tarjeta: null, tipo: 'cargo', categoria: null, banco: 'BCI',
              fuente: 'cartola'),
        ]);
    final container = ProviderContainer(overrides: [apiProvider.overrideWithValue(api)]);
    addTearDown(container.dispose);

    final list = await container.read(transactionsProvider.future);
    expect(list.single.descripcion, 'LIDER');
  });
}
```

- [ ] **Step 2: Correr el test y verificar que falla**

Run: `cd frontend && flutter test test/providers_test.dart`
Expected: FAIL — `data_providers.dart` no existe.

- [ ] **Step 3: Crear auth_provider.dart**

Crear `frontend/lib/providers/auth_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Emite cada cambio de sesión (login, logout, refresh).
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// True si hay una sesión activa. Se recalcula cuando authStateProvider emite.
final isLoggedInProvider = Provider<bool>((ref) {
  ref.watch(authStateProvider);
  return Supabase.instance.client.auth.currentSession != null;
});
```

- [ ] **Step 4: Crear data_providers.dart**

Crear `frontend/lib/providers/data_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import '../models/summary.dart';
import '../models/transaction.dart';

final apiProvider = Provider<ApiService>((ref) {
  return ApiService(
    token: () => Supabase.instance.client.auth.currentSession?.accessToken,
  );
});

final summaryProvider = FutureProvider<Summary>((ref) {
  return ref.watch(apiProvider).getSummary();
});

final transactionsProvider = FutureProvider<List<Transaction>>((ref) {
  return ref.watch(apiProvider).getTransactions();
});
```

- [ ] **Step 5: Correr el test y verificar que pasa**

Run: `cd frontend && flutter test test/providers_test.dart`
Expected: PASS (2 passed).

- [ ] **Step 6: Commit**

```bash
git add frontend/lib/providers frontend/test/providers_test.dart
git commit -m "feat(frontend): providers de auth y datos (Riverpod)"
```

---

### Task 5: Router con redirect por auth

**Files:**
- Create: `frontend/lib/router.dart`
- Test: `frontend/test/router_test.dart`

**Interfaces:**
- Consumes: `isLoggedInProvider` (Task 4), pantallas (Login/Dashboard — se referencian; ver nota).
- Produces:
  - `authRedirect(bool loggedIn, String location) -> String?` (función pura: a dónde redirigir, o null).
  - `routerProvider` — `Provider<GoRouter>`.

- [ ] **Step 1: Escribir el test que falla**

Crear `frontend/test/router_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:preguntale_tu_plata/router.dart';

void main() {
  group('authRedirect', () {
    test('sin sesión en /dashboard -> /login', () {
      expect(authRedirect(false, '/dashboard'), '/login');
    });
    test('con sesión en /login -> /dashboard', () {
      expect(authRedirect(true, '/login'), '/dashboard');
    });
    test('sin sesión en /login -> no redirige', () {
      expect(authRedirect(false, '/login'), isNull);
    });
    test('con sesión en /dashboard -> no redirige', () {
      expect(authRedirect(true, '/dashboard'), isNull);
    });
  });
}
```

- [ ] **Step 2: Correr el test y verificar que falla**

Run: `cd frontend && flutter test test/router_test.dart`
Expected: FAIL — `router.dart` no existe.

- [ ] **Step 3: Crear router.dart**

Crear `frontend/lib/router.dart`. NOTA: importa pantallas que se crean en Tasks 6-8; si aún no existen al correr el test de este task, el test de la función pura `authRedirect` igual compila sólo si `router.dart` compila. Para evitar dependencia circular, este task crea `router.dart` con la función pura y un `routerProvider` que referencia `LoginScreen` y `DashboardScreen`; esas pantallas DEBEN existir como stubs mínimos. Crear primero los stubs:

Crear `frontend/lib/screens/login_screen.dart` (stub, se completa en Task 6):

```dart
import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Login')));
}
```

Crear `frontend/lib/screens/dashboard_screen.dart` (stub, se completa en Task 7):

```dart
import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Dashboard')));
}
```

Crear `frontend/lib/router.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

/// Función pura: dado el estado de sesión y la ubicación actual, devuelve la
/// ruta a la que redirigir, o null si no hay que redirigir.
String? authRedirect(bool loggedIn, String location) {
  final goingToLogin = location == '/login';
  if (!loggedIn && !goingToLogin) return '/login';
  if (loggedIn && goingToLogin) return '/dashboard';
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final loggedIn = ref.read(isLoggedInProvider);
      return authRedirect(loggedIn, state.matchedLocation);
    },
    refreshListenable: _AuthRefresh(ref),
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
    ],
  );
});

/// Hace que go_router reevalúe el redirect cuando cambia el estado de auth.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}
```

(Necesita `import 'package:flutter/foundation.dart';`? `ChangeNotifier` viene de `package:flutter/foundation.dart`; agregarlo al import si el analyzer lo pide.)

- [ ] **Step 4: Correr el test y verificar que pasa**

Run: `cd frontend && flutter test test/router_test.dart`
Expected: PASS (4 passed).

- [ ] **Step 5: Verificar que compila todo**

Run: `cd frontend && flutter analyze`
Expected: No errores (warnings de lint OK). Si `ChangeNotifier` no resuelve, agregar `import 'package:flutter/foundation.dart';` a `router.dart`.

- [ ] **Step 6: Commit**

```bash
git add frontend/lib/router.dart frontend/lib/screens/login_screen.dart frontend/lib/screens/dashboard_screen.dart frontend/test/router_test.dart
git commit -m "feat(frontend): go_router con redirect por auth (authRedirect puro + routerProvider)"
```

---

### Task 6: LoginScreen (email + password)

**Files:**
- Modify: `frontend/lib/screens/login_screen.dart` (reemplaza el stub)
- Test: `frontend/test/login_screen_test.dart`

**Interfaces:**
- Consumes: supabase_flutter (`signInWithPassword`, `signUp`). go_router redirige al entrar (vía authState).
- Produces: `LoginScreen` (ConsumerStatefulWidget) con modos Entrar/Registrarse.

- [ ] **Step 1: Escribir el test que falla (validación, sin tocar Supabase)**

Crear `frontend/test/login_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:preguntale_tu_plata/screens/login_screen.dart';

void main() {
  testWidgets('muestra error si el email es inválido', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: LoginScreen()),
    ));

    await tester.enterText(find.byKey(const Key('email')), 'no-es-email');
    await tester.enterText(find.byKey(const Key('password')), '123456');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pump();

    expect(find.text('Ingresa un email válido'), findsOneWidget);
  });

  testWidgets('muestra error si la contraseña es muy corta', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: LoginScreen()),
    ));

    await tester.enterText(find.byKey(const Key('email')), 'a@b.cl');
    await tester.enterText(find.byKey(const Key('password')), '123');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pump();

    expect(find.text('La contraseña debe tener al menos 6 caracteres'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Correr el test y verificar que falla**

Run: `cd frontend && flutter test test/login_screen_test.dart`
Expected: FAIL — el stub no tiene los campos `email`/`password`/`submit` ni la validación.

- [ ] **Step 3: Implementar LoginScreen**

Reemplazar `frontend/lib/screens/login_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registrando = false;
  bool _cargando = false;
  String? _error;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validar() {
    if (!_emailRe.hasMatch(_email.text.trim())) return 'Ingresa un email válido';
    if (_password.text.length < 6) return 'La contraseña debe tener al menos 6 caracteres';
    return null;
  }

  Future<void> _submit() async {
    final err = _validar();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _error = null;
      _cargando = true;
    });
    try {
      final auth = Supabase.instance.client.auth;
      if (_registrando) {
        await auth.signUp(email: _email.text.trim(), password: _password.text);
      } else {
        await auth.signInWithPassword(email: _email.text.trim(), password: _password.text);
      }
      // El redirect del router (authState) lleva al dashboard automáticamente.
    } on AuthException catch (e) {
      setState(() => _error = _traducir(e.message));
    } catch (_) {
      setState(() => _error = 'No se pudo conectar. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _traducir(String m) {
    final low = m.toLowerCase();
    if (low.contains('invalid login')) return 'Email o contraseña incorrectos';
    if (low.contains('already registered')) return 'Este email ya está registrado';
    if (low.contains('confirm')) return 'Revisa tu correo para confirmar la cuenta';
    return m;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Pregúntale a tu plata',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                const SizedBox(height: 24),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Entrar')),
                    ButtonSegment(value: true, label: Text('Registrarse')),
                  ],
                  selected: {_registrando},
                  onSelectionChanged: (s) => setState(() {
                    _registrando = s.first;
                    _error = null;
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('password'),
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Color(0xFFF85149))),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('submit'),
                  onPressed: _cargando ? null : _submit,
                  child: _cargando
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_registrando ? 'Crear cuenta' : 'Entrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Correr el test y verificar que pasa**

Run: `cd frontend && flutter test test/login_screen_test.dart`
Expected: PASS (2 passed). La validación corre antes de tocar Supabase, así que el test no necesita Supabase inicializado.

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/screens/login_screen.dart frontend/test/login_screen_test.dart
git commit -m "feat(frontend): LoginScreen email+password con validación y errores en español"
```

---

### Task 7: DashboardScreen + widgets

**Files:**
- Modify: `frontend/lib/screens/dashboard_screen.dart` (reemplaza el stub)
- Create: `frontend/lib/widgets/summary_card.dart`
- Create: `frontend/lib/widgets/transaction_tile.dart`
- Create: `frontend/lib/widgets/gastos_dona.dart`
- Test: `frontend/test/dashboard_screen_test.dart`

**Interfaces:**
- Consumes: `summaryProvider`, `transactionsProvider`, `apiProvider` (Task 4); `Summary`, `Transaction` (Task 2).
- Produces: `DashboardScreen` (ConsumerWidget) que rendea cards + dona + lista, con empty state y pull-to-refresh.

- [ ] **Step 1: Escribir el test que falla (con providers mockeados)**

Crear `frontend/test/dashboard_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:preguntale_tu_plata/screens/dashboard_screen.dart';
import 'package:preguntale_tu_plata/providers/data_providers.dart';
import 'package:preguntale_tu_plata/models/summary.dart';
import 'package:preguntale_tu_plata/models/transaction.dart';

void main() {
  testWidgets('rendea total de gastos y una transacción', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        summaryProvider.overrideWith((ref) async => const Summary(
              porMoneda: {'CLP': MonedaTotales(ingresos: 2500000, gastos: -89890)},
              gastosPorCategoria: [],
              gastosPorBanco: [BancoTotal(banco: 'BCI', total: -89890)],
            )),
        transactionsProvider.overrideWith((ref) async => const [
              Transaction(id: '1', fecha: '2025-06-01', descripcion: 'SUPERMERCADO LIDER',
                  monto: -45000, moneda: 'CLP', tarjeta: null, tipo: 'cargo',
                  categoria: null, banco: 'BCI', fuente: 'cartola'),
            ]),
      ],
      child: const MaterialApp(home: DashboardScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('89.890'), findsWidgets);
    expect(find.text('SUPERMERCADO LIDER'), findsOneWidget);
  });

  testWidgets('empty state cuando no hay transacciones', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        summaryProvider.overrideWith((ref) async => const Summary(
              porMoneda: {}, gastosPorCategoria: [], gastosPorBanco: [])),
        transactionsProvider.overrideWith((ref) async => const <Transaction>[]),
      ],
      child: const MaterialApp(home: DashboardScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sube tu primera cartola'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Correr el test y verificar que falla**

Run: `cd frontend && flutter test test/dashboard_screen_test.dart`
Expected: FAIL — el stub no rendea nada de eso.

- [ ] **Step 3: Crear los widgets**

Crear `frontend/lib/widgets/summary_card.dart`:

```dart
import 'package:flutter/material.dart';

class SummaryCard extends StatelessWidget {
  final String label;
  final String valor;
  final Color color;
  const SummaryCard({super.key, required this.label, required this.valor, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
          const SizedBox(height: 6),
          Text(valor, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
```

Crear `frontend/lib/widgets/transaction_tile.dart`:

```dart
import 'package:flutter/material.dart';
import '../models/transaction.dart';

class TransactionTile extends StatelessWidget {
  final Transaction t;
  const TransactionTile({super.key, required this.t});

  String _monto(double m) {
    final neg = m < 0;
    final abs = m.abs().toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (mm) => '${mm[1]}.');
    return '${neg ? '-' : '+'}\$$abs';
  }

  @override
  Widget build(BuildContext context) {
    final gasto = t.monto < 0;
    return ListTile(
      dense: true,
      title: Text(t.descripcion, style: const TextStyle(color: Color(0xFFE6EDF3))),
      subtitle: Text('${t.fecha} · ${t.banco}',
          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
      trailing: Text(_monto(t.monto),
          style: TextStyle(
              color: gasto ? const Color(0xFFF85149) : const Color(0xFF00C896),
              fontWeight: FontWeight.w600)),
    );
  }
}
```

Crear `frontend/lib/widgets/gastos_dona.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/summary.dart';

class GastosDona extends StatelessWidget {
  final List<BancoTotal> porBanco;
  const GastosDona({super.key, required this.porBanco});

  static const _colores = [
    Color(0xFF00C896), Color(0xFF1F6FEB), Color(0xFFF85149),
    Color(0xFFD29922), Color(0xFFA371F7),
  ];

  @override
  Widget build(BuildContext context) {
    if (porBanco.isEmpty) return const SizedBox.shrink();
    final total = porBanco.fold<double>(0, (a, b) => a + b.total.abs());
    return SizedBox(
      height: 180,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 50,
          sections: [
            for (var i = 0; i < porBanco.length; i++)
              PieChartSectionData(
                value: porBanco[i].total.abs(),
                color: _colores[i % _colores.length],
                title: total == 0
                    ? ''
                    : '${(porBanco[i].total.abs() / total * 100).toStringAsFixed(0)}%',
                radius: 40,
                titleStyle: const TextStyle(
                    fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Implementar DashboardScreen**

Reemplazar `frontend/lib/screens/dashboard_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/data_providers.dart';
import '../models/summary.dart';
import '../widgets/summary_card.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/gastos_dona.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _miles(double m) => m.abs().toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (mm) => '${mm[1]}.');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(summaryProvider);
    final txns = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Tu plata'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(summaryProvider);
          ref.invalidate(transactionsProvider);
          await ref.read(transactionsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            summary.when(
              loading: () => const Center(child: Padding(
                  padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              error: (e, _) => _ErrorBox(msg: 'No se pudo cargar el resumen',
                  onRetry: () => ref.invalidate(summaryProvider)),
              data: (s) => _Resumen(s: s, miles: _miles),
            ),
            const SizedBox(height: 20),
            const Text('Movimientos',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            txns.when(
              loading: () => const Center(child: Padding(
                  padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              error: (e, _) => _ErrorBox(msg: 'No se pudieron cargar los movimientos',
                  onRetry: () => ref.invalidate(transactionsProvider)),
              data: (list) => list.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('Sube tu primera cartola para empezar',
                          style: TextStyle(color: Color(0xFF8B949E)))))
                  : Column(children: [for (final t in list) TransactionTile(t: t)]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  final Summary s;
  final String Function(double) miles;
  const _Resumen({required this.s, required this.miles});

  @override
  Widget build(BuildContext context) {
    final clp = s.porMoneda['CLP'];
    final gastos = clp?.gastos ?? 0;
    final ingresos = clp?.ingresos ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: SummaryCard(
                label: 'Gastos', valor: '\$${miles(gastos)}', color: const Color(0xFFF85149))),
            const SizedBox(width: 12),
            Expanded(child: SummaryCard(
                label: 'Ingresos', valor: '\$${miles(ingresos)}', color: const Color(0xFF00C896))),
          ],
        ),
        const SizedBox(height: 16),
        GastosDona(porBanco: s.gastosPorBanco),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _ErrorBox({required this.msg, required this.onRetry});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Text(msg, style: const TextStyle(color: Color(0xFF8B949E))),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ]),
      );
}
```

- [ ] **Step 5: Correr el test y verificar que pasa**

Run: `cd frontend && flutter test test/dashboard_screen_test.dart`
Expected: PASS (2 passed).

- [ ] **Step 6: Commit**

```bash
git add frontend/lib/screens/dashboard_screen.dart frontend/lib/widgets frontend/test/dashboard_screen_test.dart
git commit -m "feat(frontend): DashboardScreen con cards, dona por banco, lista y empty state"
```

---

### Task 8: Wire main.dart + chat/upload detrás de auth

**Files:**
- Modify: `frontend/lib/main.dart`
- Create: `frontend/lib/screens/chat_screen.dart`
- Create: `frontend/lib/screens/upload_screen.dart`
- Modify: `frontend/lib/screens/dashboard_screen.dart` (botones a chat/upload)
- Modify: `frontend/lib/router.dart` (rutas /chat y /upload)
- Delete: `frontend/lib/screens/home_screen.dart`, `frontend/lib/widgets/upload_card.dart` (lógica vieja sin auth)
- Test: `frontend/test/smoke_test.dart`

**Interfaces:**
- Consumes: `routerProvider` (Task 5), `apiProvider` (Task 4), `Config` (Task 1).
- Produces: app booteada con Supabase + Riverpod + go_router; `ChatScreen` y `UploadScreen` conectadas al backend con JWT.

- [ ] **Step 1: Reescribir main.dart**

Reemplazar `frontend/lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: Config.supabaseUrl,
    anonKey: Config.supabaseAnonKey,
  );
  runApp(const ProviderScope(child: PreguntaleApp()));
}

class PreguntaleApp extends ConsumerWidget {
  const PreguntaleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Pregúntale a tu plata',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          surface: Color(0xFF161B22),
          primary: Color(0xFF00C896),
          onPrimary: Color(0xFF0D1117),
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
```

- [ ] **Step 2: Crear UploadScreen (con JWT)**

Crear `frontend/lib/screens/upload_screen.dart`:

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
  String _banco = 'bci';
  bool _cargando = false;
  String? _msg;

  Future<void> _subir() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['csv'], withData: true);
    if (res == null || res.files.single.bytes == null) return;
    setState(() { _cargando = true; _msg = null; });
    try {
      final r = await ref.read(apiProvider).uploadCsv(
          res.files.single.bytes!, res.files.single.name, _banco);
      ref.invalidate(summaryProvider);
      ref.invalidate(transactionsProvider);
      setState(() => _msg = '${r.count} transacciones cargadas');
    } on ApiException catch (e) {
      setState(() => _msg = e.message);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subir cartola')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _banco,
              decoration: const InputDecoration(labelText: 'Banco'),
              items: const [
                DropdownMenuItem(value: 'bci', child: Text('BCI')),
                DropdownMenuItem(value: 'santander', child: Text('Santander')),
                DropdownMenuItem(value: 'bancoestado', child: Text('BancoEstado')),
              ],
              onChanged: (v) => setState(() => _banco = v ?? 'bci'),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _cargando ? null : _subir,
              icon: const Icon(Icons.upload_file),
              label: Text(_cargando ? 'Subiendo...' : 'Elegir CSV'),
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

- [ ] **Step 3: Crear ChatScreen (con JWT)**

Crear `frontend/lib/screens/chat_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/data_providers.dart';
import '../services/api_service.dart';

class _Msg {
  final String text;
  final bool user;
  _Msg(this.text, this.user);
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _msgs = <_Msg>[];
  bool _cargando = false;

  Future<void> _enviar() async {
    final q = _input.text.trim();
    if (q.isEmpty || _cargando) return;
    setState(() { _msgs.add(_Msg(q, true)); _cargando = true; });
    _input.clear();
    try {
      final r = await ref.read(apiProvider).ask(q);
      setState(() => _msgs.add(_Msg(r.answer, false)));
    } on ApiException catch (e) {
      setState(() => _msgs.add(_Msg(e.message, false)));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pregúntale a tu plata')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _msgs.length,
              itemBuilder: (_, i) {
                final m = _msgs[i];
                return Align(
                  alignment: m.user ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: m.user ? const Color(0xFF1F6FEB) : const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(m.text, style: const TextStyle(color: Color(0xFFE6EDF3))),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(child: TextField(
                controller: _input,
                onSubmitted: (_) => _enviar(),
                decoration: const InputDecoration(hintText: '¿Cuánto gasté este mes?'),
              )),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _cargando ? null : _enviar,
                icon: _cargando
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Agregar rutas /chat y /upload al router**

En `frontend/lib/router.dart`, agregar los imports y las rutas dentro de `routes: [...]`:

```dart
import 'screens/chat_screen.dart';
import 'screens/upload_screen.dart';
```

Y dentro de la lista `routes`, después de la ruta `/dashboard`:

```dart
      GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),
      GoRoute(path: '/upload', builder: (_, __) => const UploadScreen()),
```

Como `/chat` y `/upload` no son `/login`, el `authRedirect` ya los protege (sin sesión → `/login`).

- [ ] **Step 5: Botones del dashboard a chat/upload**

En `frontend/lib/screens/dashboard_screen.dart`, agregar `import 'package:go_router/go_router.dart';` y un `floatingActionButton` al `Scaffold` (después del `body:`):

```dart
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'subir',
            onPressed: () => context.push('/upload'),
            icon: const Icon(Icons.upload_file),
            label: const Text('Subir'),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: 'preguntar',
            onPressed: () => context.push('/chat'),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Preguntar'),
          ),
        ],
      ),
```

- [ ] **Step 6: Borrar los archivos viejos sin auth**

```bash
git rm frontend/lib/screens/home_screen.dart frontend/lib/widgets/upload_card.dart
```

(`home_screen.dart` y `upload_card.dart` eran la versión sin login/JWT; `message_bubble.dart` se conserva por si se reusa, pero si `flutter analyze` lo marca como no usado, borrarlo también con `git rm`.)

- [ ] **Step 7: Smoke test — la app compila y el login aparece sin sesión**

Crear `frontend/test/smoke_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:preguntale_tu_plata/router.dart';
import 'package:preguntale_tu_plata/providers/auth_provider.dart';

void main() {
  testWidgets('sin sesión arranca en el login', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [isLoggedInProvider.overrideWithValue(false)],
      child: Consumer(builder: (context, ref, _) {
        return MaterialApp.router(routerConfig: ref.watch(routerProvider));
      }),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Entrar'), findsWidgets);
  });
}
```

NOTA: este smoke test overridea `isLoggedInProvider` para no requerir `Supabase.initialize`. El `routerProvider` usa `ref.read(isLoggedInProvider)` en el redirect, que toma el override.

- [ ] **Step 8: Correr el test y verificar que pasa**

Run: `cd frontend && flutter test test/smoke_test.dart`
Expected: PASS. Si falla porque `authStateProvider` (usado por `_AuthRefresh`) toca Supabase, en el smoke test añadir también `authStateProvider.overrideWith((ref) => const Stream.empty())` al `overrides`.

- [ ] **Step 9: Verificar toda la suite + analyze**

Run: `cd frontend && flutter test`
Expected: todos los tests pasan (config, models, api_service, providers, router, login, dashboard, smoke).

Run: `cd frontend && flutter analyze`
Expected: sin errores.

- [ ] **Step 10: Commit**

```bash
git add frontend/lib frontend/test
git commit -m "feat(frontend): wire app (Supabase+Riverpod+go_router), chat/upload con JWT detrás de auth"
```

---

## Verificación manual final (web)

1. Levantar el backend: `cd backend && .\.venv\Scripts\uvicorn app.main:app --port 8000`
2. Correr la app: `cd frontend && flutter run -d chrome --web-port 3000`
3. Registrarse o entrar con el usuario de prueba → debe redirigir al Dashboard.
4. Tocar **Subir** → elegir un CSV BCI → vuelve y el dashboard muestra los montos.
5. Tocar **Preguntar** → preguntar "¿cuánto gasté?" → respuesta del RAG.
6. Logout → vuelve al login.

> CORS: el backend ya tiene `allow_origins=["*"]`, así que la app web en `localhost:3000`
> puede llamar a `localhost:8000` sin problema.

## Notas para planes siguientes

- **Plan 3 (fotos):** agrega `receipt_screen.dart` (image_picker cámara/galería) + endpoints
  `upload-receipt`/`confirm-receipt` en el backend.
- **Plan 4 (categorización):** la dona del dashboard pasa de `gastos_por_banco` a
  `gastos_por_categoria` (ya viene en el summary, hoy vacío).
