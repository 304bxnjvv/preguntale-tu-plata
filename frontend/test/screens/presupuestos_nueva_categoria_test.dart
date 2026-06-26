import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:preguntale_tu_plata/screens/presupuestos_screen.dart';
import 'package:preguntale_tu_plata/providers/data_providers.dart';
import 'package:preguntale_tu_plata/services/api_service.dart';

/// Construye un ProviderScope con overrides mínimos para la pantalla de presupuestos.
Widget _wrapScreen({
  List<PresupuestoEstado> presupuestos = const [],
  http.Client? httpClient,
}) {
  final mock = httpClient ??
      MockClient((req) async {
        // /categorias
        if (req.url.path.endsWith('/categorias') && req.method == 'GET') {
          return http.Response(
            jsonEncode({
              'base': ['Comida y delivery', 'Supermercado'],
              'personalizadas': <String>[],
              'todas': ['Comida y delivery', 'Supermercado'],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('{}', 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });

  return ProviderScope(
    overrides: [
      presupuestosProvider.overrideWith((ref) async => presupuestos),
      apiProvider.overrideWith(
        (ref) => ApiService(
          client: mock,
          token: () => 'test-token',
          baseUrl: 'http://localhost/api/v1',
        ),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const PresupuestosScreen(),
          ),
        ],
      ),
    ),
  );
}

void main() {
  group('PresupuestosScreen — Nueva categoría', () {
    testWidgets('sheet de fijar tope muestra opción + Nueva categoría', (tester) async {
      await tester.pumpWidget(_wrapScreen());
      await tester.pump(const Duration(milliseconds: 300));

      // Abrir el sheet pulsando el FAB "+ tope"
      await tester.tap(find.text('+ tope'));
      await tester.pump(const Duration(milliseconds: 300));

      // El sheet debe mostrar el botón "+ Nueva categoría"
      expect(find.text('+ Nueva categoría'), findsOneWidget);
    });

    testWidgets('al pulsar + Nueva categoría aparece el TextField', (tester) async {
      await tester.pumpWidget(_wrapScreen());
      await tester.pump(const Duration(milliseconds: 300));

      // Abrir el sheet
      await tester.tap(find.text('+ tope'));
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll hasta el botón y pulsarlo (puede estar fuera del viewport)
      await tester.ensureVisible(find.byKey(const Key('btn_nueva_categoria')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('btn_nueva_categoria')), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));

      // Debe aparecer el TextField para la nueva categoría
      expect(find.byKey(const Key('field_nueva_categoria')), findsOneWidget);
    });

    testWidgets('el sheet muestra dropdown de categorías del provider', (tester) async {
      await tester.pumpWidget(_wrapScreen());
      await tester.pump(const Duration(milliseconds: 300));

      // Abrir el sheet
      await tester.tap(find.text('+ tope'));
      await tester.pump(const Duration(milliseconds: 500));

      // El dropdown debe contener "Comida y delivery" (del provider mock)
      expect(find.text('Comida y delivery'), findsWidgets);
    });
  });
}
