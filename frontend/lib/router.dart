import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/upload_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/paywall_screen.dart';
import 'screens/consent_screen.dart';

/// Función pura: dado el estado de sesión y la ubicación actual, devuelve la
/// ruta a la que redirigir, o null si no hay que redirigir.
String? authRedirect(bool loggedIn, String location) {
  final goingToLogin = location == '/login';
  if (!loggedIn && !goingToLogin) return '/login';
  if (loggedIn && goingToLogin) return '/dashboard';
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final loggedIn = ref.read(isLoggedInProvider);
      return authRedirect(loggedIn, state.matchedLocation);
    },
    refreshListenable: _AuthRefresh(ref),
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
      GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),
      GoRoute(path: '/upload', builder: (_, __) => const UploadScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/ajustes', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/suscripcion', builder: (_, __) => const PaywallScreen()),
      GoRoute(path: '/suscripcion/consentimiento', builder: (_, __) => const ConsentScreen()),
    ],
  );
});

/// Hace que go_router reevalúe el redirect cuando cambia el estado de auth.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}
