import 'package:drift/drift.dart';

import '../domain/analytics.dart';
import '../domain/dates.dart';
import '../domain/strength.dart';
import 'database.dart';

/// Операции журнала. Вычисляемые поля (статус, e1rm_kg, недельные агрегаты)
/// считаются функциями слоя domain и записываются только здесь.
class JournalRepo {
  JournalRepo(this.db);
  final AppDatabase db;

  // ---------- Сессии ----------

  Stream<WorkoutSession?> watchInProgress() => (db.select(db.workoutSessions)
        ..where((s) => s.status.equals('in_progress'))
        ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
        ..limit(1))
      .watchSingleOrNull();

  Stream<WorkoutSession?> watchSession(int id) =>
      (db.select(db.workoutSessions)..where((s) => s.id.equals(id))).watchSingleOrNull();

  Future<WorkoutSession> session(int id) =>
      (db.select(db.workoutSessions)..where((s) => s.id.equals(id))).getSingle();

  Stream<List<SessionSummary>> watchHistory({int limit = 100}) {
    final q = db.select(db.workoutSessions).join([
      leftOuterJoin(db.programDays, db.programDays.id.equalsExp(db.workoutSessions.programDayId)),
    ])
      ..orderBy([OrderingTerm.desc(db.workoutSessions.date), OrderingTerm.desc(db.workoutSessions.startedAt)])
      ..limit(limit);
    return q.watch().map((rows) => [
          for (final r in rows) SessionSummary(r.readTable(db.workoutSessions), r.readTableOrNull(db.programDays)),
        ]);
  }

