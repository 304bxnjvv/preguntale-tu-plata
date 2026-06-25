import 'package:shared_preferences/shared_preferences.dart';

/// Persiste el conjunto de keys de alertas que el usuario ya vio.
/// Guarda en SharedPreferences con la clave `alertas_seen_keys`.
class AlertasSeen {
  static const _prefsKey = 'alertas_seen_keys';

  /// Devuelve el conjunto de keys ya vistas.
  Future<Set<String>> seenKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? [];
    return list.toSet();
  }

  /// Marca las keys dadas como vistas.
  Future<void> markSeen(Iterable<String> keys) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_prefsKey) ?? [];
    final merged = {...existing, ...keys};
    await prefs.setStringList(_prefsKey, merged.toList());
  }
}
