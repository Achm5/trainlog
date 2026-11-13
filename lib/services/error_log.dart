import 'dart:io';

/// Журнал ошибок на телефоне: файл рядом с базой, никуда не отправляется.
/// Нужен, чтобы после сбоя можно было посмотреть причину и переслать её вручную.

const errorLogMaxChars = 60000;
const _separator = '\n----\n';

/// Запись журнала: время, место, ошибка и верх стека (не больше [maxStackLines] строк).
String formatLogEntry(DateTime at, String where, Object error, StackTrace? stack, {int maxStackLines = 12}) {
  final lines = stack == null
      ? const <String>[]
      : stack.toString().split('\n').where((l) => l.trim().isNotEmpty).take(maxStackLines).toList();
  final message = error.toString();
  return [
    '${at.toIso8601String().substring(0, 19).replaceFirst('T', ' ')} · $where',
    message.length > 2000 ? '${message.substring(0, 2000)}…' : message,
    ...lines,
  ].join('\n');
}

/// Добавляет запись в конец и обрезает самые старые записи, чтобы текст не превышал [maxChars].
String appendLogEntry(String existing, String entry, {int maxChars = errorLogMaxChars}) {
  var text = existing.isEmpty ? entry : '$existing$_separator$entry';
  while (text.length > maxChars) {
    final cut = text.indexOf(_separator);
    if (cut < 0) return text.substring(text.length - maxChars);
    text = text.substring(cut + _separator.length);
  }
  return text;
}

int logEntriesCount(String text) => text.trim().isEmpty ? 0 : _separator.allMatches(text).length + 1;

class ErrorLog {
  ErrorLog(this.file);
  final File file;

  /// Журнал приложения; до вызова [init] записи не сохраняются.
  static ErrorLog? instance;

  static void init(File file) => instance = ErrorLog(file);

  /// Записывает ошибку; сам никогда не бросает исключений.
  static void record(String where, Object error, [StackTrace? stack]) {
    try {
      instance?.add(formatLogEntry(DateTime.now(), where, error, stack));
    } catch (_) {
      // Журнал ошибок не должен ронять приложение.
    }
  }

  String read() => file.existsSync() ? file.readAsStringSync() : '';

  void add(String entry) => file.writeAsStringSync(appendLogEntry(read(), entry), flush: true);

  void clear() {
    if (file.existsSync()) file.deleteSync();
  }
}
