import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:preguntale_tu_plata/screens/chat_screen.dart';
import 'package:preguntale_tu_plata/providers/data_providers.dart';
import 'package:preguntale_tu_plata/models/chat_message.dart';

void main() {
  testWidgets('muestra mensajes del historial previo', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        chatHistoryProvider.overrideWith((ref) async => const [
              ChatMessage(role: 'user', content: 'cuanto gaste este mes'),
              ChatMessage(role: 'assistant', content: 'Gastaste 45000 en total'),
            ]),
      ],
      child: const MaterialApp(home: ChatScreen()),
    ));

    // Let initState fire and history load
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('cuanto gaste este mes'), findsOneWidget);
    expect(find.text('Gastaste 45000 en total'), findsOneWidget);
  });

  testWidgets('muestra estado vacío cuando historial está vacío', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        chatHistoryProvider.overrideWith((ref) async => const <ChatMessage>[]),
      ],
      child: const MaterialApp(home: ChatScreen()),
    ));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('pregúntame lo que quieras'), findsOneWidget);
  });
}
