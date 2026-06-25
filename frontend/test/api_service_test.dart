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

  test('getSummary con dias y tipo agrega query params correctos', () async {
    late http.Request captured;
    final mock = MockClient((req) async {
      captured = req;
      return http.Response(
        jsonEncode({
          'por_moneda': {},
          'gastos_por_categoria': [],
          'gastos_por_banco': [],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = ApiService(client: mock, token: () => 't', baseUrl: 'http://x/api/v1');

    await api.getSummary(dias: 7, tipo: 'gasto');

    expect(captured.url.queryParameters['dias'], '7');
    expect(captured.url.queryParameters['tipo'], 'gasto');
  });

  test('getSummary sin params no agrega query string', () async {
    late http.Request captured;
    final mock = MockClient((req) async {
      captured = req;
      return http.Response(
        jsonEncode({
          'por_moneda': {},
          'gastos_por_categoria': [],
          'gastos_por_banco': [],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = ApiService(client: mock, token: () => 't', baseUrl: 'http://x/api/v1');

    await api.getSummary();

    expect(captured.url.queryParameters, isEmpty);
  });

  test('getTransactions parsea lista', () async {
    final mock = MockClient((req) async => http.Response(
          jsonEncode([
            {
              'id': '1',
              'fecha': '2025-06-01',
              'descripcion': 'LIDER',
              'monto': -45000.0,
              'moneda': 'CLP',
              'tarjeta': null,
              'tipo': 'cargo',
              'categoria': null,
              'banco': 'BCI',
              'fuente': 'cartola'
            }
          ]),
          200,
          headers: {'content-type': 'application/json'},
        ));
    final api = ApiService(client: mock, token: () => 't', baseUrl: 'http://x/api/v1');
    final list = await api.getTransactions();
    expect(list.length, 1);
    expect(list.first.descripcion, 'LIDER');
  });

  test('getTransactions con filtros agrega query params', () async {
    late http.Request captured;
    final mock = MockClient((req) async {
      captured = req;
      return http.Response(jsonEncode([]), 200,
          headers: {'content-type': 'application/json'});
    });
    final api = ApiService(client: mock, token: () => 't', baseUrl: 'http://x/api/v1');

    await api.getTransactions(dias: 15, tipo: 'ingreso');

    expect(captured.url.queryParameters['dias'], '15');
    expect(captured.url.queryParameters['tipo'], 'ingreso');
  });

  test('ask parsea answer y citations', () async {
    final mock = MockClient((req) async => http.Response(
          jsonEncode({
            'answer': 'Gastaste 45000',
            'citations': [
              {'fecha': '2025-06-01', 'descripcion': 'LIDER', 'monto': -45000.0}
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ));
    final api = ApiService(client: mock, token: () => 't', baseUrl: 'http://x/api/v1');
    final r = await api.ask('cuanto gaste');
    expect(r.answer, 'Gastaste 45000');
    expect(r.citations.single.monto, -45000.0);
  });

  test('getChatHistory parsea array de mensajes', () async {
    late http.Request captured;
    final mock = MockClient((req) async {
      captured = req;
      return http.Response(
        jsonEncode([
          {
            'id': 'u1',
            'role': 'user',
            'content': 'cuanto gaste',
            'created_at': '2025-06-01T10:00:00Z'
          },
          {
            'id': 'a1',
            'role': 'assistant',
            'content': 'Gastaste 45000',
            'created_at': '2025-06-01T10:00:01Z'
          },
        ]),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = ApiService(client: mock, token: () => 'TOKEN123', baseUrl: 'http://x/api/v1');

    final history = await api.getChatHistory();

    expect(captured.headers['Authorization'], 'Bearer TOKEN123');
    expect(captured.url.path, endsWith('/chat/history'));
    expect(history.length, 2);
    expect(history[0].role, 'user');
    expect(history[0].content, 'cuanto gaste');
    expect(history[1].role, 'assistant');
    expect(history[1].content, 'Gastaste 45000');
  });

  test('getChatHistory lanza ApiException en error', () async {
    final mock = MockClient((req) async => http.Response('Unauthorized', 401));
    final api = ApiService(client: mock, token: () => 't', baseUrl: 'http://x/api/v1');
    expect(() => api.getChatHistory(), throwsA(isA<ApiException>()));
  });
}
