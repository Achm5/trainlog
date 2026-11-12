import 'dart:io';

import 'package:drift/drift.dart';

import '../domain/dates.dart';
import '../domain/nutrition.dart';
import 'database.dart';

class BackupException implements Exception {
  BackupException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Резервные копии: копия .sqlite, импорт с заменой данных, выгрузки в CSV.
class BackupService {
  BackupService(this.db);
  final AppDatabase db;

  static String fileName(DateTime now) =>
      'achm-backup-${ymd(now)}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.sqlite';

  /// Пишет целостную копию всей базы в файл.
  Future<void> exportTo(File target) async {
    if (await target.exists()) await target.delete();
    await db.customStatement('VACUUM INTO ?', [target.path]);
  }

  /// Заменяет все данные содержимым резервной копии. Копия старой версии схемы сначала мигрируется.
  Future<void> importFrom(File source) async {
    final header = await source.openRead(0, 16).fold<List<int>>([], (a, b) => a..addAll(b));
    if (String.fromCharCodes(header.take(15)) != 'SQLite format 3') {
      throw BackupException('Файл не является резервной копией приложения.');
    }
    // Работаем с временной копией: исходный файл не меняется.
    final temp = File('${source.path}.import-${DateTime.now().microsecondsSinceEpoch}');
    await source.copy(temp.path);
    try {
      await db.customStatement('ATTACH DATABASE ? AS src', [temp.path]);
      final int version;
      final Set<String> tables;
      try {
        version = (await db.customSelect('PRAGMA src.user_version').getSingle()).data.values.first as int;
        tables = {
          for (final r in await db.customSelect("SELECT name FROM src.sqlite_master WHERE type = 'table'").get())
            r.read<String>('name'),
        };
      } finally {
        await db.customStatement('DETACH DATABASE src');
      }
      if (!tables.containsAll(['settings', 'set_logs', 'food_logs', 'exercises'])) {
        throw BackupException('В файле нет таблиц приложения — это не резервная копия.');
      }
      if (version > db.schemaVersion) {
        throw BackupException('Копия сделана более новой версией приложения. Обновите приложение и повторите импорт.');
      }
      if (version < db.schemaVersion) {
        final upgraded = AppDatabase.file(temp);
        try {
          await upgraded.getSettings(); // открытие выполняет миграции
        } finally {
          await upgraded.close();
        }
      }

      await db.customStatement('ATTACH DATABASE ? AS src', [temp.path]);
      await db.customStatement('PRAGMA foreign_keys = OFF');
      try {
        await db.transaction(() async {
          for (final t in db.allTables) {
            final name = t.actualTableName;
            final srcCols = {
              for (final r in await db.customSelect('PRAGMA src.table_info("$name")').get()) r.read<String>('name'),
            };
            final cols = [for (final c in t.$columns) if (srcCols.contains(c.name)) '"${c.name}"'].join(', ');
            await db.customStatement('DELETE FROM main."$name"');
            if (cols.isNotEmpty) {
              await db.customStatement('INSERT INTO main."$name" ($cols) SELECT $cols FROM src."$name"');
            }
          }
        });
      } finally {
        await db.customStatement('PRAGMA foreign_keys = ON');
        await db.customStatement('DETACH DATABASE src');
      }
      db.markTablesUpdated(db.allTables);
    } on BackupException {
      rethrow;
    } catch (e) {
      throw BackupException('Не удалось прочитать резервную копию: $e');
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }

  static String _cell(Object? v) {
    if (v == null) return '';
    final s = v is double
        ? (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString().replaceAll('.', ','))
        : v.toString();
    return s.contains(RegExp('[;"\\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  static String _csv(List<String> header, Iterable<List<Object?>> rows) {
    final b = StringBuffer('﻿')..writeln(header.join(';'));
    for (final r in rows) {
      b.writeln(r.map(_cell).join(';'));
    }
    return b.toString();
  }

  /// Журнал тренировок: строка на подход.
  Future<String> journalCsv() async {
    final q = db.select(db.setLogs).join([
      innerJoin(db.sessionExercises, db.sessionExercises.id.equalsExp(db.setLogs.sessionExerciseId)),
      innerJoin(db.workoutSessions, db.workoutSessions.id.equalsExp(db.sessionExercises.sessionId)),
      innerJoin(db.exercises, db.exercises.id.equalsExp(db.sessionExercises.exerciseId)),
    ])
      ..orderBy([
        OrderingTerm.asc(db.workoutSessions.date),
        OrderingTerm.asc(db.workoutSessions.id),
        OrderingTerm.asc(db.sessionExercises.sortOrder),
        OrderingTerm.asc(db.setLogs.setNo),
      ]);
    final rows = await q.get();
    return _csv(
      ['Дата', 'Сессия', 'Упражнение', 'Подход', 'Разминка', 'План, кг', 'План, повторы', 'Вес, кг', 'Повторы', 'RIR',
        'Статус', 'Вес снижен', '1ПМ, кг', 'Заметка'],
      rows.map((r) {
        final s = r.readTable(db.setLogs);
        final ws = r.readTable(db.workoutSessions);
        return [
          ws.date, ws.id, r.readTable(db.exercises).name, s.setNo, s.isWarmup ? 'да' : 'нет', s.plannedWeightKg,
          s.plannedReps, s.weightKg, s.reps, s.rir, s.status, s.weightReduced ? 'да' : 'нет',
          s.e1rmKg == null ? null : (s.e1rmKg! * 100).round() / 100, s.note,
        ];
      }),
    );
  }

  /// Дневник питания: строка на запись.
  Future<String> diaryCsv() async {
    final q = db.select(db.foodLogs).join([
      leftOuterJoin(db.products, db.products.id.equalsExp(db.foodLogs.productId)),
    ])
      ..orderBy([OrderingTerm.asc(db.foodLogs.date), OrderingTerm.asc(db.foodLogs.id)]);
    final rows = await q.get();
    double r1(double v) => (v * 10).round() / 10;
    return _csv(
      ['Дата', 'Приём пищи', 'Продукт', 'Граммы', 'Ккал', 'Белки, г', 'Жиры, г', 'Углеводы, г'],
      rows.map((r) {
        final f = r.readTable(db.foodLogs);
        return [
          f.date, mealLabels[f.meal] ?? f.meal, r.readTableOrNull(db.products)?.name ?? 'Продукт удалён',
          r1(f.grams), r1(f.kcal), r1(f.proteinG), r1(f.fatG), r1(f.carbsG),
        ];
      }),
    );
  }
}
