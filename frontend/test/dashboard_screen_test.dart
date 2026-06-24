import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:preguntale_tu_plata/screens/dashboard_screen.dart';
import 'package:preguntale_tu_plata/providers/data_providers.dart';
import 'package:preguntale_tu_plata/models/summary.dart';
import 'package:preguntale_tu_plata/models/transaction.dart';

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
      ],
      child: const MaterialApp(home: DashboardScreen()),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('Sube tu primera cartola'), findsOneWidget);
  });
}
