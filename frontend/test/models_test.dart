import 'package:flutter_test/flutter_test.dart';
import 'package:preguntale_tu_plata/models/transaction.dart';
import 'package:preguntale_tu_plata/models/summary.dart';

void main() {
  test('Transaction.fromJson parsea campos', () {
    final t = Transaction.fromJson({
      'id': 'abc', 'fecha': '2025-06-01', 'descripcion': 'LIDER',
      'monto': -45000.0, 'moneda': 'CLP', 'tarjeta': null,
      'tipo': 'cargo', 'categoria': null, 'banco': 'BCI', 'fuente': 'cartola',
    });
    expect(t.id, 'abc');
    expect(t.monto, -45000.0);
    expect(t.banco, 'BCI');
    expect(t.tarjeta, isNull);
  });

  test('Summary.fromJson parsea por_moneda y gastos_por_banco', () {
    final s = Summary.fromJson({
      'por_moneda': {'CLP': {'ingresos': 2500000.0, 'gastos': -89890.0}},
      'gastos_por_categoria': [],
      'gastos_por_banco': [{'banco': 'BCI', 'total': -89890.0}],
    });
    expect(s.porMoneda['CLP']!.gastos, -89890.0);
    expect(s.porMoneda['CLP']!.ingresos, 2500000.0);
    expect(s.gastosPorBanco.single.banco, 'BCI');
  });
}
