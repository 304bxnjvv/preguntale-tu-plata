import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Emite cada cambio de sesión (login, logout, refresh).
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// True si hay una sesión activa. Se recalcula cuando authStateProvider emite.
final isLoggedInProvider = Provider<bool>((ref) {
  ref.watch(authStateProvider);
  return Supabase.instance.client.auth.currentSession != null;
});
