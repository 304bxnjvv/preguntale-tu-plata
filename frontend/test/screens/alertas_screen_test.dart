import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:preguntale_tu_plata/screens/alertas_screen.dart';
import 'package:preguntale_tu_plata/providers/data_providers.dart';

final _sampleAlertas = [
  Alerta(
    key: 'tarjeta_vence:2026-06-28',
    tipo: 'tarjeta_vence',
    severidad: 'urgent',
    titulo: 'Tu tarjeta vence en 3 días',
    detalle: 'Tienes \$200.000 por pagar',
    fecha: '2026-06-25',
  ),
  Alerta(
    key: 'presupuesto:Compras',
    tipo: 'presupuesto',
    severidad: 'warning',
    titulo: 'Presupuesto Compras cerca del tope',
    detalle: 'Has gastado el 90%',
    fecha: '2026-06-25',
  ),
  Alerta(
    key: 'gasto:abc-123',
    tipo: 'gasto_inusual',
    severidad: 'info',
    titulo: 'Gasto inusual detectado',
    detalle: 'Compraste por \$800.000',
    fecha: '2026-06-24',
  ),
];

Widget _wrapScreen(List<Alerta> alertas) {
  return ProviderScope(
    overrides: [
      alertasProvider.overrideWith((ref) async => alertas),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const AlertasScreen(),
          ),
        ],
      ),
    ),
  );
}

void main() {
  group('AlertasScreen', () {
    testWidgets('pinta una tarjeta por cada alerta', (tester) async {
      await tester.pumpWidget(_wrapScreen(_sampleAlertas));
      await tester.pump(const Duration(milliseconds: 300));

      // Muestra el título de cada alerta
      expect(find.text('Tu tarjeta vence en 3 días'), findsOneWidget);
      expect(find.text('Presupuesto Compras cerca del tope'), findsOneWidget);
      expect(find.text('Gasto inusual detectado'), findsOneWidget);

      // Debe haber una Card por alerta (3 en total)
      expect(find.byType(Card), findsNWidgets(3));
    });

    testWidgets('muestra estado vacío cuando no hay alertas', (tester) async {
      await tester.pumpWidget(_wrapScreen([]));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('todo en orden'), findsOneWidget);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('muestra los detalles de cada alerta', (tester) async {
      await tester.pumpWidget(_wrapScreen(_sampleAlertas));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Tienes \$200.000 por pagar'), findsOneWidget);
      expect(find.text('Has gastado el 90%'), findsOneWidget);
    });
  });
}