  /// Сессия по плану: предзаполняет подходы из плана недели.
  /// Если на эту дату уже есть сессия этого дня — возвращает её.
  Future<int> startPlannedSession({required int dayId, required int weekId, required DateTime date}) {
    return db.transaction(() async {
      final existing = await (db.select(db.workoutSessions)
            ..where((s) => s.programDayId.equals(dayId) & s.programWeekId.equals(weekId)))
          .getSingleOrNull();
      if (existing != null) return existing.id;
      final sid = await db.into(db.workoutSessions).insert(WorkoutSessionsCompanion.insert(
            programDayId: Value(dayId),
            programWeekId: Value(weekId),
            date: ymd(date),
            startedAt: DateTime.now().millisecondsSinceEpoch,
          ));
      final items = await (db.select(db.programDayExercises)
            ..where((e) => e.programDayId.equals(dayId))
            ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]))
          .get();
      for (final item in items) {
        final plan = await (db.select(db.exerciseWeekPlans)
              ..where((p) => p.programDayExerciseId.equals(item.id) & p.programWeekId.equals(weekId)))
            .getSingleOrNull();
        final seId = await db.into(db.sessionExercises).insert(SessionExercisesCompanion.insert(
              sessionId: sid,
              exerciseId: item.exerciseId,
              exerciseWeekPlanId: Value(plan?.id),
              sortOrder: Value(item.sortOrder),
            ));
        if (plan == null) continue;
        for (var n = 1; n <= plan.sets; n++) {
          await db.into(db.setLogs).insert(SetLogsCompanion.insert(
                sessionExerciseId: seId,
                setNo: n,
                plannedWeightKg: Value(plan.weightKg),
                plannedReps: Value(plan.repsMin),
              ));
        }
      }
      return sid;
    });
  }

  /// Свободная тренировка без плана.
  Future<int> startFreeSession(DateTime date) => db.into(db.workoutSessions).insert(
        WorkoutSessionsCompanion.insert(date: ymd(date), startedAt: DateTime.now().millisecondsSinceEpoch),
      );

  Future<void> deleteSession(int id) async {
    final s = await session(id);
    await (db.delete(db.workoutSessions)..where((x) => x.id.equals(id))).go();
    if (s.status == 'completed') await recalcWeek(parseYmd(s.date));
  }

  Future<void> setSessionNote(int id, String? note) => (db.update(db.workoutSessions)..where((s) => s.id.equals(id)))
      .write(WorkoutSessionsCompanion(note: Value(note == null || note.trim().isEmpty ? null : note.trim())));

  /// Завершает тренировку: фиксирует длительность и пересчитывает аналитику недели.
  Future<void> finishSession(int id) async {
    await (db.update(db.workoutSessions)..where((s) => s.id.equals(id))).write(WorkoutSessionsCompanion(
      status: const Value('completed'),
      finishedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
    final s = await session(id);
    await recalcWeek(parseYmd(s.date));
  }

  // ---------- Упражнения сессии ----------

  Stream<List<SessionExerciseView>> watchSessionExercises(int sessionId) {
    final q = db.select(db.sessionExercises).join([
      innerJoin(db.exercises, db.exercises.id.equalsExp(db.sessionExercises.exerciseId)),
      leftOuterJoin(db.exerciseWeekPlans, db.exerciseWeekPlans.id.equalsExp(db.sessionExercises.exerciseWeekPlanId)),
      leftOuterJoin(
          db.programDayExercises, db.programDayExercises.id.equalsExp(db.exerciseWeekPlans.programDayExerciseId)),
    ])
      ..where(db.sessionExercises.sessionId.equals(sessionId))
      ..orderBy([OrderingTerm.asc(db.sessionExercises.sortOrder), OrderingTerm.asc(db.sessionExercises.id)]);
    final sets = (db.select(db.setLogs).join([
      innerJoin(db.sessionExercises, db.sessionExercises.id.equalsExp(db.setLogs.sessionExerciseId)),
    ])
          ..where(db.sessionExercises.sessionId.equals(sessionId))
          ..orderBy([OrderingTerm.asc(db.setLogs.setNo)]))
        .watch();
    // Поток подходов — ведущий: любое изменение подхода обновляет экран.
    return sets.asyncMap((setRows) async {
      final rows = await q.get();
      final bySe = <int, List<SetLog>>{};
      for (final r in setRows) {
        final s = r.readTable(db.setLogs);
        bySe.putIfAbsent(s.sessionExerciseId, () => []).add(s);
      }
      final out = <SessionExerciseView>[];
      for (final r in rows) {
        final se = r.readTable(db.sessionExercises);
        out.add(SessionExerciseView(
          se,
          r.readTable(db.exercises),
          r.readTableOrNull(db.exerciseWeekPlans),
          r.readTableOrNull(db.programDayExercises)?.restSec,
          bySe[se.id] ?? const [],
          priorBestE1rm: await bestE1rm(se.exerciseId, exceptSessionId: sessionId),
        ));
      }
      return out;
    });
  }

  Future<int> addExerciseToSession(int sessionId, int exerciseId) async {
    final n = await (db.select(db.sessionExercises)..where((e) => e.sessionId.equals(sessionId))).get();
    final seId = await db.into(db.sessionExercises).insert(
          SessionExercisesCompanion.insert(sessionId: sessionId, exerciseId: exerciseId, sortOrder: Value(n.length)),
        );
    await addSet(seId);
    return seId;
  }

  Future<void> removeSessionExercise(int seId) async {
    final se = await (db.select(db.sessionExercises)..where((e) => e.id.equals(seId))).getSingle();
    await (db.delete(db.sessionExercises)..where((e) => e.id.equals(seId))).go();
    await _afterChange(se.sessionId);
  }

  // ---------- Подходы ----------

  Future<List<SetLog>> _setsOf(int seId) => (db.select(db.setLogs)
        ..where((s) => s.sessionExerciseId.equals(seId))
        ..orderBy([(s) => OrderingTerm.asc(s.setNo)]))
      .get();

  /// Добавляет подход сверх плана (или разминочный). Плановые значения берутся из последнего подхода.
  Future<int> addSet(int seId, {bool warmup = false}) async {
    final sets = await _setsOf(seId);
    final last = sets.where((s) => !s.isWarmup).lastOrNull;
    final nextNo = sets.isEmpty ? 1 : sets.last.setNo + 1;
    final id = await db.into(db.setLogs).insert(SetLogsCompanion.insert(
          sessionExerciseId: seId,
          setNo: nextNo,
          isWarmup: Value(warmup),
          plannedWeightKg: Value(warmup ? null : last?.plannedWeightKg),
          plannedReps: Value(warmup ? null : last?.plannedReps),
        ));
    return id;
  }

  Future<void> deleteSet(int setId) async {
    final s = await (db.select(db.setLogs)..where((x) => x.id.equals(setId))).getSingle();
    await (db.delete(db.setLogs)..where((x) => x.id.equals(setId))).go();
    await _refreshExercise(s.sessionExerciseId);
  }

  /// Лучший расчётный 1ПМ упражнения по всем подходам, кроме указанного подхода или сессии.
  Future<double?> bestE1rm(int exerciseId, {int? exceptSetId, int? exceptSessionId}) async {
    final row = await db.customSelect(
      'SELECT MAX(s.e1rm_kg) AS m FROM set_logs s '
      'JOIN session_exercises se ON se.id = s.session_exercise_id '
      'WHERE se.exercise_id = ? AND s.id != ? AND se.session_id != ?',
      variables: [Variable.withInt(exerciseId), Variable.withInt(exceptSetId ?? -1), Variable.withInt(exceptSessionId ?? -1)],
      readsFrom: {db.setLogs, db.sessionExercises},
    ).getSingle();
    return row.read<double?>('m');
  }

  /// Сохраняет факт подхода. Статус, флаг «вес снижен» и расчётный 1ПМ считает domain.
  /// Возвращает новый расчётный 1ПМ, если подход побил прежний рекорд упражнения, иначе null.
  Future<double?> saveSet(
    int setId, {
    required double? weightKg,
    required int reps,
    required int? rir,
    bool? isWarmup,
    String? note,
  }) async {
    final s = await (db.select(db.setLogs)..where((x) => x.id.equals(setId))).getSingle();
    final settings = await db.getSettings();
    final warm = isWarmup ?? s.isWarmup;
    final status = warm ? null : setStatus(plannedRepsMin: s.plannedReps, actualReps: reps);
    final e1rm = warm || weightKg == null
        ? null
        : epley1rm(weight: weightKg, reps: reps, rir: rir, useRir: settings.e1rmUseRir);
    final se = await (db.select(db.sessionExercises)..where((x) => x.id.equals(s.sessionExerciseId))).getSingle();
    final prior = e1rm == null ? null : await bestE1rm(se.exerciseId, exceptSetId: setId);
    await (db.update(db.setLogs)..where((x) => x.id.equals(setId))).write(SetLogsCompanion(
      weightKg: Value(weightKg),
      reps: Value(reps),
      rir: Value(rir),
      isWarmup: Value(warm),
      status: Value(status?.db),
      weightReduced: Value(!warm && isWeightReduced(s.plannedWeightKg, weightKg)),
      e1rmKg: Value(e1rm),
      note: note == null ? const Value.absent() : Value(note.trim().isEmpty ? null : note.trim()),
    ));
    await _refreshExercise(s.sessionExerciseId);
    return e1rm != null && prior != null && e1rm > prior + 1e-6 ? e1rm : null;
  }

  /// «Выполнено по плану» — одно нажатие: факт = план, RIR = целевой.
  Future<double?> completeAsPlanned(int setId, {int? targetRir}) async {
    final s = await (db.select(db.setLogs)..where((x) => x.id.equals(setId))).getSingle();
    return saveSet(setId, weightKg: s.plannedWeightKg, reps: s.plannedReps ?? 0, rir: targetRir);
  }

  Future<void> skipSet(int setId) async {
    final s = await (db.select(db.setLogs)..where((x) => x.id.equals(setId))).getSingle();
    await (db.update(db.setLogs)..where((x) => x.id.equals(setId))).write(SetLogsCompanion(
      weightKg: const Value(null),
      reps: const Value(null),
      rir: const Value(null),
      status: Value(SetStatus.skipped.db),
      weightReduced: const Value(false),
      e1rmKg: const Value(null),
    ));
    await _refreshExercise(s.sessionExerciseId);
  }

  /// Возвращает подход в состояние «не выполнен».
  Future<void> resetSet(int setId) async {
    final s = await (db.select(db.setLogs)..where((x) => x.id.equals(setId))).getSingle();
    await (db.update(db.setLogs)..where((x) => x.id.equals(setId))).write(const SetLogsCompanion(
      weightKg: Value(null),
      reps: Value(null),
      rir: Value(null),
      status: Value(null),
      weightReduced: Value(false),
      e1rmKg: Value(null),
    ));
    await _refreshExercise(s.sessionExerciseId);
  }

  Future<void> _refreshExercise(int seId) async {
    final se = await (db.select(db.sessionExercises)..where((e) => e.id.equals(seId))).getSingleOrNull();
    if (se == null) return;
    final sets = await _setsOf(seId);
    final worst = worstStatus(sets.where((s) => !s.isWarmup).map((s) => SetStatus.fromDb(s.status)));
    await (db.update(db.sessionExercises)..where((e) => e.id.equals(seId)))
        .write(SessionExercisesCompanion(status: Value(worst?.db)));
    await _afterChange(se.sessionId);
  }

  /// Правка завершённой сессии пересчитывает агрегаты её недели.
  Future<void> _afterChange(int sessionId) async {
    final s = await (db.select(db.workoutSessions)..where((x) => x.id.equals(sessionId))).getSingleOrNull();
    if (s != null && s.status == 'completed') await recalcWeek(parseYmd(s.date));
  }

  /// Пересчитывает e1rm_kg всех подходов (после смены настройки «учитывать RIR») и все недели.
  Future<void> recalcAll() async {
    final settings = await db.getSettings();
    final all = await db.select(db.setLogs).get();
    await db.transaction(() async {
      for (final s in all) {
        final e = s.isWarmup || s.weightKg == null || s.reps == null
            ? null
            : epley1rm(weight: s.weightKg!, reps: s.reps!, rir: s.rir, useRir: settings.e1rmUseRir);
        if (e != s.e1rmKg) {
          await (db.update(db.setLogs)..where((x) => x.id.equals(s.id))).write(SetLogsCompanion(e1rmKg: Value(e)));
        }
      }
    });
    final dates = await (db.selectOnly(db.workoutSessions, distinct: true)..addColumns([db.workoutSessions.date])).get();
    final weeks = {for (final r in dates) weekStart(parseYmd(r.read(db.workoutSessions.date)!))}.toList()..sort();
    for (final w in weeks) {
      await recalcWeek(w);
    }
  }

  // ---------- Недельные агрегаты ----------

  /// Пересобирает weekly_exercise_stats и weekly_muscle_volume за неделю даты [anyDay]
  /// и обновляет e1rm_delta_pct следующей недели с данными.
  Future<void> recalcWeek(DateTime anyDay) async {
    final ws = weekStart(anyDay);
    final from = ymd(ws);
    final to = ymd(addDays(ws, 6));
    await db.transaction(() async {
      final q = db.select(db.setLogs).join([
        innerJoin(db.sessionExercises, db.sessionExercises.id.equalsExp(db.setLogs.sessionExerciseId)),
        innerJoin(db.workoutSessions, db.workoutSessions.id.equalsExp(db.sessionExercises.sessionId)),
        leftOuterJoin(db.programWeeks, db.programWeeks.id.equalsExp(db.workoutSessions.programWeekId)),
      ])
        ..where(db.workoutSessions.status.equals('completed') &
            db.workoutSessions.date.isBetweenValues(from, to));
      final rows = await q.get();
      final shares = <int, Map<int, double>>{};
      for (final m in await db.select(db.exerciseMuscles).get()) {
        shares.putIfAbsent(m.exerciseId, () => {})[m.muscleGroupId] = m.share;
      }
      final facts = [
        for (final r in rows)
          () {
            final s = r.readTable(db.setLogs);
            final exId = r.readTable(db.sessionExercises).exerciseId;
            return SetFact(
              exerciseId: exId,
              isWarmup: s.isWarmup,
              weightKg: s.weightKg,
              reps: s.reps,
              e1rmKg: s.e1rmKg,
              status: SetStatus.fromDb(s.status),
              isDeloadWeek: r.readTableOrNull(db.programWeeks)?.isDeload ?? false,
              muscleShares: shares[exId] ?? const {},
            );
          }(),
      ];
      final agg = aggregateWeek(facts);

      await (db.delete(db.weeklyExerciseStats)..where((s) => s.weekStart.equals(from))).go();
      await (db.delete(db.weeklyMuscleVolume)..where((s) => s.weekStart.equals(from))).go();

      for (final e in agg.byExercise.entries) {
        final prev = await _prevE1rm(e.key, from);
        await db.into(db.weeklyExerciseStats).insert(WeeklyExerciseStatsCompanion.insert(
              exerciseId: e.key,
              weekStart: from,
              bestE1rmKg: Value(e.value.bestE1rm),
              e1rmDeltaPct: Value(deltaPct(e.value.bestE1rm, prev)),
              tonnageKg: Value(e.value.tonnage),
              workSets: Value(e.value.workSets),
              setsDone: Value(e.value.setsDone),
              setsPartial: Value(e.value.setsPartial),
              setsFailed: Value(e.value.setsFailed),
              isDeload: Value(e.value.isDeload),
            ));
      }
      for (final m in agg.byMuscle.entries) {
        await db.into(db.weeklyMuscleVolume).insert(WeeklyMuscleVolumeCompanion.insert(
              muscleGroupId: m.key,
              weekStart: from,
              sets: Value(m.value.sets),
              tonnageKg: Value(m.value.tonnage),
            ));
      }

      // Дельта следующей недели с данными зависит от этой недели.
      final later = await (db.select(db.weeklyExerciseStats)
            ..where((s) => s.weekStart.isBiggerThanValue(from))
            ..orderBy([(s) => OrderingTerm.asc(s.weekStart)]))
          .get();
      final seen = <int>{};
      for (final s in later) {
        if (!seen.add(s.exerciseId)) continue;
        final prev = await _prevE1rm(s.exerciseId, s.weekStart);
        await (db.update(db.weeklyExerciseStats)..where((x) => x.id.equals(s.id)))
            .write(WeeklyExerciseStatsCompanion(e1rmDeltaPct: Value(deltaPct(s.bestE1rmKg, prev))));
      }
    });
  }

  Future<double?> _prevE1rm(int exerciseId, String weekStartYmd) async {
    final row = await (db.select(db.weeklyExerciseStats)
          ..where((s) =>
              s.exerciseId.equals(exerciseId) &
              s.weekStart.isSmallerThanValue(weekStartYmd) &
              s.bestE1rmKg.isNotNull())
          ..orderBy([(s) => OrderingTerm.desc(s.weekStart)])
          ..limit(1))
        .getSingleOrNull();
    return row?.bestE1rmKg;
  }
}

class SessionSummary {
  SessionSummary(this.session, this.day);
  final WorkoutSession session;
  final ProgramDay? day;
}

class SessionExerciseView {
  SessionExerciseView(this.se, this.exercise, this.plan, this.restSec, this.sets, {this.priorBestE1rm});

  /// Лучший расчётный 1ПМ упражнения в других сессиях — для отметки рекорда.
  final double? priorBestE1rm;

  /// Подход-рекорд этой сессии: лучший 1ПМ, превысивший прежний максимум.
  int? get recordSetId {
    final prior = priorBestE1rm;
    if (prior == null) return null;
    SetLog? best;
    for (final s in sets) {
      final e = s.e1rmKg;
      if (e != null && e > prior + 1e-6 && (best == null || e > best.e1rmKg!)) best = s;
    }
    return best?.id;
  }
  final SessionExercise se;
  final Exercise exercise;
  final ExerciseWeekPlan? plan;
  final int? restSec;
  final List<SetLog> sets;

  SetStatus? get status => SetStatus.fromDb(se.status);
}
