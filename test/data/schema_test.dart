import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:trainlog/data/database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  test('схема: 22 таблицы ТЗ и таблица воды, внешние ключи включены', () async {
    expect(db.allTables.length, 23);
    final fk = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(fk.data.values.first, 1);
  });

  test('сиды: настройки, группы мышц, упражнения с вариациями, три правила', () async {
    final s = await db.getSettings();
    expect(s.id, 1);
    expect(s.weightRoundingKg, 2.5);
    expect(s.kcalPerKg, 7700);
    expect((await db.select(db.muscleGroups).get()).length, greaterThanOrEqualTo(12));
    final ex = await db.select(db.exercises).get();
    expect(ex.where((e) => e.kind == 'isolation').length, inInclusiveRange(15, 25));
    for (final name in ['Жим лёжа', 'Приседания со штангой', 'Становая тяга', 'Жим стоя', 'Тяга штанги в наклоне', 'Подтягивания']) {
      final base = ex.singleWhere((e) => e.name == name);
      expect(ex.where((e) => e.baseExerciseId == base.id), isNotEmpty, reason: name);
    }
    final bench = ex.singleWhere((e) => e.name == 'Жим лёжа');
    final shares = await (db.select(db.exerciseMuscles)..where((m) => m.exerciseId.equals(bench.id))).get();
    expect(shares.map((m) => m.share).toList()..sort(), [0.5, 0.5, 1.0]);
    final rules = await db.select(db.rules).get();
    expect(rules.map((r) => r.code).toSet(),
        {'TWO_RED_IN_ROW', 'E1RM_PLATEAU', 'EARLY_DELOAD', 'REPS_CUT', 'AUTO_PROGRESSION'});
    expect({for (final r in rules) r.code: r.priority},
        {'TWO_RED_IN_ROW': 100, 'E1RM_PLATEAU': 50, 'EARLY_DELOAD': 80, 'REPS_CUT': 90, 'AUTO_PROGRESSION': 60});
  });

  test('settings — ровно одна строка', () async {
    expect(
      () => db.into(db.settings).insert(SettingsCompanion.insert(id: const Value(2))),
      throwsA(anything),
    );
  });

  test('не более одной активной программы', () async {
    Future<int> add(String status) => db.into(db.programs).insert(ProgramsCompanion.insert(
        name: 'P', startDate: '2026-11-16', weeksCount: 5, status: Value(status)));
    await add('active');
    await add('draft');
    await add('archived');
    expect(() => add('active'), throwsA(anything));
  });

  test('упражнение с записями в журнале удалить нельзя', () async {
    final ex = (await db.select(db.exercises).get()).first;
    final sid = await db.into(db.workoutSessions).insert(WorkoutSessionsCompanion.insert(
        date: '2026-11-12', startedAt: DateTime.now().millisecondsSinceEpoch));
    await db.into(db.sessionExercises).insert(SessionExercisesCompanion.insert(sessionId: sid, exerciseId: ex.id));
    expect(() => (db.delete(db.exercises)..where((e) => e.id.equals(ex.id))).go(), throwsA(anything));
    await (db.update(db.exercises)..where((e) => e.id.equals(ex.id))).write(const ExercisesCompanion(isArchived: Value(true)));
    expect((await (db.select(db.exercises)..where((e) => e.id.equals(ex.id))).getSingle()).isArchived, isTrue);
  });

  test('ограничения set_logs: RIR 0–5 и уникальный номер подхода', () async {
    final ex = (await db.select(db.exercises).get()).first;
    final sid = await db.into(db.workoutSessions).insert(WorkoutSessionsCompanion.insert(
        date: '2026-11-12', startedAt: 0));
    final seId = await db.into(db.sessionExercises).insert(SessionExercisesCompanion.insert(sessionId: sid, exerciseId: ex.id));
    await db.into(db.setLogs).insert(SetLogsCompanion.insert(sessionExerciseId: seId, setNo: 1, rir: const Value(5)));
    expect(() => db.into(db.setLogs).insert(SetLogsCompanion.insert(sessionExerciseId: seId, setNo: 2, rir: const Value(6))),
        throwsA(anything));
    expect(() => db.into(db.setLogs).insert(SetLogsCompanion.insert(sessionExerciseId: seId, setNo: 1)), throwsA(anything));
    await (db.delete(db.workoutSessions)..where((s) => s.id.equals(sid))).go();
    expect(await db.select(db.setLogs).get(), isEmpty);
  });

  test('updated_at обновляется триггером', () async {
    await db.customStatement('UPDATE settings SET updated_at = 1, created_at = 1');
    await (db.update(db.settings)).write(const SettingsCompanion(name: Value('Алексей')));
    expect((await db.getSettings()).updatedAt, greaterThan(1));
  });
}
