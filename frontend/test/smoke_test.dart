import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:preguntale_tu_plata/router.dart';
import 'package:preguntale_tu_plata/providers/auth_provider.dart';

void main() {
  testWidgets('sin sesión arranca en el login', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        isLoggedInProvider.overrideWithValue(false),
        authStateProvider.overrideWith((ref) => const Stream.empty()),
      ],
      child: Consumer(builder: (context, ref, _) {
        return MaterialApp.router(routerConfig: ref.watch(routerProvider));
      }),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Entrar'), findsWidgets);
  });
}
