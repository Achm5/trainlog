import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:trainlog/i18n.dart';

/// Локальные уведомления: сигнал окончания отдыха (работает при свёрнутом приложении).
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  static const _restId = 1;
  static const _workoutId = 2;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_achm')),
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
        title: tr('Отдых окончен'),
        body: tr('Пора делать следующий подход'),
        scheduledDate: tz.TZDateTime.from(at, tz.UTC),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'rest_timer',
            tr('Таймер отдыха'),
            channelDescription: tr('Сигнал об окончании отдыха между подходами'),
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

  /// Постоянное уведомление о ходе тренировки: видно на экране блокировки.
  /// При [restEnd] показывает обратный отсчёт отдыха.
  Future<void> showWorkout({required String title, required String body, DateTime? restEnd}) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: _workoutId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'workout_progress',
            tr('Ход тренировки'),
            channelDescription: tr('Следующий подход и таймер отдыха на экране блокировки'),
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            playSound: false,
            enableVibration: false,
            visibility: NotificationVisibility.public,
            showWhen: restEnd != null,
            when: restEnd?.millisecondsSinceEpoch,
            usesChronometer: restEnd != null,
            chronometerCountDown: restEnd != null,
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> cancelWorkout() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _workoutId);
    } catch (_) {}
  }

  Future<void> cancelRest() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _restId);
    } catch (_) {}
  }
}
