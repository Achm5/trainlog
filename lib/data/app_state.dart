import 'dart:convert';
import 'dart:io';

/// Служебное состояние приложения вне схемы БД (последняя закрытая неделя и т. п.).
abstract class AppStateStore {
  Future<String?> get(String key);
  Future<void> set(String key, String? value);
}

class MemoryAppState implements AppStateStore {
  final _data = <String, String>{};

  @override
  Future<String?> get(String key) async => _data[key];

  @override
  Future<void> set(String key, String? value) async {
    value == null ? _data.remove(key) : _data[key] = value;
  }
}

/// Хранит состояние в небольшом JSON-файле рядом с базой.
class FileAppState implements AppStateStore {
  FileAppState(this.file);
  final File file;
  Map<String, dynamic>? _cache;

  Future<Map<String, dynamic>> _load() async {
    if (_cache != null) return _cache!;
    try {
      _cache = await file.exists() ? jsonDecode(await file.readAsString()) as Map<String, dynamic> : {};
    } catch (_) {
      _cache = {};
    }
    return _cache!;
  }

  @override
  Future<String?> get(String key) async => (await _load())[key] as String?;

  @override
  Future<void> set(String key, String? value) async {
    final data = await _load();
    value == null ? data.remove(key) : data[key] = value;
    await file.writeAsString(jsonEncode(data));
  }
}

const stateLastClosedWeek = 'last_closed_week';
const stateLastBackupAt = 'last_backup_at';
const stateBackupReminderAt = 'backup_reminder_at';
const stateBiometricEnabled = 'biometric_enabled';

/// Предупреждение о перетренированности: '0' — выключено (по умолчанию включено).
const stateOvertrainingWarning = 'overtraining_warning';

/// Неделя, предупреждение по которой скрыто пользователем.
const stateOvertrainingDismissed = 'overtraining_dismissed_week';

/// Уведомление о ходе тренировки на экране блокировки: '0' — выключено (по умолчанию включено).
const stateWorkoutNotification = 'workout_notification';

/// Язык интерфейса: 'ru' или 'en' (если не задан — по языку телефона).
const stateLang = 'lang';

/// Единицы веса: 'kg' или 'lb'.
const stateUnits = 'units';
