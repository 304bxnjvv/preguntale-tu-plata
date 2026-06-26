import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:preguntale_tu_plata/services/api_service.dart';
import 'package:preguntale_tu_plata/providers/data_providers.dart';

void main() {
  // ── CategoriasData.fromJson ──────────────────────────────────────────────────

  group('CategoriasData.fromJson', () {
    test('parsea los tres campos correctamente', () {
      final data = CategoriasData.fromJson({
        'base': ['Comida y delivery', 'Supermercado', 'Transporte'],
        'personalizadas': ['Mi categoría', 'Gym'],
        'todas': [
          'Comida y delivery',
          'Supermercado',
          'Transporte',
          'Mi categoría',
          'Gym',
        ],
      });

      expect(data.base, ['Comida y delivery', 'Supermercado', 'Transporte']);
      expect(data.personalizadas, ['Mi categoría', 'Gym']);
      expect(data.todas.length, 5);
      expect(data.todas, containsAll(['Mi categoría', 'Gym']));
    });

    test('parsea listas vacías (sin personalizadas)', () {
      final data = CategoriasData.fromJson({
        'base': ['Comida y delivery'],
        'personalizadas': <String>[],
        'todas': ['Comida y delivery'],
      });

      expect(data.personalizadas, isEmpty);
      expect(data.todas.length, 1);
    });

    test('fromJson desde JSON encodificado', () {
      final raw = jsonEncode({
        'base': ['A', 'B'],
        'personalizadas': ['C'],
        'todas': ['A', 'B', 'C'],
      });
      final data = CategoriasData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      expect(data.todas, ['A', 'B', 'C']);
    });
  });

  // ── ApiService.getCategorias ─────────────────────────────────────────────────

  group('ApiService.getCategorias', () {
    test('GET /categorias manda Bearer token y parsea respuesta', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'base': ['Comida y delivery', 'Supermercado'],
            'personalizadas': ['Gym'],
            'todas': ['Comida y delivery', 'Supermercado', 'Gym'],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final api = ApiService(client: mock, token: () => 'TOKEN_CAT', baseUrl: 'http://x/api/v1');

      final data = await api.getCategorias();

      expect(captured.headers['Authorization'], 'Bearer TOKEN_CAT');
      expect(captured.url.path, endsWith('/categorias'));
      expect(captured.method, 'GET');
      expect(data.base, ['Comida y delivery', 'Supermercado']);
      expect(data.personalizadas, ['Gym']);
      expect(data.todas.length, 3);
    });

    test('lanza ApiException en error 401', () async {
      final mock = MockClient((req) async => http.Response('Unauthorized', 401));
      final api = ApiService(client: mock, token: () => 't', baseUrl: 'http://x/api/v1');
      expect(() => api.getCategorias(), throwsA(isA<ApiException>()));
    });
  });

  // ── ApiService.crearCategoria ────────────────────────────────────────────────

  group('ApiService.crearCategoria', () {
    test('POST /categorias con nombre correcto devuelve sin error', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({'nombre': 'Gym'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final api = ApiService(client: mock, token: () => 'TOK', baseUrl: 'http://x/api/v1');

      await api.crearCategoria('Gym');

      expect(captured.method, 'POST');
      expect(captured.url.path, endsWith('/categorias'));
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['nombre'], 'Gym');
    });

    test('lanza ApiException con detail en 422 (duplicada)', () async {
      final mock = MockClient((req) async => http.Response(
            jsonEncode({'detail': 'Categoría ya existe'}),
            422,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));
      final api = ApiService(client: mock, token: () => 't', baseUrl: 'http://x/api/v1');

      expect(
        () => api.crearCategoria('Gym'),
        throwsA(
          isA<ApiException>().having((e) => e.message, 'message', 'Categoría ya existe'),
        ),
      );
    });

    test('lanza ApiException con mensaje genérico si no hay detail', () async {
      final mock = MockClient((req) async => http.Response(
            '{}',
            422,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));
      final api = ApiService(client: mock, token: () => 't', baseUrl: 'http://x/api/v1');

      expect(
        () => api.crearCategoria('X'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  // ── categoriasProvider ────────────────────────────────────────────────────────

  group('categoriasProvider', () {
    test('lee categoriasData desde apiProvider', () async {
      final mock = MockClient((_) async => http.Response(
            jsonEncode({
              'base': ['Comida y delivery'],
              'personalizadas': ['Gym'],
              'todas': ['Comida y delivery', 'Gym'],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));
      final api = ApiService(client: mock, token: () => 'T', baseUrl: 'http://x/api/v1');
      final container = ProviderContainer(overrides: [apiProvider.overrideWithValue(api)]);
      addTearDown(container.dispose);

      final data = await container.read(categoriasProvider.future);
      expect(data.todas, ['Comida y delivery', 'Gym']);
      expect(data.personalizadas, ['Gym']);
    });
  });
}
