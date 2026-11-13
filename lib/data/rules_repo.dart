import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/dates.dart';
import '../domain/rules.dart';
import '../domain/strength.dart';
import 'app_state.dart';
import 'database.dart';
import 'journal_repo.dart';
import 'planner_repo.dart';
import 'package:trainlog/i18n.dart';

/// Запуск движка правил, жизненный цикл рекомендаций и закрытие недели.
class RulesRepo {
  RulesRepo(this.db, this.state);
  final AppDatabase db;
  final AppStateStore state;

  late final _planner = PlannerRepo(db);
  late final _journal = JournalRepo(db);

  // ---------- Чтение ----------

  Stream<List<RecommendationView>> watchRecommendations({String? status}) {
    final q = db.select(db.recommendations).join([
      innerJoin(db.rules, db.rules.id.equalsExp(db.recommendations.ruleId)),
    ])
      ..orderBy([OrderingTerm.desc(db.recommendations.id)])
      ..limit(100);
    if (status != null) q.where(db.recommendations.status.equals(status));
    return q.watch().map(
        (rows) => [for (final r in rows) RecommendationView(r.readTable(db.recommendations), r.readTable(db.rules))]);
  }

  Stream<List<Rule>> watchRules() => (db.select(db.rules)..orderBy([(r) => OrderingTerm.desc(r.priority)])).watch();

  Future<void> updateRule(int id, RulesCompanion data) => (db.update(db.rules)..where((r) => r.id.equals(id))).write(data);

  Future<List<RuleDef>> _ruleDefs() async => [
        for (final r in await db.select(db.rules).get())
          RuleDef(
            id: r.id,
            code: r.code,
            name: r.name,
            trigger: r.trigger,
            scope: r.scope,
            condition: jsonDecode(r.condition) as Map<String, dynamic>,
            action: jsonDecode(r.action) as Map<String, dynamic>,
            priority: r.priority,
            cooldownDays: r.cooldownDays,
            isActive: r.isActive,
          ),
      ];

  Future<List<RecState>> _recStates(int programId) async => [
        for (final r in await (db.select(db.recommendations)..where((r) => r.programId.equals(programId))).get())
          RecState(
            ruleId: r.ruleId,
            pdeId: r.programDayExerciseId,
            status: r.status,
            resolvedAt: r.resolvedAt == null ? null : DateTime.fromMillisecondsSinceEpoch(r.resolvedAt!),
          ),
      ];

  // ---------- Сбор фактов ----------

  /// Упражнения программы с историей. [onlyPdeIds] ограничивает набор (после сессии — её упражнения).
  Future<List<ExerciseFacts>> _exerciseFacts(int programId, {Set<int>? onlyPdeIds, DateTime? asOf}) async {
    final out = <ExerciseFacts>[];
    final asOfYmd = asOf == null ? null : ymd(asOf);
    for (final day in await _planner.daysOf(programId)) {
      for (final item in await _planner.dayExercises(day.id)) {
        if (onlyPdeIds != null && !onlyPdeIds.contains(item.id)) continue;
        final ex = await (db.select(db.exercises)..where((e) => e.id.equals(item.exerciseId))).getSingle();

        // Завершённые сессии этого упражнения программы, от последней.
        final sq = db.select(db.sessionExercises).join([
          innerJoin(db.workoutSessions, db.workoutSessions.id.equalsExp(db.sessionExercises.sessionId)),
          innerJoin(db.exerciseWeekPlans, db.exerciseWeekPlans.id.equalsExp(db.sessionExercises.exerciseWeekPlanId)),
        ])
          ..where(db.exerciseWeekPlans.programDayExerciseId.equals(item.id) &
              db.workoutSessions.status.equals('completed'))
          ..orderBy([OrderingTerm.desc(db.workoutSessions.date), OrderingTerm.desc(db.workoutSessions.startedAt)])
          ..limit(4);
        final sessions = <SessionOutcome>[];
        for (final r in await sq.get()) {
          final se = r.readTable(db.sessionExercises);
          final plan = r.readTable(db.exerciseWeekPlans);
          final sets = await (db.select(db.setLogs)
                ..where((s) => s.sessionExerciseId.equals(se.id) & s.isWarmup.equals(false)))
              .get();
          final work = [for (final s in sets) if (s.status != 'skipped' && s.reps != null) s];
          final rirs = [for (final s in work) if (s.rir != null) s.rir! - plan.targetRir];
          sessions.add(SessionOutcome(
            status: se.status,
            shortfalls: [
              for (final s in sets)
                if (s.plannedReps != null && s.reps != null) shortfall(s.plannedReps!, s.reps!),
            ],
            topOfRange: work.isNotEmpty && work.every((s) => s.reps! >= plan.repsMax),
            rirMargin: rirs.isEmpty || rirs.length < work.length ? null : rirs.reduce((a, b) => a < b ? a : b),
          ));
        }

        final statsQ = db.select(db.weeklyExerciseStats)
          ..where((s) => s.exerciseId.equals(item.exerciseId) & s.isDeload.equals(false) & s.bestE1rmKg.isNotNull())
          ..orderBy([(s) => OrderingTerm.asc(s.weekStart)]);
        if (asOfYmd != null) statsQ.where((s) => s.weekStart.isSmallerOrEqualValue(asOfYmd));
        final stats = await statsQ.get();

        final next = (await _upcomingPlans(item.id)).firstOrNull?.plan;
        out.add(ExerciseFacts(
          pdeId: item.id,
          exerciseName: ex.name,
          isCompound: ex.kind == 'compound',
          lastSessions: sessions,
          weeklyE1rm: [for (final s in stats) s.bestE1rmKg!],
          currentWeightKg: next?.weightKg,
          currentRepsMin: next?.repsMin,
          currentRepsMax: next?.repsMax,
        ));
      }
    }
    return out;
  }

