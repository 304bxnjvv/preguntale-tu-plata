import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:preguntale_tu_plata/widgets/forecast_card.dart';
import 'package:preguntale_tu_plata/providers/data_providers.dart';
import 'package:preguntale_tu_plata/services/api_service.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────

Map<String, dynamic> _sampleJson({
  bool tieneDatos = true,
  double? netoProyectado,
  List<Map<String, dynamic>>? categoriasEnRiesgo,
  String confianza = 'alta',
}) =>
    {
      'tiene_datos': tieneDatos,
      'dias_restantes': 20,
      'dia_del_mes': 10,
      'gasto_actual': 100000.0,
      'gasto_proyectado': 300000.0,
      'ingresos_mes': netoProyectado != null ? 500000.0 : 0.0,
      'neto_proyectado': netoProyectado,
      'categorias_en_riesgo': categoriasEnRiesgo ?? [],
      'confianza': confianza,
      'caveat': confianza == 'baja'
          ? 'aún es temprano en el mes, la proyección puede cambiar'
          : '',
    };

// ── Model tests ────────────────────────────────────────────────────────────────

void main() {
  group('Forecast.fromJson', () {
    test('parsea todos los campos con neto y categorias en riesgo', () {
      final json = _sampleJson(
        netoProyectado: 200000.0,
        categoriasEnRiesgo: [
          {
            'categoria': 'Comida y delivery',
            'tope': 150000.0,
            'proyectado': 200000.0,
            'pct': 133.3,
          }
        ],
      );
      final f = Forecast.fromJson(json);
      expect(f.tieneDatos, isTrue);
      expect(f.diasRestantes, 20);
      expect(f.diaDelMes, 10);
      expect(f.gastoActual, 100000.0);
      expect(f.gastoProyectado, 300000.0);
      expect(f.ingresosMes, 500000.0);
      expect(f.netoProyectado, 200000.0);
      expect(f.categoriasEnRiesgo.length, 1);
      expect(f.categoriasEnRiesgo.first.categoria, 'Comida y delivery');
      expect(f.categoriasEnRiesgo.first.tope, 150000.0);
      expect(f.categoriasEnRiesgo.first.proyectado, 200000.0);
      expect(f.categoriasEnRiesgo.first.pct, 133.3);
      expect(f.confianza, 'alta');
      expect(f.caveat, '');
    });

    test('parsea neto_proyectado nulo', () {
      final f = Forecast.fromJson(_sampleJson());
      expect(f.netoProyectado, isNull);
      expect(f.ingresosMes, 0.0);
    });

    test('parsea tiene_datos == false', () {
      final f = Forecast.fromJson({
        'tiene_datos': false,
        'dias_restantes': 0,
        'dia_del_mes': 1,
        'gasto_actual': 0.0,
        'gasto_proyectado': 0.0,
        'ingresos_mes': 0.0,
        'neto_proyectado': null,
        'categorias_en_riesgo': [],
        'confianza': 'baja',
        'caveat': 'aún es temprano',
      });
      expect(f.tieneDatos, isFalse);
    });

    test('parsea confianza baja con caveat', () {
      final f = Forecast.fromJson(_sampleJson(confianza: 'baja'));
      expect(f.confianza, 'baja');
      expect(f.caveat, isNotEmpty);
    });

    test('CategoriaRiesgo.fromJson parsea correctamente', () {
      final c = CategoriaRiesgo.fromJson({
        'categoria': 'Compras',
        'tope': 80000.0,
        'proyectado': 120000.0,
        'pct': 150.0,
      });
      expect(c.categoria, 'Compras');
      expect(c.tope, 80000.0);
      expect(c.proyectado, 120000.0);
      expect(c.pct, 150.0);
    });
  });

  // ── ApiService.getForecast ─────────────────────────────────────────────────

  group('ApiService.getForecast', () {
    test('manda Bearer token, ruta correcta y parsea respuesta', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode(_sampleJson(netoProyectado: 200000.0)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final api = ApiService(client: mock, token: () => 'MYTOKEN', baseUrl: 'http://x/api/v1');
      final f = await api.getForecast();

      expect(captured.headers['Authorization'], 'Bearer MYTOKEN');
      expect(captured.url.path, endsWith('/insights/forecast'));
      expect(f.gastoProyectado, 300000.0);
      expect(f.tieneDatos, isTrue);
    });

    test('lanza ApiException en error 401', () async {
      final mock = MockClient((req) async => http.Response('Unauthorized', 401));
      final api = ApiService(client: mock, token: () => 't', baseUrl: 'http://x/api/v1');
      expect(() => api.getForecast(), throwsA(isA<ApiException>()));
    });
  });

  // ── forecastProvider ───────────────────────────────────────────────────────

  group('forecastProvider', () {
    test('lee Forecast desde apiProvider', () async {
      final mock = MockClient((_) async => http.Response(
            jsonEncode(_sampleJson()),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));
      final api = ApiService(client: mock, token: () => 'T', baseUrl: 'http://x/api/v1');
      final container = ProviderContainer(overrides: [apiProvider.overrideWithValue(api)]);
      addTearDown(container.dispose);

      final f = await container.read(forecastProvider.future);
      expect(f.gastoProyectado, 300000.0);
    });
  });

  // ── ForecastCard widget ────────────────────────────────────────────────────

  group('ForecastCard widget', () {
    Widget wrap(Forecast data) {
      return ProviderScope(
        overrides: [
          forecastProvider.overrideWith((ref) async => data),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ForecastCard()),
        ),
      );
    }

    testWidgets('muestra gasto_proyectado cuando tiene_datos == true', (tester) async {
      final f = Forecast.fromJson(_sampleJson());
      await tester.pumpWidget(wrap(f));
      await tester.pump(const Duration(seconds: 1));

      // Should display the projected amount
      expect(find.textContaining('300.000'), findsWidgets);
    });

    testWidgets('muestra neto positivo en color salvia', (tester) async {
      final f = Forecast.fromJson(_sampleJson(netoProyectado: 200000.0));
      await tester.pumpWidget(wrap(f));
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('200.000'), findsWidgets);
      expect(find.textContaining('sobran'), findsOneWidget);
    });

    testWidgets('muestra neto negativo con texto faltan', (tester) async {
      final f = Forecast.fromJson({
        'tiene_datos': true,
        'dias_restantes': 20,
        'dia_del_mes': 10,
        'gasto_actual': 100000.0,
        'gasto_proyectado': 600000.0,
        'ingresos_mes': 500000.0,
        'neto_proyectado': -100000.0,
        'categorias_en_riesgo': [],
        'confianza': 'alta',
        'caveat': '',
      });
      await tester.pumpWidget(wrap(f));
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('faltan'), findsOneWidget);
    });

    testWidgets('muestra categorias en riesgo', (tester) async {
      final f = Forecast.fromJson(_sampleJson(
        categoriasEnRiesgo: [
          {
            'categoria': 'Comida y delivery',
            'tope': 100000.0,
            'proyectado': 150000.0,
            'pct': 150.0,
          }
        ],
      ));
      await tester.pumpWidget(wrap(f));
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Comida y delivery'), findsOneWidget);
    });

    testWidgets('muestra caveat cuando confianza es baja', (tester) async {
      final f = Forecast.fromJson(_sampleJson(confianza: 'baja'));
      await tester.pumpWidget(wrap(f));
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('temprano'), findsOneWidget);
    });

    testWidgets('muestra CTA cuando tiene_datos == false', (tester) async {
      final f = Forecast.fromJson({
        'tiene_datos': false,
        'dias_restantes': 0,
        'dia_del_mes': 1,
        'gasto_actual': 0.0,
        'gasto_proyectado': 0.0,
        'ingresos_mes': 0.0,
        'neto_proyectado': null,
        'categorias_en_riesgo': [],
        'confianza': 'baja',
        'caveat': '',
      });
      await tester.pumpWidget(wrap(f));
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('cartola'), findsOneWidget);
    });
  });
}
