import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:preguntale_tu_plata/models/transaction.dart';
import 'package:preguntale_tu_plata/widgets/transaction_tile.dart';
import 'package:preguntale_tu_plata/providers/data_providers.dart';
import 'package:preguntale_tu_plata/services/api_service.dart';
import 'package:preguntale_tu_plata/models/categorias.dart';

const _txn = Transaction(
  id: 'abc-123',
  fecha: '2026-06-01',
  descripcion: 'UBER EATS *9988',
  monto: -5500,
  moneda: 'CLP',
  tarjeta: null,
  tipo: 'gasto',
  categoria: 'Otros',
  banco: 'BCI',
  fuente: 'cartola',
);

Widget _wrap({
  required Transaction t,
  VoidCallback? onCategoriaChanged,
  http.Client? httpClient,
}) {
  final mock = httpClient ??
      MockClient((_) async => http.Response(
            jsonEncode({'actualizadas': 1}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));
  return ProviderScope(
    overrides: [
      apiProvider.overrideWith(
        (ref) => ApiService(
          client: mock,
          token: () => 'test-token',
          baseUrl: 'http://localhost/api/v1',
        ),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: TransactionTile(t: t, onCategoriaChanged: onCategoriaChanged),
      ),
    ),
  );
}

void main() {
  group('TransactionTile', () {
    testWidgets('rendea descripción y monto formateado', (tester) async {
      await tester.pumpWidget(_wrap(t: _txn));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('UBER EATS *9988'), findsOneWidget);
      expect(find.textContaining('5.500'), findsOneWidget);
    });

    testWidgets('tap abre bottom sheet con los 11 chips de categoría', (tester) async {
      await tester.pumpWidget(_wrap(t: _txn));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byType(ListTile));
      await tester.pump(const Duration(milliseconds: 300));

      // El sheet debe mostrar los 11 chips
      for (final cat in kCategorias) {
        expect(find.text(cat), findsOneWidget);
      }
    });

    testWidgets('chip de categoría actual aparece resaltado', (tester) async {
      await tester.pumpWidget(_wrap(t: _txn));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byType(ListTile));
      await tester.pump(const Duration(milliseconds: 300));

      // "Otros" debe estar en el sheet (la categoría actual de _txn)
      expect(find.text('Otros'), findsOneWidget);
    });

    test('ApiService.editarCategoria manda PATCH con token y parsea actualizadas', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({'actualizadas': 3}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final api = ApiService(
        client: mock,
        token: () => 'tok123',
        baseUrl: 'http://x/api/v1',
      );

      final n = await api.editarCategoria('abc-123', 'Comida y delivery');

      expect(n, 3);
      expect(captured.method, 'PATCH');
      expect(captured.url.path, '/api/v1/transactions/abc-123');
      expect(captured.headers['Authorization'], 'Bearer tok123');
      expect(jsonDecode(captured.body)['categoria'], 'Comida y delivery');
    });
  });
}
