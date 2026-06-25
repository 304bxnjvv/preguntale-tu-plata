import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:preguntale_tu_plata/models/insights.dart';
import 'package:preguntale_tu_plata/services/api_service.dart';

void main() {
  // ── Model parse ────────────────────────────────────────────────────────────

  test('Suscripciones.fromJson parsea total_mensual e items', () {
    final s = Suscripciones.fromJson({
      'total_mensual': 42990.0,
      'items': [
        {'descripcion': 'netflix', 'monto': 12990.0, 'categoria': 'Entretenimiento'},
        {'descripcion': 'spotify', 'monto': 5990.0, 'categoria': 'Entretenimiento'},
      ],
    });
    expect(s.totalMensual, 42990.0);
    expect(s.items.length, 2);
    expect(s.items.first.descripcion, 'netflix');
    expect(s.items.first.monto, 12990.0);
    expect(s.items.first.categoria, 'Entretenimiento');
  });

  test('Suscripciones.fromJson con lista vacía', () {
    final s = Suscripciones.fromJson({'total_mensual': 0.0, 'items': []});
    expect(s.totalMensual, 0.0);
    expect(s.items, isEmpty);
  });

  test('Comparativo.fromJson parsea todos los campos', () {
    final c = Comparativo.fromJson({
      'mes_actual': '2025-06',
      'mes_anterior': '2025-05',
      'gastos_actual': 500000.0,
      'gastos_anterior': 420000.0,
      'delta': 80000.0,
      'top_cambios': [],
    });
    expect(c.mesActual, '2025-06');
    expect(c.mesAnterior, '2025-05');
    expect(c.gastosActual, 500000.0);
    expect(c.gastosAnterior, 420000.0);
    expect(c.delta, 80000.0);
  });

  // ── API methods ────────────────────────────────────────────────────────────

  test('getSuscripciones parsea respuesta correctamente', () async {
    final mock = MockClient((req) async => http.Response(
          jsonEncode({
            'total_mensual': 18990.0,
            'items': [
              {'descripcion': 'netflix', 'monto': 12990.0, 'categoria': 'Entretenimiento'},
              {'descripcion': 'spotify', 'monto': 5990.0, 'categoria': 'Musica'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ));
    final api = ApiService(client: mock, token: () => 'TOKEN', baseUrl: 'http://x/api/v1');
    final s = await api.getSuscripciones();
    expect(s.totalMensual, 18990.0);
    expect(s.items.length, 2);
    expect(s.items[1].descripcion, 'spotify');
  });

  test('getSuscripciones manda Bearer token y ruta correcta', () async {
    late http.Request captured;
    final mock = MockClient((req) async {
      captured = req;
      return http.Response(
        jsonEncode({'total_mensual': 0.0, 'items': []}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = ApiService(client: mock, token: () => 'MYTOKEN', baseUrl: 'http://x/api/v1');
    await api.getSuscripciones();
    expect(captured.headers['Authorization'], 'Bearer MYTOKEN');
    expect(captured.url.path, endsWith('/insights/suscripciones'));
  });

  test('getSuscripciones lanza ApiException en error', () async {
    final mock = MockClient((req) async => http.Response('Unauthorized', 401));
    final api = ApiService(client: mock, token: () => 't', baseUrl: 'http://x/api/v1');
    expect(() => api.getSuscripciones(), throwsA(isA<ApiException>()));
  });

  test('getComparativo parsea respuesta correctamente', () async {
    final mock = MockClient((req) async => http.Response(
          jsonEncode({
            'mes_actual': '2025-06',
            'mes_anterior': '2025-05',
            'gastos_actual': 600000.0,
            'gastos_anterior': 500000.0,
            'delta': 100000.0,
            'top_cambios': [
              {'categoria': 'Alimentacion', 'delta': 60000.0}
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ));
    final api = ApiService(client: mock, token: () => 't', baseUrl: 'http://x/api/v1');
    final c = await api.getComparativo();
    expect(c.mesActual, '2025-06');
    expect(c.delta, 100000.0);
    expect(c.gastosAnterior, 500000.0);
  });

  test('getComparativo manda Bearer token y ruta correcta', () async {
    late http.Request captured;
    final mock = MockClient((req) async {
      captured = req;
      return http.Response(
        jsonEncode({
          'mes_actual': '2025-06',
          'mes_anterior': '2025-05',
          'gastos_actual': 0.0,
          'gastos_anterior': 0.0,
          'delta': 0.0,
          'top_cambios': [],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = ApiService(client: mock, token: () => 'MYTOKEN', baseUrl: 'http://x/api/v1');
    await api.getComparativo();
    expect(captured.headers['Authorization'], 'Bearer MYTOKEN');
    expect(captured.url.path, endsWith('/insights/comparativo'));
  });

  test('getComparativo lanza ApiException en error', () async {
    final mock = MockClient((req) async => http.Response('Error', 500));
    final api = ApiService(client: mock, token: () => 't', baseUrl: 'http://x/api/v1');
    expect(() => api.getComparativo(), throwsA(isA<ApiException>()));
  });
}
