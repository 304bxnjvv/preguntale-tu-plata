import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:preguntale_tu_plata/services/api_service.dart';
import 'package:preguntale_tu_plata/providers/data_providers.dart';

void main() {
  // ── PresupuestoEstado.fromJson ─────────────────────────────────────────────

  group('PresupuestoEstado.fromJson', () {
    test('parsea todos los campos estado ok', () {
      final p = PresupuestoEstado.fromJson({
        'categoria': 'Comida y delivery',
        'monto_tope': 100000.0,
        'gastado': 50000.0,
        'pct': 0.5,
        'estado': 'ok',
      });
      expect(p.categoria, 'Comida y delivery');
      expect(p.montoTope, 100000.0);
      expect(p.gastado, 50000.0);
      expect(p.pct, 0.5);
      expect(p.estado, 'ok');
    });

    test('parsea estado excedido', () {
      final p = PresupuestoEstado.fromJson({
        'categoria': 'Compras',
        'monto_tope': 10000.0,
        'gastado': 15000.0,
        'pct': 1.5,
        'estado': 'excedido',
      });
      expect(p.estado, 'excedido');
      expect(p.pct, 1.5);
    });

    test('parsea estado cerca', () {
      final p = PresupuestoEstado.fromJson({
        'categoria': 'Salud',
        'monto_tope': 50000.0,
        'gastado': 42000.0,
        'pct': 0.84,
        'estado': 'cerca',
      });
      expect(p.estado, 'cerca');
    });
  });

  // ── Meta.fromJson ──────────────────────────────────────────────────────────

  group('Meta.fromJson', () {
    test('parsea todos los campos con fecha y aporte', () {
      final m = Meta.fromJson({
        'id': 'abc-123',
        'nombre': 'Fondo de emergencia',
        'monto_objetivo': 500000.0,
        'monto_actual': 200000.0,
        'fecha_objetivo': '2026-12-31',
        'progreso': 0.4,
        'aporte_mensual_necesario': 50000.0,
      });
      expect(m.id, 'abc-123');
      expect(m.nombre, 'Fondo de emergencia');
      expect(m.montoObjetivo, 500000.0);
      expect(m.montoActual, 200000.0);
      expect(m.fechaObjetivo, '2026-12-31');
      expect(m.progreso, 0.4);
      expect(m.aporteMensualNecesario, 50000.0);
    });

    test('parsea sin fecha y sin aporte (null)', () {
      final m = Meta.fromJson({
        'id': 'xyz',
        'nombre': 'Viaje',
        'monto_objetivo': 1000000.0,
        'monto_actual': 0.0,
        'fecha_objetivo': null,
        'progreso': 0.0,
        'aporte_mensual_necesario': null,
      });
      expect(m.fechaObjetivo, isNull);
      expect(m.aporteMensualNecesario, isNull);
      expect(m.progreso, 0.0);
    });

    test('parsea progreso 1.0 meta completada', () {
      final m = Meta.fromJson({
        'id': 'done',
        'nombre': 'Completada',
        'monto_objetivo': 100000.0,
        'monto_actual': 100000.0,
        'fecha_objetivo': null,
        'progreso': 1.0,
        'aporte_mensual_necesario': null,
      });
      expect(m.progreso, 1.0);
    });
  });

  // ── ApiService.getPresupuestos ─────────────────────────────────────────────

  group('ApiService.getPresupuestos', () {
    final sampleItems = [
      {
        'categoria': 'Comida y delivery',
        'monto_tope': 100000.0,
        'gastado': 50000.0,
        'pct': 0.5,
        'estado': 'ok',
      },
    ];

    test('GET /presupuestos retorna lista parseada', () async {
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
      final list = await api.getPresupuestos();

      expect(captured.headers['Authorization'], 'Bearer TOK');
      expect(captured.url.path, endsWith('/presupuestos'));
      expect(list.length, 1);
      expect(list.first.categoria, 'Comida y delivery');
    });

    test('lanza ApiException en error 401', () async {
      final mock = MockClient((req) async => http.Response('Unauthorized', 401));
      final api = ApiService(client: mock, token: () => 't', baseUrl: 'http://x/api/v1');
      expect(() => api.getPresupuestos(), throwsA(isA<ApiException>()));
    });
  });

  group('ApiService.setTope', () {
    test('POST /presupuestos con categoria y monto_tope', () async {
      late http.Request captured;
      final sampleOut = {
        'categoria': 'Salud',
        'monto_tope': 50000.0,
        'gastado': 0.0,
        'pct': 0.0,
        'estado': 'ok',
      };
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode(sampleOut),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final api = ApiService(client: mock, token: () => 'TOK', baseUrl: 'http://x/api/v1');
      final result = await api.setTope('Salud', 50000);

      expect(captured.url.path, endsWith('/presupuestos'));
      expect(captured.method, 'POST');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['categoria'], 'Salud');
      expect(body['monto_tope'], 50000);
      expect(result.categoria, 'Salud');
    });
  });

  group('ApiService.deleteTope', () {
    test('DELETE /presupuestos/{categoria} retorna bool', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(jsonEncode({'ok': true}), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });
      final api = ApiService(client: mock, token: () => 'TOK', baseUrl: 'http://x/api/v1');
      final ok = await api.deleteTope('Salud');

      expect(captured.method, 'DELETE');
      expect(captured.url.path, endsWith('/presupuestos/Salud'));
      expect(ok, isTrue);
    });
  });

  // ── ApiService.getMetas ────────────────────────────────────────────────────

  group('ApiService.getMetas', () {
    final sampleMetas = [
      {
        'id': 'abc',
        'nombre': 'Viaje',
        'monto_objetivo': 500000.0,
        'monto_actual': 100000.0,
        'fecha_objetivo': null,
        'progreso': 0.2,
        'aporte_mensual_necesario': null,
      },
    ];

    test('GET /metas retorna lista parseada', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({'items': sampleMetas}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final api = ApiService(client: mock, token: () => 'TOK', baseUrl: 'http://x/api/v1');
      final list = await api.getMetas();

      expect(captured.url.path, endsWith('/metas'));
      expect(list.length, 1);
      expect(list.first.nombre, 'Viaje');
    });
  });

  group('ApiService.crearMeta', () {
    test('POST /metas con campos correctos', () async {
      late http.Request captured;
      final sampleOut = {
        'id': 'new-id',
        'nombre': 'Fondo',
        'monto_objetivo': 300000.0,
        'monto_actual': 0.0,
        'fecha_objetivo': '2027-01-01',
        'progreso': 0.0,
        'aporte_mensual_necesario': 25000.0,
      };
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode(sampleOut),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final api = ApiService(client: mock, token: () => 'T', baseUrl: 'http://x/api/v1');
      final meta = await api.crearMeta('Fondo', 300000, fechaObjetivo: '2027-01-01');

      expect(captured.method, 'POST');
      expect(captured.url.path, endsWith('/metas'));
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['nombre'], 'Fondo');
      expect(body['monto_objetivo'], 300000);
      expect(body['fecha_objetivo'], '2027-01-01');
      expect(meta.id, 'new-id');
    });
  });

  group('ApiService.actualizarMeta', () {
    test('PATCH /metas/{id} con campos parciales', () async {
      late http.Request captured;
      final sampleOut = {
        'id': 'abc',
        'nombre': 'Viaje',
        'monto_objetivo': 500000.0,
        'monto_actual': 200000.0,
        'fecha_objetivo': null,
        'progreso': 0.4,
        'aporte_mensual_necesario': null,
      };
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode(sampleOut),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final api = ApiService(client: mock, token: () => 'T', baseUrl: 'http://x/api/v1');
      final meta = await api.actualizarMeta('abc', montoActual: 200000);

      expect(captured.method, 'PATCH');
      expect(captured.url.path, endsWith('/metas/abc'));
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['monto_actual'], 200000);
      expect(meta.progreso, 0.4);
    });
  });

  group('ApiService.eliminarMeta', () {
    test('DELETE /metas/{id} retorna bool', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(jsonEncode({'ok': true}), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });
      final api = ApiService(client: mock, token: () => 'T', baseUrl: 'http://x/api/v1');
      final ok = await api.eliminarMeta('abc');

      expect(captured.method, 'DELETE');
      expect(captured.url.path, endsWith('/metas/abc'));
      expect(ok, isTrue);
    });
  });

  // ── Providers ─────────────────────────────────────────────────────────────

  group('presupuestosProvider', () {
    test('lee lista de presupuestos desde apiProvider', () async {
      final pItem = PresupuestoEstado(
        categoria: 'Comida y delivery',
        montoTope: 100000,
        gastado: 50000,
        pct: 0.5,
        estado: 'ok',
      );
      final mock = MockClient((_) async => http.Response(
            jsonEncode({
              'items': [
                {
                  'categoria': 'Comida y delivery',
                  'monto_tope': 100000.0,
                  'gastado': 50000.0,
                  'pct': 0.5,
                  'estado': 'ok',
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));
      final api = ApiService(client: mock, token: () => 'T', baseUrl: 'http://x/api/v1');
      final container = ProviderContainer(overrides: [apiProvider.overrideWithValue(api)]);
      addTearDown(container.dispose);

      final list = await container.read(presupuestosProvider.future);
      expect(list.first.categoria, pItem.categoria);
      expect(list.first.estado, 'ok');
    });
  });

  group('metasProvider', () {
    test('lee lista de metas desde apiProvider', () async {
      final mock = MockClient((_) async => http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'abc',
                  'nombre': 'Viaje',
                  'monto_objetivo': 500000.0,
                  'monto_actual': 100000.0,
                  'fecha_objetivo': null,
                  'progreso': 0.2,
                  'aporte_mensual_necesario': null,
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));
      final api = ApiService(client: mock, token: () => 'T', baseUrl: 'http://x/api/v1');
      final container = ProviderContainer(overrides: [apiProvider.overrideWithValue(api)]);
      addTearDown(container.dispose);

      final list = await container.read(metasProvider.future);
      expect(list.first.nombre, 'Viaje');
      expect(list.first.progreso, 0.2);
    });
  });
}
