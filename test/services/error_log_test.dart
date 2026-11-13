import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trainlog/services/error_log.dart';

void main() {
  test('запись: время, место, ошибка, верх стека', () {
    final stack = StackTrace.fromString([for (var i = 0; i < 30; i++) '#$i frame'].join('\n'));
    final e = formatLogEntry(DateTime(2026, 11, 13, 9, 5, 7), 'закрытие недели', StateError('нет данных'), stack);
    final lines = e.split('\n');
    expect(lines.first, '2026-11-13 09:05:07 · закрытие недели');
    expect(lines[1], contains('нет данных'));
    expect(lines.length, 2 + 12);
    expect(formatLogEntry(DateTime(2026), 'x', 'e' * 5000, null).length, lessThan(2100));
  });

  test('старые записи вытесняются при превышении размера', () {
    var text = '';
    for (var i = 0; i < 10; i++) {
      text = appendLogEntry(text, 'запись $i ${'x' * 20}', maxChars: 120);
    }
    expect(text.length, lessThanOrEqualTo(120));
    expect(text, contains('запись 9'));
    expect(text, isNot(contains('запись 0')));
    expect(text, startsWith('запись'));
    expect(logEntriesCount(text), greaterThan(1));
    expect(logEntriesCount(''), 0);
    // Одна запись длиннее предела — остаётся её хвост.
    expect(appendLogEntry('', 'y' * 500, maxChars: 100).length, 100);
  });

  test('файл: запись, чтение, очистка; до init ничего не падает', () {
    final dir = Directory.systemTemp.createTempSync('achm_log');
    ErrorLog.instance = null;
    ErrorLog.record('тест', 'до init');
    ErrorLog.init(File('${dir.path}/errors.log'));
    ErrorLog.record('экран', const FormatException('плохой ввод'), StackTrace.current);
    ErrorLog.record('экран', 'вторая');
    final text = ErrorLog.instance!.read();
    expect(logEntriesCount(text), 2);
    expect(text, contains('плохой ввод'));
    ErrorLog.instance!.clear();
    expect(ErrorLog.instance!.read(), '');
    ErrorLog.instance = null;
    dir.deleteSync(recursive: true);
  });
}
