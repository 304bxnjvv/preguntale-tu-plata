import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:preguntale_tu_plata/screens/presupuestos_screen.dart';
import 'package:preguntale_tu_plata/widgets/presupuesto_card.dart';
import 'package:preguntale_tu_plata/providers/data_providers.dart';

// Datos sintéticos de presupuestos para los tests
final _samplePresupuestos = [
  PresupuestoEstado(
    categoria: 'Comida y delivery',
    montoTope: 100000,
    gastado: 50000,
    pct: 0.5,
    estado: 'ok',
  ),
  PresupuestoEstado(
    categoria: 'Compras',
    montoTope: 20000,
    gastado: 18000,
    pct: 0.9,
    estado: 'cerca',
  ),
  PresupuestoEstado(
    categoria: 'Salud',
    montoTope: 10000,
    gastado: 15000,
    pct: 1.5,
    estado: 'excedido',
  ),
];

/// Envuelve el widget con un ProviderScope + GoRouter mínimo (para push).
Widget _wrapScreen(List<PresupuestoEstado> presupuestos) {
  return ProviderScope(
    overrides: [
      presupuestosProvider.overrideWith((ref) async => presupuestos),
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

/// Envuelve el widget card directamente (sin router).
Widget _wrapCard(List<PresupuestoEstado> presupuestos) {
  return ProviderScope(
    overrides: [
      presupuestosProvider.overrideWith((ref) async => presupuestos),
    ],
    child: MaterialApp(
      home: Scaffold(body: PresupuestoCard()),
    ),
  );
}

void main() {
  group('PresupuestosScreen', () {
    testWidgets('pinta una barra por cada categoría', (tester) async {
      await tester.pumpWidget(_wrapScreen(_samplePresupuestos));
      await tester.pump(const Duration(milliseconds: 300));

      // Debe mostrar el nombre de cada categoría
      expect(find.text('Comida y delivery'), findsOneWidget);
      expect(find.text('Compras'), findsOneWidget);
      expect(find.text('Salud'), findsOneWidget);

      // Debe haber un LinearProgressIndicator por presupuesto
      expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
    });

    testWidgets('muestra CTA cuando no hay presupuestos', (tester) async {
      await tester.pumpWidget(_wrapScreen([]));
      await tester.pump(const Duration(milliseconds: 300));

      // El empty state muestra texto y botón, ambos con el texto "primer presupuesto"
      expect(find.textContaining('primer presupuesto'), findsWidgets);
      // No deben aparecer barras de progreso
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('muestra montos formateados en CLP', (tester) async {
      await tester.pumpWidget(_wrapScreen(_samplePresupuestos));
      await tester.pump(const Duration(milliseconds: 300));

      // $50.000 gastado de $100.000 para Comida y delivery
      expect(find.textContaining('50.000'), findsWidgets);
      expect(find.textContaining('100.000'), findsWidgets);
    });
  });

  group('PresupuestoCard (dashboard card)', () {
    testWidgets('muestra alerta cuando hay categorías cerca/excedido', (tester) async {
      await tester.pumpWidget(_wrapCard(_samplePresupuestos));
      await tester.pump(const Duration(milliseconds: 300));

      // Debe mencionar que hay categorías cerca del tope (Compras + Salud = 2)
      expect(find.textContaining('categoría'), findsWidgets);
    });

    testWidgets('muestra mensaje positivo cuando todo está ok', (tester) async {
      final okPresupuestos = [
        PresupuestoEstado(
          categoria: 'Comida y delivery',
          montoTope: 100000,
          gastado: 30000,
          pct: 0.3,
          estado: 'ok',
        ),
      ];
      await tester.pumpWidget(_wrapCard(okPresupuestos));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('topes'), findsOneWidget);
    });

    testWidgets('muestra CTA cuando no hay topes fijados', (tester) async {
      await tester.pumpWidget(_wrapCard([]));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('primer presupuesto'), findsOneWidget);
    });
  });
}