  /// Строки плана упражнения, по которым ещё нет сессии (будущие недели), по порядку.
  Future<List<WeekPlanView>> _upcomingPlans(int pdeId) async {
    final plans = await _planner.plansOf(pdeId);
    final used = <int>{
      for (final se in await (db.select(db.sessionExercises)..where((s) => s.exerciseWeekPlanId.isNotNull())).get())
        se.exerciseWeekPlanId!,
    };
    final lastUsedIdx = plans.lastIndexWhere((p) => used.contains(p.plan.id));
    return plans.sublist(lastUsedIdx + 1);
  }

  // ---------- Запуск правил ----------

  Future<void> _create(int programId, List<Candidate> candidates) async {
    for (final c in candidates) {
      var proposal = c.proposal;
      if (proposal['type'] == 'choice' && c.pdeId != null) {
        // Для смены вариации заранее собираем доступные варианты.
        final item = await _planner.pde(c.pdeId!);
        final family = await _variationFamily(item.exerciseId);
        proposal = {
          ...proposal,
          'variations': [
            for (final v in family)
              if (v.id != item.exerciseId) {'id': v.id, 'name': v.name},
          ],
        };
      }
      await db.into(db.recommendations).insert(RecommendationsCompanion.insert(
            ruleId: c.rule.id,
            programId: programId,
            programDayExerciseId: Value(c.pdeId),
            facts: Value(jsonEncode(c.facts)),
            proposedChanges: Value(jsonEncode(proposal)),
          ));
    }
  }

  Future<List<Exercise>> _variationFamily(int exerciseId) async {
    final e = await (db.select(db.exercises)..where((x) => x.id.equals(exerciseId))).getSingle();
    final baseId = e.baseExerciseId ?? e.id;
    return (db.select(db.exercises)
          ..where((x) => (x.id.equals(baseId) | x.baseExerciseId.equals(baseId)) & x.isArchived.equals(false)))
        .get();
  }

