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
    when(() => api.getSummary()).thenAnswer((_) async => const Summary(
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
    when(() => api.getTransactions()).thenAnswer((_) async => const [
          Transaction(id: '1', fecha: '2025-06-01', descripcion: 'LIDER', monto: -45000,
              moneda: 'CLP', tarjeta: null, tipo: 'cargo', categoria: null, banco: 'BCI',
              fuente: 'cartola'),
        ]);
    final container = ProviderContainer(overrides: [apiProvider.overrideWithValue(api)]);
    addTearDown(container.dispose);

    final list = await container.read(transactionsProvider.future);
    expect(list.single.descripcion, 'LIDER');
  });
}
