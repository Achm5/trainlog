import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:trainlog/data/backup.dart';
import 'package:trainlog/data/database.dart';
import 'package:trainlog/data/journal_repo.dart';
import 'package:trainlog/data/nutrition_repo.dart';
import 'package:trainlog/data/planner_repo.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('achm_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  /// Наполняет базу: программа, завершённая сессия, продукт, запись дневника, вес.
  Future<void> fill(AppDatabase db) async {
    final planner = PlannerRepo(db);
    final journal = JournalRepo(db);
    final nutrition = NutritionRepo(db);
    final pid = await planner.createProgram(
        name: 'Цикл', startDate: DateTime.utc(2026, 11, 2), weeksCount: 4, timeLimitMin: 60, weekdays: [1, 4], deloadWeekNo: 4);
    await planner.activate(pid);
    final day = (await planner.daysOf(pid)).first;
    final ex = (await db.select(db.exercises).get()).first;
    final pde = await planner.addExercise(dayId: day.id, exerciseId: ex.id);
    await planner.updatePde(pde, const ProgramDayExercisesCompanion(loadMode: Value('linear'), startWeightKg: Value(60), weeklyStepKg: Value(2.5)));
    final sid = await journal.startPlannedSession(
        dayId: day.id, weekId: (await planner.weeksOf(pid)).first.id, date: DateTime.utc(2026, 11, 2));
    for (final s in await db.select(db.setLogs).get()) {
      await journal.completeAsPlanned(s.id, targetRir: 2);
    }
    await journal.finishSession(sid);
    final prod = await nutrition.saveManualProduct(name: 'Рис; "варёный"', kcal: 116, protein: 2.2, fat: 0.5, carbs: 25);
    await nutrition.addFood(date: DateTime.utc(2026, 11, 2), meal: 'lunch', product: (await nutrition.product(prod))!, grams: 200);
    await nutrition.setWeight(DateTime.utc(2026, 11, 2), 81.4);
    await (db.update(db.settings)).write(const SettingsCompanion(name: Value('Алексей'), heightCm: Value(180)));
  }

  /// Снимок содержимого всех таблиц (без служебных меток времени).
  Future<Map<String, List<Map<String, Object?>>>> dump(AppDatabase db) async {
    final out = <String, List<Map<String, Object?>>>{};
    for (final t in db.allTables) {
      final rows = await db.customSelect('SELECT * FROM "${t.actualTableName}" ORDER BY rowid').get();
      out[t.actualTableName] = [
        for (final r in rows) Map.of(r.data)..remove('updated_at'),
      ];
    }
    return out;
  }

  test('экспорт → импорт возвращает те же данные', () async {
    final a = AppDatabase.memory();
    await fill(a);
    final before = await dump(a);
    final file = File('${dir.path}/backup.sqlite');
    await BackupService(a).exportTo(file);
    expect(file.lengthSync(), greaterThan(4096));

    // Импорт в другую базу с собственными данными: они полностью заменяются.
    final b = AppDatabase.memory();
    await NutritionRepo(b).saveManualProduct(name: 'Лишний продукт', kcal: 1, protein: 0, fat: 0, carbs: 0);
    await (b.delete(b.exercises)..where((e) => e.name.equals('Скручивания'))).go();
    await BackupService(b).importFrom(file);
    expect(await dump(b), before);
    // Внешние ключи снова включены, база рабочая.
    expect((await b.customSelect('PRAGMA foreign_keys').getSingle()).data.values.first, 1);
    expect((await b.getSettings()).name, 'Алексей');
    await NutritionRepo(b).setWeight(DateTime.utc(2026, 11, 3), 81.0);

    // Исходная база после экспорта не изменилась.
    expect(await dump(a), before);
    await a.close();
    await b.close();
  });

  test('импорт отклоняет посторонние файлы и не трогает данные', () async {
    final db = AppDatabase.memory();
    await fill(db);
    final before = await dump(db);
    final text = File('${dir.path}/notes.sqlite')..writeAsStringSync('это не база данных');
    await expectLater(BackupService(db).importFrom(text), throwsA(isA<BackupException>()));
    final foreign = File('${dir.path}/foreign.sqlite');
    final other = AppDatabase.file(foreign);
    await other.customStatement('DROP TABLE food_logs');
    await other.close();
    await expectLater(BackupService(db).importFrom(foreign), throwsA(isA<BackupException>()));
    expect(await dump(db), before);
    await db.close();
  });

  test('миграция со схемы v1 на текущую без потери данных', () async {
    final file = File('${dir.path}/v1.sqlite');
    // База версии 1: та же схема без индексов, появившихся в v2.
    var db = AppDatabase.file(file);
    await fill(db);
    for (final name in AppDatabase.v2Indexes.keys) {
      await db.customStatement('DROP INDEX $name');
    }
    await db.customStatement('PRAGMA user_version = 1');
    final before = await dump(db);
    await db.close();

    db = AppDatabase.file(file);
    expect(await dump(db), before);
    expect((await db.customSelect('PRAGMA user_version').getSingle()).data.values.first, db.schemaVersion);
    final indexes = {
      for (final r in await db.customSelect("SELECT name FROM sqlite_master WHERE type = 'index'").get()) r.read<String>('name'),
    };
    expect(indexes.containsAll(AppDatabase.v2Indexes.keys), isTrue);
    // Ограничения исходной схемы на месте.
    expect(indexes.containsAll(['ux_programs_one_active', 'ux_products_off_barcode']), isTrue);
    await db.close();

    // Резервная копия v1 импортируется в текущую версию.
    final v1Backup = File('${dir.path}/v1-backup.sqlite');
    db = AppDatabase.file(file);
    await BackupService(db).exportTo(v1Backup);
    await db.close();
    final raw = AppDatabase.file(v1Backup);
    await raw.customStatement('PRAGMA user_version = 1');
    await raw.close();
    final target = AppDatabase.memory();
    await BackupService(target).importFrom(v1Backup);
    expect(await dump(target), before);
    await target.close();
  });

  test('CSV журнала и дневника', () async {
    final db = AppDatabase.memory();
    await fill(db);
    final journal = await BackupService(db).journalCsv();
    final lines = journal.trim().split('\n');
    expect(journal.codeUnitAt(0), 0xFEFF); // BOM для Excel
    expect(lines.first, startsWith('Дата;Сессия;Упражнение;Подход'));
    expect(lines.length, 1 + 3); // три плановых подхода
    expect(lines[1], contains('2026-11-02'));
    expect(lines[1], contains(';60;8;60;8;2;done;нет;'));
    final diary = await BackupService(db).diaryCsv();
    expect(diary, contains('2026-11-02;Обед;"Рис; ""варёный""";200;232;4,4;1;50'));
    await db.close();
  });
}
