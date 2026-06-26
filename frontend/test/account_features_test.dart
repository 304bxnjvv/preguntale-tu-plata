import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:preguntale_tu_plata/services/api_service.dart';
import 'package:preguntale_tu_plata/screens/login_screen.dart';
import 'package:preguntale_tu_plata/screens/legal_screen.dart';

// ── ApiService nuevos métodos ─────────────────────────────────────────────────

void main() {
  group('ApiService.exportarDatos', () {
    test('GET /account/export devuelve body como String', () async {
      final payload = jsonEncode({'email': 'a@b.cl', 'transacciones': []});
      final mock = MockClient((req) async {
        expect(req.method, 'GET');
        expect(req.url.path, endsWith('/account/export'));
        expect(req.headers['Authorization'], 'Bearer token-test');
        return http.Response(
          payload,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final api =
          ApiService(client: mock, token: () => 'token-test', baseUrl: 'http://x/api/v1');

      final result = await api.exportarDatos();
      expect(result, payload);
    });

    test('lanza ApiException en status != 200', () async {
      final mock = MockClient((req) async => http.Response('Unauthorized', 401));
      final api =
          ApiService(client: mock, token: () => 't', baseUrl: 'http://x/api/v1');

      expect(() => api.exportarDatos(), throwsA(isA<ApiException>()));
    });
  });

  group('ApiService.eliminarCuenta', () {
    test('DELETE /account devuelve map con datos_eliminados y auth_eliminada', () async {
      final mock = MockClient((req) async {
        expect(req.method, 'DELETE');
        expect(req.url.path, endsWith('/account'));
        return http.Response(
          jsonEncode({'datos_eliminados': true, 'auth_eliminada': true}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final api =
          ApiService(client: mock, token: () => 't', baseUrl: 'http://x/api/v1');

      final result = await api.eliminarCuenta();
      expect(result['datos_eliminados'], isTrue);
      expect(result['auth_eliminada'], isTrue);
    });

    test('lanza ApiException en status != 200', () async {
      final mock = MockClient((req) async => http.Response('Error', 500));
      final api =
          ApiService(client: mock, token: () => 't', baseUrl: 'http://x/api/v1');

      expect(() => api.eliminarCuenta(), throwsA(isA<ApiException>()));
    });

    test('Bearer token incluido en DELETE /account', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({'datos_eliminados': true, 'auth_eliminada': false}),
          200,
        );
      });
      final api =
          ApiService(client: mock, token: () => 'mi-token', baseUrl: 'http://x/api/v1');

      await api.eliminarCuenta();
      expect(captured.headers['Authorization'], 'Bearer mi-token');
    });
  });

  // ── LegalScreen ──────────────────────────────────────────────────────────────

  group('LegalScreen', () {
    testWidgets('renderiza sin explotar (privacidad)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LegalScreen(doc: 'privacidad'),
        ),
      );
      // pump sin pumpAndSettle para no esperar al rootBundle en test env
      await tester.pump();
      // AppBar debe estar presente
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Política de privacidad'), findsOneWidget);
    });

    testWidgets('renderiza sin explotar (terminos)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LegalScreen(doc: 'terminos'),
        ),
      );
      await tester.pump();
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Términos y condiciones'), findsOneWidget);
    });

    testWidgets('muestra banner "Borrador"', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LegalScreen(doc: 'privacidad'),
        ),
      );
      await tester.pump();
      expect(find.textContaining('Borrador'), findsOneWidget);
    });
  });

  // ── LoginScreen checkbox 18+ ─────────────────────────────────────────────────

  group('LoginScreen consentimiento 18+', () {
    testWidgets('botón "Crear cuenta" deshabilitado sin checkbox marcado', (tester) async {
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ));
      await tester.pump();

      // Switch to register mode
      await tester.tap(find.text('Registrarse'));
      await tester.pump();

      // Fill valid email and password
      await tester.enterText(find.byKey(const Key('email')), 'test@test.cl');
      await tester.enterText(find.byKey(const Key('password')), '123456');
      await tester.pump();

      // Checkbox visible
      expect(find.byKey(const Key('consent_checkbox')), findsOneWidget);

      // Button must be disabled (onPressed == null) because checkbox not checked
      final btn = tester.widget<FilledButton>(find.byKey(const Key('submit')));
      expect(btn.onPressed, isNull);
    });

    testWidgets('botón "Crear cuenta" habilitado después de marcar checkbox', (tester) async {
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ));
      await tester.pump();

      // Switch to register mode
      await tester.tap(find.text('Registrarse'));
      await tester.pump();

      await tester.enterText(find.byKey(const Key('email')), 'test@test.cl');
      await tester.enterText(find.byKey(const Key('password')), '123456');

      // Check the consent checkbox
      await tester.tap(find.byKey(const Key('consent_check')));
      await tester.pump();

      final btn = tester.widget<FilledButton>(find.byKey(const Key('submit')));
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('checkbox NO aparece en modo "Entrar"', (tester) async {
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ));
      await tester.pump();

      // Default is login mode
      expect(find.byKey(const Key('consent_checkbox')), findsNothing);
    });
  });
}
