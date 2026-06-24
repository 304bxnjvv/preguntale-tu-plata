import 'package:flutter_test/flutter_test.dart';
import 'package:preguntale_tu_plata/router.dart';

void main() {
  group('authRedirect', () {
    test('sin sesión en /dashboard -> /login', () {
      expect(authRedirect(false, '/dashboard'), '/login');
    });
    test('con sesión en /login -> /dashboard', () {
      expect(authRedirect(true, '/login'), '/dashboard');
    });
    test('sin sesión en /login -> no redirige', () {
      expect(authRedirect(false, '/login'), isNull);
    });
    test('con sesión en /dashboard -> no redirige', () {
      expect(authRedirect(true, '/dashboard'), isNull);
    });
  });
}
