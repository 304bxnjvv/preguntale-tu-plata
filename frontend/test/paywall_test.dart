import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:preguntale_tu_plata/screens/paywall_screen.dart';

void main() {
  testWidgets('PaywallScreen muestra precio y beneficios', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: PaywallScreen()),
      ),
    );
    await tester.pump();

    expect(find.textContaining('hazte premium'), findsOneWidget);
    expect(find.textContaining('3.990'), findsOneWidget);
    expect(find.textContaining('chat ilimitado'), findsOneWidget);
    expect(find.text('suscribirme'), findsOneWidget);
    expect(find.text('ahora no'), findsOneWidget);
  });
}
