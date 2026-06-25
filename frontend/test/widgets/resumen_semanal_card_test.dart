import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:preguntale_tu_plata/widgets/resumen_semanal_card.dart';
import 'package:preguntale_tu_plata/providers/data_providers.dart';
import 'package:preguntale_tu_plata/services/api_service.dart';
import 'package:preguntale_tu_plata/services/resumen_seen.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────

Map<String, dynamic> _sampleJson({bool tieneDatos = true}) => {
      'tiene_datos': tieneDatos,
      'periodo': '2026-06-18..2026-06-25',
      'gasto_semana': 25000.0,
      'top_categoria': 'Comida y delivery',
      'top_monto': 20000.0,
      'delta_pct': 100.0,
      'texto': 'Esta semana se te fueron \$25.000. Lo más fuerte fue Comida y delivery (\$20.000). Gastaste un 100% más que la semana pasada, ojo 👀.',
    };

// ── Model tests ────────────────────────────────────────────────────────────────

void main() {
  group('ResumenSemanal.fromJson', () {
    test('parsea todos los campos cuando tiene_datos == true', () {
      final r = ResumenSemanal.fromJson(_sampleJson());
      expect(r.tieneDatos, isTrue);
      expect(r.periodo, '2026-06-18..2026-06-25');
      expect(r.gastoSemana, 25000.0);
      expect(r.topCategoria, 'Comida y delivery');
      expect(r.topMonto, 20000.0);
      expect(r.deltaPct, 100.0);
      expect(r.texto, contains('25.000'));
    });

    test('parsea campos opcionales nulos', () {
      final data = _sampleJson();
      data['top_categoria'] = null;
      data['delta_pct'] = null;
      final r = ResumenSemanal.fromJson(data);
      expect(r.topCategoria, isNull);
      expect(r.deltaPct, isNull);
    });

    test('parsea tiene_datos == false', () {
      final r = ResumenSemanal.fromJson({
        'tiene_datos': false,
        'periodo': '2026-06-18..2026-06-25',
        'gasto_semana': 0.0,
        'top_categoria': null,
        'top_monto': 0.0,
        'delta_pct': null,
        'texto': '',
      });
      expect(r.tieneDatos, isFalse);
      expect(r.gastoSemana, 0.0);
    });
  });

  // ── ResumenSeen ────────────────────────────────────────────────────────────────

  group('ResumenSeen', () {
    test('debeMostrar() true cuando now >> ultima vista (>=7 días)', () async {
      final seen = ResumenSeen();
      final now = DateTime(2026, 6, 25, 12);
      // Simulate last seen 8 days ago
      final lastSeen = now.subtract(const Duration(days: 8));
      expect(await seen.debeMostrar(now: now, lastSeenOverride: lastSeen.millisecondsSinceEpoch), isTrue);
    });

    test('debeMostrar() false si se vio hace <7 días', () async {
      final seen = ResumenSeen();
      final now = DateTime(2026, 6, 25, 12);
      final lastSeen = now.subtract(const Duration(days: 3));
      expect(await seen.debeMostrar(now: now, lastSeenOverride: lastSeen.millisecondsSinceEpoch), isFalse);
    });

    test('debeMostrar() true si nunca se mostró (lastSeenOverride = 0 = epoch)', () async {
      final seen = ResumenSeen();
      final now = DateTime(2026, 6, 25, 12);
      // 0 ms desde epoch significa que no hay registro; siempre es >=7 días atrás
      expect(await seen.debeMostrar(now: now, lastSeenOverride: 0), isTrue);
    });
  });

  // ── API method ────────────────────────────────────────────────────────────────

  group('ApiService.getResumenSemanal', () {
    test('manda Bearer token, ruta correcta y parsea respuesta', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode(_sampleJson()),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final api = ApiService(client: mock, token: () => 'MYTOKEN', baseUrl: 'http://x/api/v1');
      final r = await api.getResumenSemanal();

      expect(captured.headers['Authorization'], 'Bearer MYTOKEN');
      expect(captured.url.path, endsWith('/insights/resumen-semanal'));
      expect(r.gastoSemana, 25000.0);
      expect(r.tieneDatos, isTrue);
    });

    test('lanza ApiException en error 401', () async {
      final mock = MockClient((req) async => http.Response('Unauthorized', 401));
      final api = ApiService(client: mock, token: () => 't', baseUrl: 'http://x/api/v1');
      expect(() => api.getResumenSemanal(), throwsA(isA<ApiException>()));
    });
  });

  // ── Widget tests ──────────────────────────────────────────────────────────────

  group('ResumenSemanalCard widget', () {
    Widget wrap(ResumenSemanal data, {bool debeMostrar = true}) {
      return ProviderScope(
        overrides: [
          resumenSemanalProvider.overrideWith((ref) async => data),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ResumenSemanalCard(
              seenOverride: _FakeResumenSeen(debeMostrar: debeMostrar),
            ),
          ),
        ),
      );
    }

    testWidgets('muestra texto del resumen cuando tiene_datos == true y debe mostrar', (tester) async {
      final r = ResumenSemanal.fromJson(_sampleJson());
      await tester.pumpWidget(wrap(r));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('25.000'), findsWidgets);
      expect(find.text('ya lo vi'), findsOneWidget);
    });

    testWidgets('se oculta cuando tiene_datos == false', (tester) async {
      final r = ResumenSemanal.fromJson({
        'tiene_datos': false,
        'periodo': '2026-06-18..2026-06-25',
        'gasto_semana': 0.0,
        'top_categoria': null,
        'top_monto': 0.0,
        'delta_pct': null,
        'texto': '',
      });
      await tester.pumpWidget(wrap(r));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('ya lo vi'), findsNothing);
      expect(find.textContaining('semana'), findsNothing);
    });

    testWidgets('se oculta cuando debeMostrar es false', (tester) async {
      final r = ResumenSemanal.fromJson(_sampleJson());
      await tester.pumpWidget(wrap(r, debeMostrar: false));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('ya lo vi'), findsNothing);
    });

    testWidgets('tap ya lo vi oculta la card y llama marcarVisto', (tester) async {
      final r = ResumenSemanal.fromJson(_sampleJson());
      var marcarVistoCalled = false;
      final fakeSeen = _FakeResumenSeen(
        debeMostrar: true,
        onMarcarVisto: () => marcarVistoCalled = true,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            resumenSemanalProvider.overrideWith((ref) async => r),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ResumenSemanalCard(seenOverride: fakeSeen),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Card is visible
      expect(find.text('ya lo vi'), findsOneWidget);

      // Tap the button
      await tester.tap(find.text('ya lo vi'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(marcarVistoCalled, isTrue);
      // Card should now be hidden
      expect(find.text('ya lo vi'), findsNothing);
    });
  });
}

// ── Fake seen for testing ─────────────────────────────────────────────────────

class _FakeResumenSeen implements ResumenSeen {
  final bool _debeMostrar;
  final VoidCallback? onMarcarVisto;

  _FakeResumenSeen({required bool debeMostrar, this.onMarcarVisto})
      : _debeMostrar = debeMostrar;

  @override
  Future<bool> debeMostrar({DateTime? now, int? lastSeenOverride}) async => _debeMostrar;

  @override
  Future<void> marcarVisto({DateTime? now}) async {
    onMarcarVisto?.call();
  }
}
