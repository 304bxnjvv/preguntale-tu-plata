import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Singleton compartido entre main.dart y cualquier pantalla que llame a NotifService.
/// Garantiza que init() y agendarVencimiento() usen la misma instancia de plugin.
final notifService = NotifService();

/// Servicio de notificaciones locales — solo móvil.
/// Todas las operaciones son no-op si [kIsWeb] o si el plugin no está disponible.
class NotifService {
  static const _channelId = 'tarjeta_vencimiento';
  static const _channelName = 'Vencimiento tarjeta';
  static const _notifId = 1;

  final FlutterLocalNotificationsPlugin _plugin;

  NotifService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Inicializa el plugin. No-op en web o si el plugin falla (CI/test).
  Future<void> init() async {
    if (kIsWeb) return;
    try {
      tz_data.initializeTimeZones();
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings();
      const linuxSettings = LinuxInitializationSettings(defaultActionName: 'Open');
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
      );
      await _plugin.initialize(initSettings);
    } catch (_) {
      // En entornos CI/test el plugin no está disponible — ignorar.
    }
  }

  /// Agenda una notificación local 3 días antes de [fecha].
  /// Cancela cualquier notificación anterior del mismo slot.
  /// No-op si [kIsWeb], o si la fecha de disparo ya pasó, o si el plugin falla.
  Future<void> agendarVencimiento(DateTime fecha, double monto) async {
    if (kIsWeb) return;

    final triggerDate = fecha.subtract(const Duration(days: 3));
    final now = DateTime.now();

    try {
      await _plugin.cancel(_notifId);
    } catch (_) {}

    if (triggerDate.isBefore(now)) return;

    final montoFmt = _formatCLP(monto);

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Recordatorio de vencimiento de tarjeta de crédito',
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      final tzTrigger = tz.TZDateTime.from(triggerDate, tz.local);
      await _plugin.zonedSchedule(
        _notifId,
        'Tu tarjeta vence en 3 días',
        'Tienes $montoFmt pendiente de pago',
        tzTrigger,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      // En entornos CI/test o web el plugin puede no estar disponible — ignorar.
    }
  }

  static String _formatCLP(double amount) {
    final str = amount.toStringAsFixed(0);
    final buffer = StringBuffer('\$');
    final len = str.length;
    for (var i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
