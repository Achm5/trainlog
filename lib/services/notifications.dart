import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Локальные уведомления: сигнал окончания отдыха (работает при свёрнутом приложении).
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  static const _restId = 1;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// Запрашивает разрешение на уведомления (Android 13+). Вызывается при первом запуске таймера.
  Future<void> requestPermission() async {
    if (!_ready) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}
  }

  Future<void> scheduleRestEnd(DateTime at) async {
    if (!_ready) return;
    try {
      await _plugin.zonedSchedule(
        id: _restId,
        title: 'Отдых окончен',
        body: 'Пора делать следующий подход',
        scheduledDate: tz.TZDateTime.from(at, tz.UTC),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'rest_timer',
            'Таймер отдыха',
            channelDescription: 'Сигнал об окончании отдыха между подходами',
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: true,
            category: AndroidNotificationCategory.alarm,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {}
  }

  Future<void> cancelRest() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _restId);
    } catch (_) {}
  }
}
