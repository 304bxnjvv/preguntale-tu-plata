import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:preguntale_tu_plata/services/api_service.dart';
import 'package:preguntale_tu_plata/providers/data_providers.dart';
import 'package:preguntale_tu_plata/widgets/tarjeta_card.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────

Map<String, dynamic> _sampleJson({bool tieneDatos = true}) => {
      'tiene_datos': tieneDatos,
      'total_a_pagar': 250000.0,
      'monto_minimo': 50000.0,
      'fecha_vencimiento': '2026-07-10',
      'cupo_total': 1000000.0,
      'cupo_utilizado': 400000.0,
      'comprometido_proximo_mes': 180000.0,
      'cuotas': [
        {
          'descripcion': 'Notebook Dell',
          'valor_cuota': 45000.0,
          'cuotas_restantes': 8,
        }
      ],
    };

// ── Model tests ────────────────────────────────────────────────────────────────

void main() {
  group('TarjetaEstado.fromJson', () {
    test('parsea todos los campos cuando tiene_datos == true', () {
      final t = TarjetaEstado.fromJson(_sampleJson());
      expect(t.tieneDatos, isTrue);
      expect(t.totalAPagar, 250000.0);
      expect(t.montoMinimo, 50000.0);
      expect(t.fechaVencimiento, '2026-07-10');
      expect(t.cupoTotal, 1000000.0);
      expect(t.cupoUtilizado, 400000.0);
      expect(t.comprometidoProximoMes, 180000.0);
      expect(t.cuotas.length, 1);
      expect(t.cuotas.first.descripcion, 'Notebook Dell');
      expect(t.cuotas.first.valorCuota, 45000.0);
      expect(t.cuotas.first.cuotasRestantes, 8);
    });

    test('parsea tiene_datos == false sin cuotas', () {
      final t = TarjetaEstado.fromJson({
        'tiene_datos': false,
        'total_a_pagar': 0,
        'monto_minimo': 0,
        'fecha_vencimiento': null,
        'cupo_total': 0,
        'cupo_utilizado': 0,
        'comprometido_proximo_mes': 0,
        'cuotas': [],
      });
      expect(t.tieneDatos, isFalse);
      expect(t.cuotas, isEmpty);
      expect(t.fechaVencimiento, isNull);
    });

    test('parsea fechaVencimiento null sin error', () {
      final data = _sampleJson();
      data['fecha_vencimiento'] = null;
      final t = TarjetaEstado.fromJson(data);
      expect(t.fechaVencimiento, isNull);
    });
  });

  // ── API method ────────────────────────────────────────────────────────────────

  group('ApiService.getTarjeta', () {
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
      final t = await api.getTarjeta();

      expect(captured.headers['Authorization'], 'Bearer MYTOKEN');
      expect(captured.url.path, endsWith('/insights/tarjeta'));
      expect(t.totalAPagar, 250000.0);
      expect(t.tieneDatos, isTrue);
      expect(t.cuotas.first.descripcion, 'Notebook Dell');
    });

    test('lanza ApiException en error 401', () async {
      final mock = MockClient((req) async => http.Response('Unauthorized', 401));
      final api = ApiService(client: mock, token: () => 't', baseUrl: 'http://x/api/v1');
      expect(() => api.getTarjeta(), throwsA(isA<ApiException>()));
    });

    test('lanza ApiException en error 500', () async {
      final mock = MockClient((req) async => http.Response('Error', 500));
      final api = ApiService(client: mock, token: () => 't', baseUrl: 'http://x/api/v1');
      expect(() => api.getTarjeta(), throwsA(isA<ApiException>()));
    });
  });

  // ── Widget tests ──────────────────────────────────────────────────────────────

  group('TarjetaCard widget', () {
    Widget wrap(TarjetaEstado data) => ProviderScope(
          overrides: [
            tarjetaProvider.overrideWith((ref) async => data),
          ],
          child: const MaterialApp(
            home: Scaffold(body: TarjetaCard()),
          ),
        );

    testWidgets('muestra total a pagar cuando tiene_datos == true', (tester) async {
      final t = TarjetaEstado.fromJson(_sampleJson());
      await tester.pumpWidget(wrap(t));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // \$250.000 formateado
      expect(find.textContaining('250.000'), findsWidgets);
    });

    testWidgets('muestra comprometido próximo mes', (tester) async {
      final t = TarjetaEstado.fromJson(_sampleJson());
      await tester.pumpWidget(wrap(t));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('180.000'), findsWidgets);
      expect(find.textContaining('próximo mes'), findsOneWidget);
    });

    testWidgets('muestra fecha formateada dd/mm', (tester) async {
      final t = TarjetaEstado.fromJson(_sampleJson());
      await tester.pumpWidget(wrap(t));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('10/07'), findsOneWidget);
    });

    testWidgets('se oculta cuando tiene_datos == false', (tester) async {
      final t = TarjetaEstado.fromJson(_sampleJson(tieneDatos: false));
      await tester.pumpWidget(wrap(t));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('tarjeta'), findsNothing);
      expect(find.textContaining('250.000'), findsNothing);
    });

    testWidgets('muestra label cupo usado cuando cupoTotal > 0', (tester) async {
      final t = TarjetaEstado.fromJson(_sampleJson());
      await tester.pumpWidget(wrap(t));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('cupo usado'), findsOneWidget);
    });
  });
}