  /// Триггер session_completed. Перед проверкой истекают рекомендации,
  /// не принятые до этой сессии упражнения.
  Future<void> onSessionCompleted(int sessionId, {DateTime? now}) async {
    final session = await (db.select(db.workoutSessions)..where((s) => s.id.equals(sessionId))).getSingle();
    if (session.programWeekId == null) return;
    final week = await (db.select(db.programWeeks)..where((w) => w.id.equals(session.programWeekId!))).getSingleOrNull();
    if (week == null) return;
    final programId = week.programId;
    final at = now ?? DateTime.now();

    final q = db.select(db.sessionExercises).join([
      innerJoin(db.exerciseWeekPlans, db.exerciseWeekPlans.id.equalsExp(db.sessionExercises.exerciseWeekPlanId)),
    ])
      ..where(db.sessionExercises.sessionId.equals(sessionId));
    final pdeIds = {for (final r in await q.get()) r.readTable(db.exerciseWeekPlans).programDayExerciseId};
    if (pdeIds.isEmpty) return;

    await (db.update(db.recommendations)
          ..where((r) =>
              r.status.equals('new') &
              r.programDayExerciseId.isIn(pdeIds) &
              r.createdAt.isSmallerThanValue(session.startedAt)))
        .write(RecommendationsCompanion(status: const Value('expired'), resolvedAt: Value(at.millisecondsSinceEpoch)));

    final settings = await db.getSettings();
    final candidates = evaluateRules(
      trigger: 'session_completed',
      rules: await _ruleDefs(),
      exercises: await _exerciseFacts(programId, onlyPdeIds: pdeIds),
      program: const ProgramFacts(),
      existing: await _recStates(programId),
      now: at,
      weightStep: settings.weightRoundingKg,
    );
    await _create(programId, candidates);
  }

  /// Триггер week_closed для недели, начинающейся в [weekStartDay].
  Future<void> onWeekClosed(DateTime weekStartDay, {DateTime? now}) async {
    final program = await _planner.activeProgram();
    if (program == null) return;
    final ws = ymd(weekStartDay);
    final weeks = await _planner.weeksOf(program.id);
    final closed = weeks.where((w) => w.startDate == ws).firstOrNull;
    if (closed == null) return; // неделя вне цикла
    final next = weeks.where((w) => w.weekNo == closed.weekNo + 1).firstOrNull;
    final at = now ?? DateTime.now();

    // Программные рекомендации, не принятые за неделю, истекают.
    await (db.update(db.recommendations)
          ..where((r) =>
              r.status.equals('new') & r.programId.equals(program.id) & r.programDayExerciseId.isNull()))
        .write(RecommendationsCompanion(status: const Value('expired'), resolvedAt: Value(at.millisecondsSinceEpoch)));

    final exercises = await _exerciseFacts(program.id, asOf: weekStartDay);
    final exerciseIds = <int>{};
    for (final d in await _planner.daysOf(program.id)) {
      for (final e in await _planner.dayExercises(d.id)) {
        exerciseIds.add(e.exerciseId);
      }
    }
    final stats = await (db.select(db.weeklyExerciseStats)
          ..where((s) => s.weekStart.equals(ws) & s.exerciseId.isIn(exerciseIds)))
        .get();
    var done = 0, partial = 0, failed = 0;
    for (final s in stats) {
      done += s.setsDone;
      partial += s.setsPartial;
      failed += s.setsFailed;
    }

    final settings = await db.getSettings();
    final candidates = evaluateRules(
      trigger: 'week_closed',
      rules: await _ruleDefs(),
      // На разгрузочной неделе застой не оценивается.
      exercises: closed.isDeload ? const [] : exercises,
      program: ProgramFacts(
        setsDone: closed.isDeload ? 0 : done,
        setsPartial: closed.isDeload ? 0 : partial,
        setsFailed: closed.isDeload ? 0 : failed,
        hasNextWeek: next != null,
        nextWeekIsDeload: next?.isDeload ?? false,
      ),
      existing: await _recStates(program.id),
      now: at,
      weightStep: settings.weightRoundingKg,
    );
    // Для досрочной разгрузки запоминаем, на какую неделю она ставится.
    await _create(program.id, [
      for (final c in candidates)
        c.proposal['type'] == 'early_deload' && next != null
            ? Candidate(rule: c.rule, pdeId: null, facts: c.facts, proposal: {...c.proposal, 'week_no': next.weekNo})
            : c,
    ]);
  }

