import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:preguntale_tu_plata/models/boleta_draft.dart';
import 'package:preguntale_tu_plata/services/api_service.dart';

void main() {
  // ── BoletaDraft.fromJson ─────────────────────────────────────────────────────

  group('BoletaDraft.fromJson', () {
    test('parsea todos los campos', () {
      final d = BoletaDraft.fromJson({
        'comercio': 'LIDER',
        'monto': -12990.0,
        'fecha': '2026-06-20',
        'categoria': 'Supermercado',
      });
      expect(d.comercio, 'LIDER');
      expect(d.monto, -12990.0);
      expect(d.fecha, '2026-06-20');
      expect(d.categoria, 'Supermercado');
    });

    test('acepta categoria nula', () {
      final d = BoletaDraft.fromJson({
        'comercio': 'Panaderia',
        'monto': -3500.0,
        'fecha': '2026-06-21',
        'categoria': null,
      });
      expect(d.categoria, isNull);
    });

    test('maneja monto como int en json', () {
      final d = BoletaDraft.fromJson({
        'comercio': 'Farmacia',
        'monto': -5000,
        'fecha': '2026-06-22',
        'categoria': 'Salud',
      });
      expect(d.monto, -5000.0);
    });

    test('tolera fecha null → queda como cadena vacía', () {
      final d = BoletaDraft.fromJson({
        'comercio': 'Minimarket',
        'monto': -2000.0,
        'fecha': null,
        'categoria': null,
      });
      expect(d.fecha, '');
    });
  });

  // ── ApiService.escanearBoleta ────────────────────────────────────────────────

  group('ApiService.escanearBoleta', () {
    test('hace POST multipart a /transactions/boleta y parsea draft', () async {
      late http.BaseRequest captured;
      final mock = MockClient.streaming((req, body) async {
        captured = req;
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'comercio': 'LIDER',
            'monto': -12990.0,
            'fecha': '2026-06-20',
            'categoria': 'Supermercado',
          }))),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final api = ApiService(client: mock, token: () => 'TOK', baseUrl: 'http://x/api/v1');
      final draft = await api.escanearBoleta(Uint8List.fromList([1, 2, 3]), 'boleta.jpg');

      expect(captured.url.path, contains('/transactions/boleta'));
      expect(captured.headers['Authorization'], 'Bearer TOK');
      expect(draft.comercio, 'LIDER');
      expect(draft.monto, -12990.0);
      expect(draft.categoria, 'Supermercado');
    });

    test('lanza ApiException en 422', () async {
      final mock = MockClient.streaming((req, body) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({'detail': 'No pudimos leer la boleta'}))),
          422,
        );
      });
      final api = ApiService(client: mock, token: () => 't', baseUrl: 'http://x/api/v1');
      expect(() => api.escanearBoleta(Uint8List.fromList([1]), 'x.jpg'), throwsA(isA<ApiException>()));
    });
  });

  // ── ApiService.crearManual ───────────────────────────────────────────────────

  group('ApiService.crearManual', () {
    test('hace POST JSON a /transactions/manual con campos correctos', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({'ok': true, 'id': 'abc123'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final api = ApiService(client: mock, token: () => 'TOK', baseUrl: 'http://x/api/v1');
      await api.crearManual(
        comercio: 'LIDER',
        monto: -12990.0,
        fecha: '2026-06-20',
        categoria: 'Supermercado',
      );

      expect(captured.url.path, contains('/transactions/manual'));
      expect(captured.headers['Authorization'], 'Bearer TOK');
      expect(captured.headers['content-type'], contains('application/json'));
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['comercio'], 'LIDER');
      expect(body['monto'], -12990.0);
      expect(body['fecha'], '2026-06-20');
      expect(body['categoria'], 'Supermercado');
    });

    test('lanza ApiException en error 422', () async {
      final mock = MockClient((req) async => http.Response(
            jsonEncode({'detail': 'categoría inválida'}),
            422,
          ));
      final api = ApiService(client: mock, token: () => 't', baseUrl: 'http://x/api/v1');
      expect(
        () => api.crearManual(
          comercio: 'X',
          monto: -1000.0,
          fecha: '2026-06-20',
          categoria: 'InvalidCat',
        ),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
