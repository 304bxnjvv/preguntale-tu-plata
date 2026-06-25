import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preguntale_tu_plata/services/api_service.dart';
import 'package:preguntale_tu_plata/models/summary.dart';
import 'package:preguntale_tu_plata/models/transaction.dart';
import 'package:preguntale_tu_plata/providers/data_providers.dart';

class MockApi extends Mock implements ApiService {}

void main() {
  test('summaryProvider devuelve lo que da ApiService', () async {
    final api = MockApi();
    when(() => api.getSummary(dias: any(named: 'dias'), tipo: any(named: 'tipo')))
        .thenAnswer((_) async => const Summary(
              porMoneda: {'CLP': MonedaTotales(ingresos: 100, gastos: -50)},
              gastosPorCategoria: [],
              gastosPorBanco: [BancoTotal(banco: 'BCI', total: -50)],
            ));
    final container = ProviderContainer(overrides: [apiProvider.overrideWithValue(api)]);
    addTearDown(container.dispose);

    final s = await container.read(summaryProvider.future);
    expect(s.porMoneda['CLP']!.gastos, -50.0);
  });

  test('transactionsProvider devuelve la lista del ApiService', () async {
    final api = MockApi();
    when(() => api.getTransactions(dias: any(named: 'dias'), tipo: any(named: 'tipo')))
        .thenAnswer((_) async => const [
              Transaction(
                  id: '1',
                  fecha: '2025-06-01',
                  descripcion: 'LIDER',
                  monto: -45000,
                  moneda: 'CLP',
                  tarjeta: null,
                  tipo: 'cargo',
                  categoria: null,
                  banco: 'BCI',
                  fuente: 'cartola'),
            ]);
    final container = ProviderContainer(overrides: [apiProvider.overrideWithValue(api)]);
    addTearDown(container.dispose);

    final list = await container.read(transactionsProvider.future);
    expect(list.single.descripcion, 'LIDER');
  });

  test('cambiar dashboardFilterProvider refetches summaryProvider con nuevos parámetros', () async {
    final api = MockApi();
    // Default call: dias=null (Todo), tipo=null
    when(() => api.getSummary(dias: null, tipo: null)).thenAnswer((_) async => const Summary(
          porMoneda: {'CLP': MonedaTotales(ingresos: 100, gastos: -50)},
          gastosPorCategoria: [],
          gastosPorBanco: [],
        ));
    // After filter change: dias=7, tipo='gasto'
    when(() => api.getSummary(dias: 7, tipo: 'gasto')).thenAnswer((_) async => const Summary(
          porMoneda: {'CLP': MonedaTotales(ingresos: 0, gastos: -20)},
          gastosPorCategoria: [],
          gastosPorBanco: [],
        ));
    when(() => api.getTransactions(dias: any(named: 'dias'), tipo: any(named: 'tipo')))
        .thenAnswer((_) async => []);

    final container = ProviderContainer(overrides: [apiProvider.overrideWithValue(api)]);
    addTearDown(container.dispose);

    // Read initial
    final s1 = await container.read(summaryProvider.future);
    expect(s1.porMoneda['CLP']!.gastos, -50.0);

    // Update filter
    container.read(dashboardFilterProvider.notifier).state =
        const DashboardFilter(dias: 7, tipo: 'gasto');

    // Refetch
    final s2 = await container.read(summaryProvider.future);
    expect(s2.porMoneda['CLP']!.gastos, -20.0);

    // Verify correct params were used
    verify(() => api.getSummary(dias: 7, tipo: 'gasto')).called(1);
  });
}