  /// Закрытие недель при запуске приложения: пропущенные недели закрываются по очереди.
  /// Возвращает понедельники закрытых недель.
  Future<List<DateTime>> closeWeeks({DateTime? now, Future<void> Function(DateTime weekStart)? extra}) async {
    final at = now ?? DateTime.now();
    final last = await state.get(stateLastClosedWeek);
    final weeks = weeksToClose(last == null ? null : parseYmd(last), at);
    for (final w in weeks) {
      await _journal.recalcWeek(w);
      await onWeekClosed(w, now: at);
      if (extra != null) await extra(w);
      await state.set(stateLastClosedWeek, ymd(w));
    }
    return weeks;
  }

  // ---------- Жизненный цикл ----------

  Future<Recommendation> _rec(int id) => (db.select(db.recommendations)..where((r) => r.id.equals(id))).getSingle();

  Future<void> reject(int id) => (db.update(db.recommendations)..where((r) => r.id.equals(id))).write(
      RecommendationsCompanion(status: const Value('rejected'), resolvedAt: Value(DateTime.now().millisecondsSinceEpoch)));

  /// Принятие: изменения пишутся в план, прежние значения сохраняются для отката.
  /// Для правила с выбором передаётся [option] ('change_variation' | 'add_sets') и, для вариации, [variationId].
  Future<void> accept(int id, {String? option, int? variationId}) async {
    final rec = await _rec(id);
    if (rec.status != 'new') return;
    final proposal = jsonDecode(rec.proposedChanges) as Map<String, dynamic>;
    var type = proposal['type'] as String;
    Map<String, dynamic>? chosen;
    if (type == 'choice') {
      final options = (proposal['options'] as List).cast<Map<String, dynamic>>();
      chosen = options.firstWhere((o) => o['type'] == option, orElse: () => options.first);
      type = chosen['type'] as String;
    }

    await db.transaction(() async {
      final Map<String, dynamic> previous;
      switch (type) {
        case 'reduce_weight' || 'increase_weight':
          final sign = type == 'increase_weight' ? -1 : 1;
          final delta = sign * (proposal['delta_kg'] as num).toDouble();
          final plans = await _upcomingPlans(rec.programDayExerciseId!);
          previous = {
            'type': type,
            'plans': [
              for (final p in plans) {'id': p.plan.id, 'weight_kg': p.plan.weightKg, 'is_manual': p.plan.isManual},
            ],
          };
          // Новый вес — к следующей сессии, прогрессия последующих недель сдвигается на ту же величину.
          for (final p in plans) {
            final w = p.plan.weightKg;
            if (w == null) continue;
            await (db.update(db.exerciseWeekPlans)..where((x) => x.id.equals(p.plan.id))).write(
                ExerciseWeekPlansCompanion(weightKg: Value(w - delta < 0 ? 0 : w - delta), isManual: const Value(true)));
          }
        case 'reduce_reps':
          final cut = (proposal['from_min'] as num).toInt() - (proposal['to_min'] as num).toInt();
          final cutMax = (proposal['from_max'] as num).toInt() - (proposal['to_max'] as num).toInt();
          final plans = (await _upcomingPlans(rec.programDayExerciseId!)).where((p) => !p.week.isDeload).toList();
          previous = {
            'type': type,
            'plans': [
              for (final p in plans) {'id': p.plan.id, 'reps_min': p.plan.repsMin, 'reps_max': p.plan.repsMax},
            ],
          };
          for (final p in plans) {
            final min = p.plan.repsMin - cut < 1 ? 1 : p.plan.repsMin - cut;
            final max = p.plan.repsMax - cutMax < min ? min : p.plan.repsMax - cutMax;
            await (db.update(db.exerciseWeekPlans)..where((x) => x.id.equals(p.plan.id)))
                .write(ExerciseWeekPlansCompanion(repsMin: Value(min), repsMax: Value(max)));
          }
          await _planner.recalcPlans(rec.programDayExerciseId!);
        case 'add_sets':
          final add = ((chosen?['sets'] ?? proposal['sets'] ?? 1) as num).toInt();
          final plans = (await _upcomingPlans(rec.programDayExerciseId!)).where((p) => !p.week.isDeload).toList();
          previous = {
            'type': type,
            'plans': [
              for (final p in plans) {'id': p.plan.id, 'sets': p.plan.sets},
            ],
          };
          for (final p in plans) {
            await (db.update(db.exerciseWeekPlans)..where((x) => x.id.equals(p.plan.id)))
                .write(ExerciseWeekPlansCompanion(sets: Value(p.plan.sets + add)));
          }
          await _planner.recalcPlans(rec.programDayExerciseId!);
        case 'change_variation':
          final item = await _planner.pde(rec.programDayExerciseId!);
          final variations = (proposal['variations'] as List? ?? const []).cast<Map<String, dynamic>>();
          final target = variationId ?? (variations.isEmpty ? null : variations.first['id'] as int);
          if (target == null) throw StateError(tr('У упражнения нет вариаций'));
          previous = {'type': type, 'exercise_id': item.exerciseId};
          await (db.update(db.programDayExercises)..where((x) => x.id.equals(item.id)))
              .write(ProgramDayExercisesCompanion(exerciseId: Value(target)));
          await _planner.recalcPlans(item.id);
        case 'early_deload':
          final weeks = await _planner.weeksOf(rec.programId);
          previous = {
            'type': type,
            'deload_week_no': weeks.where((w) => w.isDeload).map((w) => w.weekNo).firstOrNull,
          };
          await _planner.setDeloadWeek(rec.programId, (proposal['week_no'] as num).toInt());
        default:
          throw StateError(tr('Неизвестное действие: {0}', [type]));
      }
      await (db.update(db.recommendations)..where((r) => r.id.equals(id))).write(RecommendationsCompanion(
        status: const Value('accepted'),
        previousValues: Value(jsonEncode(previous)),
        resolvedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ));
    });
  }

