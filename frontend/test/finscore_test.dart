import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:preguntale_tu_plata/services/api_service.dart';
import 'package:preguntale_tu_plata/providers/data_providers.dart';
import 'package:preguntale_tu_plata/widgets/finscore_card.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────

Map<String, dynamic> _sampleJson({
  int score = 72,
  String nivel = 'vas bien',
  String resumen = 'Tus finanzas van bien este mes.',
  String signo = '+',
}) =>
    {
      'score': score,
      'nivel': nivel,
      'resumen': resumen,
      'factores': [
        {'texto': 'Ahorraste más que el mes pasado', 'signo': signo},
      ],
      'tasa_ahorro': 0.18,
    };

// ── Model tests ────────────────────────────────────────────────────────────────

void main() {
  group('FinScore.fromJson', () {
    test('parsea todos los campos correctamente', () {
      final fs = FinScore.fromJson(_sampleJson());
      expect(fs.score, 72);
      expect(fs.nivel, 'vas bien');
      expect(fs.resumen, 'Tus finanzas van bien este mes.');
      expect(fs.tasaAhorro, 0.18);
      expect(fs.factores.length, 1);
    });

    test('parsea factores con signo + y -', () {
      final fs = FinScore.fromJson({
        'score': 45,
        'nivel': 'ojo',
        'resumen': 'Cuidado con los gastos.',
        'factores': [
          {'texto': 'Buen ahorro', 'signo': '+'},
          {'texto': 'Gastos altos en ocio', 'signo': '-'},
        ],
        'tasa_ahorro': 0.05,
      });
      expect(fs.factores[0].signo, '+');
      expect(fs.factores[1].signo, '-');
      expect(fs.factores[1].texto, 'Gastos altos en ocio');
    });

    test('parsea nivel alerta', () {
      final fs = FinScore.fromJson(_sampleJson(score: 20, nivel: 'alerta'));
      expect(fs.score, 20);
      expect(fs.nivel, 'alerta');
    });

    test('parsea nivel sin datos con score 0', () {
      final fs = FinScore.fromJson(_sampleJson(score: 0, nivel: 'sin datos', resumen: ''));
      expect(fs.nivel, 'sin datos');
    });
  });

  // ── API method ────────────────────────────────────────────────────────────────

  group('ApiService.getFinScore', () {
    test('manda Bearer token, ruta correcta y parsea respuesta', () async {
      late http.Request captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode(_sampleJson()),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final api = ApiService(client: mock, token: () => 'MYTOKEN', baseUrl: 'http://x/api/v1');
      final fs = await api.getFinScore();

      expect(captured.headers['Authorization'], 'Bearer MYTOKEN');
      expect(captured.url.path, endsWith('/insights/finscore'));
      expect(fs.score, 72);
      expect(fs.nivel, 'vas bien');
    });

    test('lanza ApiException en error 500', () async {
      final mock = MockClient((req) async => http.Response('Error', 500));
      final api = ApiService(client: mock, token: () => 't', baseUrl: 'http://x/api/v1');
      expect(() => api.getFinScore(), throwsA(isA<ApiException>()));
    });

    test('lanza ApiException en error 401', () async {
      final mock = MockClient((req) async => http.Response('Unauthorized', 401));
      final api = ApiService(client: mock, token: () => 't', baseUrl: 'http://x/api/v1');
      expect(() => api.getFinScore(), throwsA(isA<ApiException>()));
    });
  });

  // ── Widget tests ──────────────────────────────────────────────────────────────

  group('FinScoreCard widget', () {
    Widget wrap(FinScore fs) => ProviderScope(
          overrides: [
            finScoreProvider.overrideWith((ref) async => fs),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: FinScoreCard(data: fs),
            ),
          ),
        );

    testWidgets('muestra el score número correctamente', (tester) async {
      final fs = FinScore.fromJson(_sampleJson(score: 72));
      await tester.pumpWidget(wrap(fs));
      await tester.pump();
      expect(find.text('72'), findsOneWidget);
    });

    testWidgets('muestra el resumen', (tester) async {
      final fs = FinScore.fromJson(_sampleJson());
      await tester.pumpWidget(wrap(fs));
      await tester.pump();
      expect(find.textContaining('Tus finanzas van bien'), findsOneWidget);
    });

    testWidgets('muestra el factor con texto', (tester) async {
      final fs = FinScore.fromJson(_sampleJson());
      await tester.pumpWidget(wrap(fs));
      await tester.pump();
      expect(find.textContaining('Ahorraste más'), findsOneWidget);
    });

    testWidgets('muestra nivel badge OJO en nivel ojo', (tester) async {
      final fs = FinScore.fromJson(_sampleJson(score: 50, nivel: 'ojo'));
      await tester.pumpWidget(wrap(fs));
      await tester.pump();
      expect(find.textContaining('OJO'), findsOneWidget);
    });

    testWidgets('muestra nivel badge ALERTA en nivel alerta', (tester) async {
      final fs = FinScore.fromJson(_sampleJson(score: 20, nivel: 'alerta'));
      await tester.pumpWidget(wrap(fs));
      await tester.pump();
      expect(find.textContaining('ALERTA'), findsOneWidget);
    });
  });
}
