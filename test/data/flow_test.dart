import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:trainlog/data/database.dart';
import 'package:trainlog/data/journal_repo.dart';
import 'package:trainlog/data/planner_repo.dart';

void main() {
  late AppDatabase db;
  late PlannerRepo planner;
  late JournalRepo journal;
  setUp(() {
    db = AppDatabase.memory();
    planner = PlannerRepo(db);
    journal = JournalRepo(db);
  });
  tearDown(() => db.close());

  Future<int> exerciseId(String name) async =>
      (await (db.select(db.exercises)..where((e) => e.name.equals(name))).getSingle()).id;

  Future<({int programId, int dayId, int pdeId})> program() async {
    final id = await planner.createProgram(
      name: 'Тест',
      startDate: DateTime.utc(2026, 11, 16),
      weeksCount: 5,
      timeLimitMin: 75,
      weekdays: [1, 3, 5],
      deloadWeekNo: 5,
    );
    final day = (await planner.daysOf(id)).first;
    final pdeId = await planner.addExercise(dayId: day.id, exerciseId: await exerciseId('Жим лёжа'), sets: 4, repsMin: 5, repsMax: 8);
    return (programId: id, dayId: day.id, pdeId: pdeId);
  }

  test('программа: недели, дни, одна разгрузочная неделя', () async {
    final p = await program();
    final weeks = await planner.weeksOf(p.programId);
    expect(weeks.map((w) => w.startDate).toList(),
        ['2026-11-16', '2026-11-23', '2026-11-30', '2026-12-07', '2026-12-14']);
    expect(weeks.where((w) => w.isDeload).single.weekNo, 5);
    expect((await planner.daysOf(p.programId)).map((d) => d.weekday).toList(), [1, 3, 5]);
  });

  test('линейный шаг с округлением вниз и автоматическая разгрузка', () async {
    final p = await program();
    await planner.updatePde(
        p.pdeId, const ProgramDayExercisesCompanion(loadMode: Value('linear'), startWeightKg: Value(80), weeklyStepKg: Value(2)));
    final plans = await planner.plansOf(p.pdeId);
    expect(plans.map((v) => v.plan.weightKg).toList(), [80, 80, 82.5, 85, 75]); // 85 × 0,9 = 76,5 → 75
    expect(plans.last.plan.sets, 2);
    expect(plans.last.plan.targetRir, 4);
    expect(plans.last.plan.repsMin, 5);
  });

  test('ручная правка веса не пересчитывается, сброс возвращает расчёт', () async {
    final p = await program();
    await planner.updatePde(
        p.pdeId, const ProgramDayExercisesCompanion(loadMode: Value('linear'), startWeightKg: Value(80), weeklyStepKg: Value(2.5)));
    var plans = await planner.plansOf(p.pdeId);
    await planner.updatePlan(plans[1].plan.id, const ExerciseWeekPlansCompanion(weightKg: Value(90), isManual: Value(true)));
    plans = await planner.plansOf(p.pdeId);
    expect(plans[1].plan.weightKg, 90);
    await planner.updatePlan(plans[1].plan.id, const ExerciseWeekPlansCompanion(isManual: Value(false)));
    plans = await planner.plansOf(p.pdeId);
    expect(plans[1].plan.weightKg, 82.5);
  });

  test('перенос разгрузки на другую неделю перестраивает план', () async {
    final p = await program();
    await planner.updatePde(
        p.pdeId, const ProgramDayExercisesCompanion(loadMode: Value('linear'), startWeightKg: Value(100), weeklyStepKg: Value(2.5)));
    await planner.setDeloadWeek(p.programId, 3);
    final plans = await planner.plansOf(p.pdeId);
    expect(plans.map((v) => v.plan.weightKg).toList(), [100, 102.5, 90, 105, 107.5]); // 102,5 × 0,9 = 92,25 → 90
    expect(plans[2].plan.sets, 2);
    expect(plans[4].plan.sets, 4);
  });

  test('длительность дня и подсказки при превышении лимита', () async {
    final p = await program();
    final week = (await planner.weeksOf(p.programId)).first;
    expect(await planner.dayDuration(p.dayId, week.id), 4 * (40 + 120) + 600);
    await planner.shortenRest(p.dayId);
    expect(await planner.dayDuration(p.dayId, week.id), 4 * (40 + 90) + 600);
    await planner.removeOneSet(p.pdeId);
    expect(await planner.dayDuration(p.dayId, week.id), 3 * (40 + 90) + 600);
  });

  test('сессия: предзаполнение, статусы, 1ПМ, недельные агрегаты и правка', () async {
    final p = await program();
    await planner.updatePde(
        p.pdeId, const ProgramDayExercisesCompanion(loadMode: Value('linear'), startWeightKg: Value(100), weeklyStepKg: Value(2.5)));
    final week = (await planner.weeksOf(p.programId)).first;
    final sid = await journal.startPlannedSession(dayId: p.dayId, weekId: week.id, date: DateTime.utc(2026, 11, 16));
    expect(await journal.startPlannedSession(dayId: p.dayId, weekId: week.id, date: DateTime.utc(2026, 11, 16)), sid);

    var sets = await db.select(db.setLogs).get();
    expect(sets.length, 4);
    expect(sets.every((s) => s.plannedWeightKg == 100 && s.plannedReps == 5 && s.reps == null), isTrue);

    await journal.completeAsPlanned(sets[0].id, targetRir: 2);
    await journal.saveSet(sets[1].id, weightKg: 97.5, reps: 4, rir: 0);
    await journal.saveSet(sets[2].id, weightKg: 100, reps: 2, rir: 0);
    await journal.skipSet(sets[3].id);
    final warm = await journal.addSet(sets[0].sessionExerciseId, warmup: true);
    await journal.saveSet(warm, weightKg: 60, reps: 10, rir: null);

    sets = await (db.select(db.setLogs)..orderBy([(s) => OrderingTerm.asc(s.setNo)])).get();
    expect(sets.map((s) => s.status).toList(), ['done', 'minor_miss', 'partial', 'skipped', null]);
    expect(sets[1].weightReduced, isTrue);
    expect(sets[0].weightReduced, isFalse);
    expect(sets[0].e1rmKg, closeTo(100 * (1 + 7 / 30), 1e-6)); // RIR учитывается по умолчанию
    expect(sets[4].e1rmKg, isNull);
    final se = await db.select(db.sessionExercises).getSingle();
    expect(se.status, 'partial');

    // До завершения сессии агрегатов нет.
    expect(await db.select(db.weeklyExerciseStats).get(), isEmpty);
    await journal.finishSession(sid);
    var stat = await db.select(db.weeklyExerciseStats).getSingle();
    expect(stat.weekStart, '2026-11-16');
    expect(stat.workSets, 3);
    expect(stat.setsDone, 2);
    expect(stat.setsPartial, 1);
    expect(stat.tonnageKg, 100 * 5 + 97.5 * 4 + 100 * 2);
    expect(stat.bestE1rmKg, closeTo(100 * (1 + 7 / 30), 1e-6));
    final chest = await (db.select(db.muscleGroups)..where((m) => m.name.equals('Грудь'))).getSingle();
    final triceps = await (db.select(db.muscleGroups)..where((m) => m.name.equals('Трицепс'))).getSingle();
    final vol = await db.select(db.weeklyMuscleVolume).get();
    expect(vol.singleWhere((v) => v.muscleGroupId == chest.id).sets, 3);
    expect(vol.singleWhere((v) => v.muscleGroupId == triceps.id).sets, 1.5);

    // Правка прошлой сессии пересчитывает статус и агрегаты.
    await journal.saveSet(sets[2].id, weightKg: 100, reps: 5, rir: 3);
    stat = await db.select(db.weeklyExerciseStats).getSingle();
    expect(stat.setsPartial, 0);
    expect(stat.setsDone, 3);
    expect(stat.bestE1rmKg, closeTo(100 * (1 + 8 / 30), 1e-6));
    expect((await db.select(db.sessionExercises).getSingle()).status, 'minor_miss');
  });

  test('свободная тренировка: статус не считается, в аналитику идёт; дельта к прошлой неделе', () async {
    final squat = await exerciseId('Приседания со штангой');
    Future<void> free(DateTime date, double w) async {
      final sid = await journal.startFreeSession(date);
      final seId = await journal.addExerciseToSession(sid, squat);
      final set = await (db.select(db.setLogs)..where((s) => s.sessionExerciseId.equals(seId))).getSingle();
      await journal.saveSet(set.id, weightKg: w, reps: 5, rir: 0);
      await journal.finishSession(sid);
    }

    await free(DateTime.utc(2026, 11, 3), 100);
    await free(DateTime.utc(2026, 11, 10), 105);
    final sets = await db.select(db.setLogs).get();
    expect(sets.every((s) => s.status == null && s.e1rmKg != null), isTrue);
    final stats = await (db.select(db.weeklyExerciseStats)..orderBy([(s) => OrderingTerm.asc(s.weekStart)])).get();
    expect(stats.map((s) => s.weekStart).toList(), ['2026-11-02', '2026-11-09']);
    expect(stats[0].e1rmDeltaPct, isNull);
    expect(stats[1].e1rmDeltaPct, closeTo(5, 1e-6));
  });

  test('копирование дня: упражнения и план по неделям переносятся в другой день', () async {
    final p = await program();
    await planner.updatePde(
        p.pdeId, const ProgramDayExercisesCompanion(loadMode: Value('linear'), startWeightKg: Value(80), weeklyStepKg: Value(2.5)));
    final days = await planner.daysOf(p.programId);
    final squat = await exerciseId('Приседания со штангой');
    await planner.addExercise(dayId: days[1].id, exerciseId: squat);

    expect(await planner.copyDay(fromDayId: p.dayId, toDayId: days[1].id), 1); // добавить в конец
    var target = await planner.dayExercises(days[1].id);
    expect(target.length, 2);
    expect(target.last.loadMode, 'linear');
    final src = await planner.plansOf(p.pdeId);
    final copy = await planner.plansOf(target.last.id);
    expect(copy.map((v) => (v.plan.sets, v.plan.repsMin, v.plan.weightKg, v.plan.targetRir)).toList(),
        src.map((v) => (v.plan.sets, v.plan.repsMin, v.plan.weightKg, v.plan.targetRir)).toList());

    expect(await planner.copyDay(fromDayId: p.dayId, toDayId: days[2].id, replace: true), 1);
    expect(await planner.copyDay(fromDayId: p.dayId, toDayId: days[1].id, replace: true), 1); // заменить
    target = await planner.dayExercises(days[1].id);
    expect(target.single.exerciseId, isNot(squat));
    // Копия независима от оригинала.
    await planner.removeExercise(p.pdeId);
    expect((await planner.dayExercises(days[1].id)).length, 1);
  });

  test('рекорд 1ПМ: первый подход не рекорд, превышение максимума — рекорд', () async {
    final squat = await exerciseId('Приседания со штангой');
    Future<(int, int)> free(DateTime date) async {
      final sid = await journal.startFreeSession(date);
      final seId = await journal.addExerciseToSession(sid, squat);
      final set = await (db.select(db.setLogs)..where((s) => s.sessionExerciseId.equals(seId))).getSingle();
      return (sid, set.id);
    }

    final (s1, set1) = await free(DateTime.utc(2026, 11, 3));
    expect(await journal.saveSet(set1, weightKg: 100, reps: 5, rir: 0), isNull); // истории ещё нет
    await journal.finishSession(s1);

    final (s2, set2) = await free(DateTime.utc(2026, 11, 10));
    expect(await journal.saveSet(set2, weightKg: 100, reps: 5, rir: 0), isNull); // повтор максимума
    expect(await journal.saveSet(set2, weightKg: 102.5, reps: 5, rir: 0), closeTo(102.5 * (1 + 5 / 30), 1e-6));
    var view = (await journal.watchSessionExercises(s2).first).single;
    expect(view.priorBestE1rm, closeTo(100 * (1 + 5 / 30), 1e-6));
    expect(view.recordSetId, set2);
    // Правка вниз снимает отметку.
    expect(await journal.saveSet(set2, weightKg: 90, reps: 5, rir: 0), isNull);
    view = (await journal.watchSessionExercises(s2).first).single;
    expect(view.recordSetId, isNull);
  });

  test('копия программы: структура и план переносятся, веса сдвигаются', () async {
    final p = await program();
    await planner.updatePde(
        p.pdeId, const ProgramDayExercisesCompanion(loadMode: Value('linear'), startWeightKg: Value(80), weeklyStepKg: Value(2.5)));
    final copyId = await planner.copyProgram(p.programId, startDate: DateTime.utc(2026, 12, 21), weightDeltaKg: 5);
    final copy = await planner.watchProgram(copyId).first;
    expect(copy!.name, 'Тест (копия)');
    expect(copy.status, 'draft');
    expect(copy.startDate, '2026-12-21');
    expect((await planner.weeksOf(copyId)).where((w) => w.isDeload).single.weekNo, 5);
    final days = await planner.daysOf(copyId);
    expect(days.map((d) => d.weekday).toList(), [1, 3, 5]);
    final pde = (await planner.dayExercises(days.first.id)).single;
    expect(pde.startWeightKg, 85);
    final src = await planner.plansOf(p.pdeId);
    final plans = await planner.plansOf(pde.id);
    expect(plans.map((v) => v.plan.sets).toList(), src.map((v) => v.plan.sets).toList());
    expect(plans.map((v) => v.plan.weightKg).toList(), [85, 87.5, 90, 92.5, 82.5]); // 92,5 × 0,9 = 83,25 → 82,5
    // Оригинал не изменился.
    expect(src.first.plan.weightKg, 80);
  });
}
