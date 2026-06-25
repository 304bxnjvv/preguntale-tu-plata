import 'package:shared_preferences/shared_preferences.dart';

/// Persiste el timestamp de la última vez que el usuario vio/descartó el
/// resumen semanal.  Muestra de nuevo cuando pasaron ≥7 días.
class ResumenSeen {
  static const _prefsKey = 'resumen_semanal_last_seen_ms';

  static const _intervalDias = 7;

  /// Devuelve true si nunca se mostró o pasaron ≥7 días desde el último descarte.
  ///
  /// [now] y [lastSeenOverride] son sólo para testear sin SharedPreferences reales.
  Future<bool> debeMostrar({DateTime? now, int? lastSeenOverride}) async {
    final efectivoNow = now ?? DateTime.now();

    final int? lastMs;
    if (lastSeenOverride != null) {
      lastMs = lastSeenOverride;
    } else {
      final prefs = await SharedPreferences.getInstance();
      lastMs = prefs.getInt(_prefsKey);
    }

    if (lastMs == null) return true;
    final diff = efectivoNow.millisecondsSinceEpoch - lastMs;
    return diff >= const Duration(days: _intervalDias).inMilliseconds;
  }

  /// Guarda el timestamp actual (o el inyectado) como "última vez visto".
  Future<void> marcarVisto({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final ms = (now ?? DateTime.now()).millisecondsSinceEpoch;
    await prefs.setInt(_prefsKey, ms);
  }
}
