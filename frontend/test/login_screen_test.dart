import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:preguntale_tu_plata/screens/login_screen.dart';

void main() {
  testWidgets('muestra error si el email es inválido', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: LoginScreen()),
    ));

    await tester.enterText(find.byKey(const Key('email')), 'no-es-email');
    await tester.enterText(find.byKey(const Key('password')), '123456');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pump();

    expect(find.text('ingresa un email válido'), findsOneWidget);
  });

  testWidgets('muestra error si la contraseña es muy corta', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: LoginScreen()),
    ));

    await tester.enterText(find.byKey(const Key('email')), 'a@b.cl');
    await tester.enterText(find.byKey(const Key('password')), '123');
    await tester.tap(find.byKey(const Key('submit')));
    await tester.pump();

    expect(find.text('la contraseña debe tener al menos 6 caracteres'), findsOneWidget);
  });
}
