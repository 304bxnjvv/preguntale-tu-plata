import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:preguntale_tu_plata/screens/boleta_confirm_screen.dart';
import 'package:preguntale_tu_plata/models/boleta_draft.dart';

// ── Stub para crearManual ──────────────────────────────────────────────────────

bool _crearManualCalled = false;
String? _crearManualComercio;
double? _crearManualMonto;

Future<void> _stubCrearManual({
  required String comercio,
  required double monto,
  required String fecha,
  required String categoria,
}) async {
  _crearManualCalled = true;
  _crearManualComercio = comercio;
  _crearManualMonto = monto;
}

// ── Helper: envuelve directamente sin router (evita animaciones de pop) ───────

Widget _wrapDirect(BoletaDraft draft) {
  return ProviderScope(
    child: MaterialApp(
      home: BoletaConfirmScreen(
        draft: draft,
        onGuardar: _stubCrearManual,
      ),
    ),
  );
}

void main() {
  setUp(() {
    _crearManualCalled = false;
    _crearManualComercio = null;
    _crearManualMonto = null;
  });

  group('BoletaConfirmScreen', () {
    final draft = BoletaDraft(
      comercio: 'LIDER EXPRESS',
      monto: -12990.0,
      fecha: '2026-06-20',
      categoria: 'Supermercado',
    );

    testWidgets('muestra comercio y monto del draft', (tester) async {
      await tester.pumpWidget(_wrapDirect(draft));
      await tester.pump(const Duration(milliseconds: 300));

      // Comercio debe aparecer en el campo de texto
      expect(find.text('LIDER EXPRESS'), findsOneWidget);
      // Monto absoluto: el controller almacena el número sin formatear
      expect(find.textContaining('12990'), findsOneWidget);
    });

    testWidgets('tap "Guardar gasto" llama crearManual con los datos', (tester) async {
      await tester.pumpWidget(_wrapDirect(draft));
      await tester.pump(const Duration(milliseconds: 300));

      // El botón puede estar fuera del viewport — hacer scroll hasta él.
      await tester.scrollUntilVisible(
        find.text('Guardar gasto'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      await tester.tap(find.text('Guardar gasto'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(_crearManualCalled, isTrue);
      expect(_crearManualComercio, 'LIDER EXPRESS');
      expect(_crearManualMonto, -12990.0);
    });

    testWidgets('muestra la categoría pre-seleccionada del draft', (tester) async {
      await tester.pumpWidget(_wrapDirect(draft));
      await tester.pump(const Duration(milliseconds: 300));

      // La categoría "Supermercado" debe verse seleccionada
      expect(find.text('Supermercado'), findsWidgets);
    });

    testWidgets('botón cancelar está presente', (tester) async {
      await tester.pumpWidget(_wrapDirect(draft));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Cancelar'), findsOneWidget);
    });
  });
}
