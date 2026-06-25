import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:preguntale_tu_plata/screens/onboarding_screen.dart';
import 'package:preguntale_tu_plata/screens/settings_screen.dart';
import 'package:preguntale_tu_plata/providers/data_providers.dart';
import 'package:preguntale_tu_plata/models/summary.dart';
import 'package:preguntale_tu_plata/models/transaction.dart';
import 'package:preguntale_tu_plata/models/insights.dart';

// Minimal GoRouter-free wrapper that handles push/go calls gracefully.
class _TestApp extends StatelessWidget {
  final Widget child;
  const _TestApp({required this.child});

  @override
  Widget build(BuildContext context) => MaterialApp(home: child);
}

List<Override> _defaultProviders() => [
      summaryProvider.overrideWith((ref) async => const Summary(
            porMoneda: {'CLP': MonedaTotales(ingresos: 1000000, gastos: -80000)},
            gastosPorCategoria: [
              CategoriaTotal(categoria: 'Comida y delivery', total: -45000),
            ],
            gastosPorBanco: [],
          )),
      transactionsProvider.overrideWith((ref) async => const <Transaction>[]),
      suscripcionesProvider.overrideWith(
          (ref) async => const Suscripciones(totalMensual: 0, items: [])),
      comparativoProvider.overrideWith((ref) async => const Comparativo(
            mesActual: '2025-06',
            mesAnterior: '2025-05',
            gastosActual: 0,
            gastosAnterior: 0,
            delta: 0,
          )),
      subscriptionProvider.overrideWith((ref) async => const Subscription(
            estado: 'trial',
            diasRestantes: 28,
            precioClp: 3990,
          )),
    ];

void main() {
  group('OnboardingScreen', () {
    testWidgets('step 1 muestra mensaje de privacidad', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _defaultProviders(),
          child: const _TestApp(child: OnboardingScreen()),
        ),
      );
      await tester.pump();

      expect(find.textContaining('tu privacidad'), findsOneWidget);
      expect(find.textContaining('no le pedimos permiso a tu banco'), findsOneWidget);
      expect(find.text('empezar'), findsOneWidget);
    });

    testWidgets('step 2 aparece al presionar empezar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _defaultProviders(),
          child: const _TestApp(child: OnboardingScreen()),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('empezar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('cuánto crees que'), findsOneWidget);
    });

    testWidgets('step 3 aparece al presionar continuar desde step 2', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _defaultProviders(),
          child: const _TestApp(child: OnboardingScreen()),
        ),
      );
      await tester.pump();

      // Step 1 → 2
      await tester.tap(find.text('empezar'));
      await tester.pumpAndSettle();

      // Step 2 → 3
      await tester.tap(find.text('continuar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('cómo quieres'), findsOneWidget);
      expect(find.text('subir mi cartola'), findsOneWidget);
      expect(find.text('probar con un ejemplo'), findsOneWidget);
    });

    testWidgets('botón saltar siempre visible en pasos 0-2', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _defaultProviders(),
          child: const _TestApp(child: OnboardingScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('saltar'), findsOneWidget);
    });
  });

  group('SettingsScreen', () {
    testWidgets('muestra texto de privacidad', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _defaultProviders(),
          child: const _TestApp(child: SettingsScreen()),
        ),
      );
      await tester.pump();

      expect(find.textContaining('privacidad'), findsWidgets);
      expect(find.textContaining('no le pedimos permiso'), findsOneWidget);
    });

    testWidgets('botón Eliminar mis datos muestra AlertDialog con TextField',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _defaultProviders(),
          child: const _TestApp(child: SettingsScreen()),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Eliminar mis datos'));
      // Use pump instead of pumpAndSettle: the Orb has a repeating animation
      // that prevents pumpAndSettle from ever resolving.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('eliminar mis datos'), findsOneWidget);
      expect(find.text('eliminar todo'), findsOneWidget);
      expect(find.text('cancelar'), findsOneWidget);
      // TextField must be present
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('botón eliminar deshabilitado hasta escribir "borrar"',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _defaultProviders(),
          child: const _TestApp(child: SettingsScreen()),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Eliminar mis datos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Button is disabled initially (null onPressed when text != 'borrar')
      final btnBefore = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'eliminar todo'),
      );
      expect(btnBefore.onPressed, isNull);

      // Type 'borrar'
      await tester.enterText(find.byType(TextField), 'borrar');
      await tester.pump();

      final btnAfter = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'eliminar todo'),
      );
      expect(btnAfter.onPressed, isNotNull);

      // Close dialog to avoid controller leak into next test
      await tester.tap(find.text('cancelar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('cancelar en AlertDialog cierra el diálogo sin eliminar',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _defaultProviders(),
          child: const _TestApp(child: SettingsScreen()),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Eliminar mis datos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('cancelar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog should be gone, button still present
      expect(find.text('Eliminar mis datos'), findsOneWidget);
      expect(find.text('eliminar todo'), findsNothing);
    });
  });
}
