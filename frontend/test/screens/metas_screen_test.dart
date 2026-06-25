import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:preguntale_tu_plata/screens/metas_screen.dart';
import 'package:preguntale_tu_plata/widgets/meta_card.dart';
import 'package:preguntale_tu_plata/providers/data_providers.dart';

// Datos sintéticos de metas para los tests
final _sampleMetas = [
  Meta(
    id: 'abc123',
    nombre: 'Vacaciones',
    montoObjetivo: 500000,
    montoActual: 200000,
    progreso: 0.4,
    fechaObjetivo: '2026-12-31',
    aporteMensualNecesario: 30000,
  ),
  Meta(
    id: 'def456',
    nombre: 'Fondo de emergencia',
    montoObjetivo: 1000000,
    montoActual: 750000,
    progreso: 0.75,
    aporteMensualNecesario: null,
  ),
];

/// Envuelve la pantalla con un ProviderScope + GoRouter mínimo.
Widget _wrapScreen(List<Meta> metas) {
  return ProviderScope(
    overrides: [
      metasProvider.overrideWith((ref) async => metas),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const MetasScreen(),
          ),
        ],
      ),
    ),
  );
}

/// Envuelve el widget card directamente (sin router).
Widget _wrapCard(List<Meta> metas) {
  return ProviderScope(
    overrides: [
      metasProvider.overrideWith((ref) async => metas),
    ],
    child: MaterialApp(
      home: Scaffold(body: MetaCard()),
    ),
  );
}

void main() {
  group('MetasScreen', () {
    testWidgets('pinta una barra por cada meta', (tester) async {
      await tester.pumpWidget(_wrapScreen(_sampleMetas));
      await tester.pump(const Duration(milliseconds: 300));

      // Debe mostrar el nombre de cada meta
      expect(find.text('Vacaciones'), findsOneWidget);
      expect(find.text('Fondo de emergencia'), findsOneWidget);

      // Debe haber un LinearProgressIndicator por meta
      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
    });

    testWidgets('muestra CTA cuando no hay metas', (tester) async {
      await tester.pumpWidget(_wrapScreen([]));
      await tester.pump(const Duration(milliseconds: 300));

      // El empty state muestra texto de CTA
      expect(find.textContaining('primera meta'), findsWidgets);
      // No deben aparecer barras de progreso
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('muestra montos y progreso formateados', (tester) async {
      await tester.pumpWidget(_wrapScreen(_sampleMetas));
      await tester.pump(const Duration(milliseconds: 300));

      // 40% de progreso para Vacaciones
      expect(find.textContaining('40%'), findsWidgets);
      // Monto objetivo formateado
      expect(find.textContaining('500.000'), findsWidgets);
    });
  });

  group('MetaCard (dashboard card)', () {
    testWidgets('muestra la meta más cercana al objetivo', (tester) async {
      await tester.pumpWidget(_wrapCard(_sampleMetas));
      await tester.pump(const Duration(milliseconds: 300));

      // Debe mostrar algo con "meta" o nombre de meta
      expect(find.textContaining('meta'), findsWidgets);
    });

    testWidgets('muestra CTA cuando no hay metas', (tester) async {
      await tester.pumpWidget(_wrapCard([]));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('primera meta'), findsOneWidget);
    });
  });
}