  /// Откат принятой рекомендации по сохранённым previous_values.
  Future<void> rollback(int id) async {
    final rec = await _rec(id);
    if (rec.status != 'accepted' || rec.previousValues == null) return;
    final prev = jsonDecode(rec.previousValues!) as Map<String, dynamic>;
    await db.transaction(() async {
      switch (prev['type']) {
        case 'reduce_weight' || 'increase_weight':
          for (final p in (prev['plans'] as List).cast<Map<String, dynamic>>()) {
            await (db.update(db.exerciseWeekPlans)..where((x) => x.id.equals(p['id'] as int))).write(
                ExerciseWeekPlansCompanion(
                    weightKg: Value((p['weight_kg'] as num?)?.toDouble()), isManual: Value(p['is_manual'] as bool)));
          }
        case 'reduce_reps':
          for (final p in (prev['plans'] as List).cast<Map<String, dynamic>>()) {
            await (db.update(db.exerciseWeekPlans)..where((x) => x.id.equals(p['id'] as int))).write(
                ExerciseWeekPlansCompanion(repsMin: Value(p['reps_min'] as int), repsMax: Value(p['reps_max'] as int)));
          }
          if (rec.programDayExerciseId != null) await _planner.recalcPlans(rec.programDayExerciseId!);
        case 'add_sets':
          for (final p in (prev['plans'] as List).cast<Map<String, dynamic>>()) {
            await (db.update(db.exerciseWeekPlans)..where((x) => x.id.equals(p['id'] as int)))
                .write(ExerciseWeekPlansCompanion(sets: Value(p['sets'] as int)));
          }
          if (rec.programDayExerciseId != null) await _planner.recalcPlans(rec.programDayExerciseId!);
        case 'change_variation':
          await (db.update(db.programDayExercises)..where((x) => x.id.equals(rec.programDayExerciseId!)))
              .write(ProgramDayExercisesCompanion(exerciseId: Value(prev['exercise_id'] as int)));
          await _planner.recalcPlans(rec.programDayExerciseId!);
        case 'early_deload':
          await _planner.setDeloadWeek(rec.programId, prev['deload_week_no'] as int?);
      }
      await (db.update(db.recommendations)..where((r) => r.id.equals(id))).write(RecommendationsCompanion(
        status: const Value('rejected'),
        previousValues: const Value(null),
        resolvedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ));
    });
  }
}

class RecommendationView {
  RecommendationView(this.rec, this.rule);
  final Recommendation rec;
  final Rule rule;

  Map<String, dynamic> get facts => jsonDecode(rec.facts) as Map<String, dynamic>;
  Map<String, dynamic> get proposal => jsonDecode(rec.proposedChanges) as Map<String, dynamic>;
}
