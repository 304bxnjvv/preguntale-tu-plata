import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:preguntale_tu_plata/services/api_service.dart';
import 'package:preguntale_tu_plata/providers/data_providers.dart';

void main() {
  // ── Alerta.fromJson ──────────────────────────────────────────────────────────

  group('Alerta.fromJson', () {
    test('parsea todos los campos urgent', () {
      final a = Alerta.fromJson({
        'key': 'tarjeta_vence:2026-06-28',
        'tipo': 'tarjeta_vence',
        'severidad': 'urgent',
        'titulo': 'Tu tarjeta vence en 3 días',
        'detalle': 'Tienes \$200.000 por pagar',
        'fecha': '2026-06-25',
      });
      expect(a.key, 'tarjeta_vence:2026-06-28');
      expect(a.tipo, 'tarjeta_vence');
      expect(a.severidad, 'urgent');
      expect(a.titulo, 'Tu tarjeta vence en 3 días');
      expect(a.detalle, 'Tienes \$200.000 por pagar');
      expect(a.fecha, '2026-06-25');
    });

    test('parsea alerta warning de presupuesto', () {
      final a = Alerta.fromJson({
        'key': 'presupuesto:Compras',
        'tipo': 'presupuesto',
        'severidad': 'warning',
        'titulo': 'Presupuesto Compras cerca del tope',
        'detalle': 'Has gastado el 90%',
        'fecha': '2026-06-25',
      });
      expect(a.tipo, 'presupuesto');
      expect(a.severidad, 'warning');
    });

    test('parsea alerta info de gasto inusual', () {
      final a = Alerta.fromJson({
        'key': 'gasto:abc-123',
        'tipo': 'gasto_inusual',
        'severidad': 'info',
        'titulo': 'Gasto inusual detectado',
        'detalle': 'Compraste por \$800.000',
        'fecha': '2026-06-24',
      });
      expect(a.tipo, 'gasto_inusual');
      expect(a.severidad, 'info');
    });
  });

  // ── ApiService.getAlertas ────────────────────────────────────────────────────

  group('ApiService.getAlertas', () {
    final sampleItems = [
      {
        'key': 'tarjeta_vence:2026-06-28',
        'tipo': 'tarjeta_vence',
        'severidad': 'urgent',
        'titulo': 'Tu tarjeta vence en 3 días',
        'detalle': 'Tienes \$200.000 por pagar',
        'fecha': '2026-06-25',
      },
      {
        'key': 'presupuesto:Compras',
        'tipo': 'presupuesto',
        'severidad': 'warning',
        'titulo': 'Presupuesto Compras cerca del tope',
        'detalle': 'Has gastado el 90%',
        'fecha': '2026-06-25',
      },
    ];

    test('GET /insights/alertas retorna lista parseada', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({'items': sampleItems}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final api = ApiService(client: mock, token: () => 'TOK', baseUrl: 'http://x/api/v1');
      final list = await api.getAlertas();

      expect(captured.headers['Authorization'], 'Bearer TOK');
      expect(captured.url.path, endsWith('/insights/alertas'));
      expect(list.length, 2);
      expect(list.first.tipo, 'tarjeta_vence');
      expect(list.first.severidad, 'urgent');
    });

    test('lanza ApiException en error 401', () async {
      final mock = MockClient((req) async => http.Response('Unauthorized', 401));
      final api = ApiService(client: mock, token: () => 't', baseUrl: 'http://x/api/v1');
      expect(() => api.getAlertas(), throwsA(isA<ApiException>()));
    });
  });

  // ── alertasProvider ──────────────────────────────────────────────────────────

  group('alertasProvider', () {
    test('lee lista de alertas desde apiProvider', () async {
      final mock = MockClient((_) async => http.Response(
            jsonEncode({
              'items': [
                {
                  'key': 'cuotas_proximo_mes',
                  'tipo': 'cuotas_proximo_mes',
                  'severidad': 'warning',
                  'titulo': 'Cuotas el próximo mes',
                  'detalle': 'Tienes \$50.000 comprometidos',
                  'fecha': '2026-06-25',
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));
      final api = ApiService(client: mock, token: () => 'T', baseUrl: 'http://x/api/v1');
      final container = ProviderContainer(overrides: [apiProvider.overrideWithValue(api)]);
      addTearDown(container.dispose);

      final list = await container.read(alertasProvider.future);
      expect(list.first.tipo, 'cuotas_proximo_mes');
    });
  });
}
