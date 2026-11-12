import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:trainlog/data/app_state.dart';
import 'package:trainlog/data/database.dart';
import 'package:trainlog/data/journal_repo.dart';
import 'package:trainlog/data/planner_repo.dart';
import 'package:trainlog/data/rules_repo.dart';

void main() {
  late AppDatabase db;
  late PlannerRepo planner;
  late JournalRepo journal;
  late RulesRepo rules;
  late MemoryAppState state;
  late int programId, dayId, pdeId;

  setUp(() async {
    db = AppDatabase.memory();
    planner = PlannerRepo(db);
    journal = JournalRepo(db);
    state = MemoryAppState();
    rules = RulesRepo(db, state);
    programId = await planner.createProgram(
        name: 'Тест', startDate: DateTime.utc(2026, 10, 5), weeksCount: 6, timeLimitMin: 75, weekdays: [1], deloadWeekNo: 6);
    await planner.activate(programId);
    dayId = (await planner.daysOf(programId)).single.id;
    final bench = await (db.select(db.exercises)..where((e) => e.name.equals('Жим лёжа'))).getSingle();
    pdeId = await planner.addExercise(dayId: dayId, exerciseId: bench.id, sets: 3, repsMin: 8, repsMax: 10);
    await planner.updatePde(pdeId,
        const ProgramDayExercisesCompanion(loadMode: Value('linear'), startWeightKg: Value(100), weeklyStepKg: Value(0)));
  });
  tearDown(() => db.close());

  /// Проводит сессию недели [weekNo]: все подходы с указанными повторами.
  Future<void> session(int weekNo, int reps, {DateTime? now}) async {
    final week = (await planner.weeksOf(programId))[weekNo - 1];
    final sid = await journal.startPlannedSession(dayId: dayId, weekId: week.id, date: DateTime.parse('${week.startDate}T00:00:00Z'));
    final sets = await (db.select(db.setLogs).join([
      innerJoin(db.sessionExercises, db.sessionExercises.id.equalsExp(db.setLogs.sessionExerciseId)),
    ])..where(db.sessionExercises.sessionId.equals(sid))).get();
    for (final r in sets) {
      final s = r.readTable(db.setLogs);
      await journal.saveSet(s.id, weightKg: s.plannedWeightKg, reps: reps, rir: 0);
    }
    await journal.finishSession(sid);
    await rules.onSessionCompleted(sid, now: now);
  }

  Future<List<Recommendation>> recs() => (db.select(db.recommendations)..orderBy([(r) => OrderingTerm.asc(r.id)])).get();

  test('TWO_RED_IN_ROW: создание, принятие сдвигает прогрессию, откат возвращает план', () async {
    await session(1, 2);
    expect(await recs(), isEmpty);
    await session(2, 2);
    final rec = (await recs()).single;
    expect(rec.status, 'new');
    expect(rec.programDayExerciseId, pdeId);

    await rules.accept(rec.id);
    var plans = await planner.plansOf(pdeId);
    expect(plans.map((p) => p.plan.weightKg).toList(), [100, 100, 95, 95, 95, 85]);
    expect((await recs()).single.status, 'accepted');
    expect((await recs()).single.previousValues, isNotNull);

    await rules.rollback(rec.id);
    plans = await planner.plansOf(pdeId);
    expect(plans.map((p) => p.plan.weightKg).toList(), [100, 100, 100, 100, 100, 90]);
    expect(plans.every((p) => !p.plan.isManual), isTrue);
  });

  test('отклонение уводит правило в cooldown; непринятая рекомендация истекает на следующей сессии', () async {
    final t0 = DateTime(2026, 10, 12, 20);
    await session(1, 2, now: t0);
    await session(2, 2, now: t0);
    await rules.reject((await recs()).single.id);
    // Третий провал через неделю — cooldown 7 дней считается от resolved_at (сейчас), рекомендации нет.
    await session(3, 2, now: DateTime.now().add(const Duration(days: 1)));
    expect((await recs()).length, 1);
    // После cooldown правило срабатывает снова.
    await session(4, 2, now: DateTime.now().add(const Duration(days: 9)));
    expect((await recs()).map((r) => r.status).toList(), ['rejected', 'new']);
    // Не принята до следующей сессии упражнения → expired; правило снова в cooldown по resolved_at.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await session(5, 2, now: DateTime.now().add(const Duration(days: 30)));
    final all = await recs();
    expect(all.map((r) => r.status).toList(), ['rejected', 'expired']);
    expect(all[1].resolvedAt, isNotNull);
  });

  test('закрытие нескольких пропущенных недель подряд', () async {
    await state.set(stateLastClosedWeek, '2026-09-28');
    await session(1, 8);
    await session(2, 8);
    await session(3, 8);
    await db.delete(db.weeklyExerciseStats).go();
    final closed = await rules.closeWeeks(now: DateTime.utc(2026, 10, 28));
    expect(closed.map((d) => d.toIso8601String().substring(0, 10)).toList(), ['2026-10-05', '2026-10-12', '2026-10-19']);
    expect(await state.get(stateLastClosedWeek), '2026-10-19');
    final stats = await (db.select(db.weeklyExerciseStats)..orderBy([(s) => OrderingTerm.asc(s.weekStart)])).get();
    expect(stats.map((s) => s.weekStart).toList(), ['2026-10-05', '2026-10-12', '2026-10-19']);
    // Повторный запуск на той же неделе ничего не закрывает.
    expect(await rules.closeWeeks(now: DateTime.utc(2026, 10, 30)), isEmpty);
  });

  test('week_closed: застой базового упражнения → досрочная разгрузка, плато подавлено; принятие и откат', () async {
    await state.set(stateLastClosedWeek, '2026-10-19');
    for (var w = 1; w <= 4; w++) {
      await session(w, 8); // вес не растёт → 1ПМ одинаковый 4 недели
    }
    await rules.closeWeeks(now: DateTime.utc(2026, 11, 3));
    final all = await recs();
    final codes = <String>[];
    for (final r in all) {
      codes.add((await (db.select(db.rules)..where((x) => x.id.equals(r.ruleId))).getSingle()).code);
    }
    expect(codes.toSet(), {'EARLY_DELOAD'});
    final rec = all.lastWhere((r) => r.status == 'new');
    expect(rec.programDayExerciseId, isNull);

    await rules.accept(rec.id);
    var weeks = await planner.weeksOf(programId);
    expect(weeks.where((w) => w.isDeload).single.weekNo, 5);
    await rules.rollback(rec.id);
    weeks = await planner.weeksOf(programId);
    expect(weeks.where((w) => w.isDeload).single.weekNo, 6);
  });

  test('E1RM_PLATEAU: +1 подход и смена вариации с откатом', () async {
    // Досрочную разгрузку выключаем, чтобы она не подавляла плато.
    await (db.update(db.rules)..where((r) => r.code.equals('EARLY_DELOAD'))).write(const RulesCompanion(isActive: Value(false)));
    await state.set(stateLastClosedWeek, '2026-10-19');
    for (var w = 1; w <= 4; w++) {
      await session(w, 8);
    }
    await rules.closeWeeks(now: DateTime.utc(2026, 11, 3));
    final rec = (await recs()).single;
    final view = (await rules.watchRecommendations().first).single;
    expect(view.rule.code, 'E1RM_PLATEAU');
    expect((view.proposal['variations'] as List), isNotEmpty);

    await rules.accept(rec.id, option: 'add_sets');
    var plans = await planner.plansOf(pdeId);
    expect(plans.map((p) => p.plan.sets).toList(), [3, 3, 3, 3, 4, 2]);
    await rules.rollback(rec.id);
    plans = await planner.plansOf(pdeId);
    expect(plans.map((p) => p.plan.sets).toList(), [3, 3, 3, 3, 3, 2]);

    // Новая рекомендация после cooldown: смена вариации.
    await (db.update(db.recommendations)).write(const RecommendationsCompanion(resolvedAt: Value(0)));
    await rules.onWeekClosed(DateTime.utc(2026, 10, 26), now: DateTime.utc(2026, 11, 3));
    final rec2 = (await recs()).last;
    expect(rec2.status, 'new');
    final variationId = ((await rules.watchRecommendations(status: 'new').first).single.proposal['variations'] as List).first['id'] as int;
    final before = (await planner.pde(pdeId)).exerciseId;
    await rules.accept(rec2.id, option: 'change_variation', variationId: variationId);
    expect((await planner.pde(pdeId)).exerciseId, variationId);
    await rules.rollback(rec2.id);
    expect((await planner.pde(pdeId)).exerciseId, before);
  });
}
