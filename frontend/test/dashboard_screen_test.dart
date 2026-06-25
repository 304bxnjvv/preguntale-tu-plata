import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:preguntale_tu_plata/screens/dashboard_screen.dart';
import 'package:preguntale_tu_plata/providers/data_providers.dart';
import 'package:preguntale_tu_plata/models/summary.dart';
import 'package:preguntale_tu_plata/models/transaction.dart';
import 'package:preguntale_tu_plata/models/insights.dart';

// Shared provider overrides for insights providers (no data to avoid side effects).
List<Override> _insightsOverrides() => [
      suscripcionesProvider.overrideWith(
          (ref) async => const Suscripciones(totalMensual: 0, items: [])),
      comparativoProvider.overrideWith((ref) async => const Comparativo(
            mesActual: '2025-06',
            mesAnterior: '2025-05',
            gastosActual: 0,
            gastosAnterior: 0,
            delta: 0,
          )),
    ];

void main() {
  testWidgets('rendea total de gastos y una transacción', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        summaryProvider.overrideWith((ref) async => const Summary(
              porMoneda: {'CLP': MonedaTotales(ingresos: 2500000, gastos: -89890)},
              gastosPorCategoria: [],
              gastosPorBanco: [BancoTotal(banco: 'BCI', total: -89890)],
            )),
        transactionsProvider.overrideWith((ref) async => const [
              Transaction(id: '1', fecha: '2025-06-01', descripcion: 'SUPERMERCADO LIDER',
                  monto: -45000, moneda: 'CLP', tarjeta: null, tipo: 'cargo',
                  categoria: null, banco: 'BCI', fuente: 'cartola'),
            ]),
        ..._insightsOverrides(),
      ],
      child: const MaterialApp(home: DashboardScreen()),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('89.890'), findsWidgets);
    expect(find.text('SUPERMERCADO LIDER'), findsOneWidget);
  });

  testWidgets('empty state cuando no hay transacciones', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        summaryProvider.overrideWith((ref) async => const Summary(
              porMoneda: {}, gastosPorCategoria: [], gastosPorBanco: [])),
        transactionsProvider.overrideWith((ref) async => const <Transaction>[]),
        ..._insightsOverrides(),
      ],
      child: const MaterialApp(home: DashboardScreen()),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('Sube tu primera cartola'), findsOneWidget);
  });

  testWidgets('card suscripciones aparece con items', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        summaryProvider.overrideWith((ref) async => const Summary(
              porMoneda: {'CLP': MonedaTotales(ingresos: 1000000, gastos: -200000)},
              gastosPorCategoria: [],
              gastosPorBanco: [],
            )),
        transactionsProvider.overrideWith((ref) async => const <Transaction>[]),
        suscripcionesProvider.overrideWith((ref) async => const Suscripciones(
              totalMensual: 18990,
              items: [
                SuscripcionItem(
                    descripcion: 'netflix', monto: 12990, categoria: 'Entretenimiento'),
                SuscripcionItem(
                    descripcion: 'spotify', monto: 5990, categoria: 'Musica'),
              ],
            )),
        comparativoProvider.overrideWith((ref) async => const Comparativo(
              mesActual: '2025-06',
              mesAnterior: '2025-05',
              gastosActual: 200000,
              gastosAnterior: 0,
              delta: 0,
            )),
      ],
      child: const MaterialApp(home: DashboardScreen()),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('Suscripciones detectadas'), findsOneWidget);
    expect(find.textContaining('18.990'), findsOneWidget);
    expect(find.textContaining('Netflix'), findsOneWidget);
  });

  testWidgets('línea comparativo muestra delta cuando gastosAnterior > 0', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        summaryProvider.overrideWith((ref) async => const Summary(
              porMoneda: {'CLP': MonedaTotales(ingresos: 1000000, gastos: -600000)},
              gastosPorCategoria: [],
              gastosPorBanco: [],
            )),
        transactionsProvider.overrideWith((ref) async => const <Transaction>[]),
        suscripcionesProvider.overrideWith(
            (ref) async => const Suscripciones(totalMensual: 0, items: [])),
        comparativoProvider.overrideWith((ref) async => const Comparativo(
              mesActual: '2025-06',
              mesAnterior: '2025-05',
              gastosActual: 600000,
              gastosAnterior: 500000,
              delta: 100000,
            )),
      ],
      child: const MaterialApp(home: DashboardScreen()),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('vs mes pasado'), findsOneWidget);
    expect(find.textContaining('100.000'), findsOneWidget);
  });
}
