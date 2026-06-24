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
          jsonEncode({
            'answer': 'Gastaste 45000',
            'citations': [{'fecha': '2025-06-01', 'descripcion': 'LIDER', 'monto': -45000.0}],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ));
    final api = ApiService(client: mock, token: () => 't', baseUrl: 'http://x/api/v1');
    final r = await api.ask('cuanto gaste');
    expect(r.answer, 'Gastaste 45000');
    expect(r.citations.single.monto, -45000.0);
  });
}
