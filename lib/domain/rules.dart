/// Движок правил (раздел 5 ТЗ). Чистые функции: правила приходят данными
/// (condition / action — уже разобранный JSON), на выходе — кандидаты в рекомендации.
library;

import 'planning.dart';

class RuleDef {
  const RuleDef({
    required this.id,
    required this.code,
    required this.name,
    required this.trigger,
    required this.scope,
    required this.condition,
    required this.action,
    required this.priority,
    required this.cooldownDays,
    this.isActive = true,
  });
  final int id;
  final String code;
  final String name;
  final String trigger; // session_completed | week_closed
  final String scope; // exercise | program
  final Map<String, dynamic> condition;
  final Map<String, dynamic> action;
  final int priority;
  final int cooldownDays;
  final bool isActive;
}

/// Итог одной сессии упражнения: статус и недоборы рабочих подходов.
class SessionOutcome {
  const SessionOutcome({required this.status, required this.shortfalls, this.topOfRange = false, this.rirMargin});
  final String? status;
  final List<int> shortfalls;

  /// Во всех рабочих подходах сделана верхняя граница диапазона повторов.
  final bool topOfRange;

  /// Минимальный по рабочим подходам запас RIR сверх целевого (null — RIR не записан).
  final int? rirMargin;
}

/// Данные упражнения программы для проверки правил.
class ExerciseFacts {
  const ExerciseFacts({
    required this.pdeId,
    required this.exerciseName,
    required this.isCompound,
    this.lastSessions = const [],
    this.weeklyE1rm = const [],
    this.currentWeightKg,
    this.currentRepsMin,
    this.currentRepsMax,
  });
  final int pdeId;
  final String exerciseName;
  final bool isCompound;

  /// Завершённые сессии упражнения, от последней к более ранним.
  final List<SessionOutcome> lastSessions;

  /// Расчётный 1ПМ по неделям в хронологическом порядке, без разгрузочных недель.
  final List<double> weeklyE1rm;

  /// Плановый вес следующей сессии.
  final double? currentWeightKg;

  /// Плановый диапазон повторов следующей сессии.
  final int? currentRepsMin;
  final int? currentRepsMax;
}

/// Данные закрытой недели программы.
class ProgramFacts {
  const ProgramFacts({
    this.setsDone = 0,
    this.setsPartial = 0,
    this.setsFailed = 0,
    this.hasNextWeek = true,
    this.nextWeekIsDeload = false,
  });
  final int setsDone;
  final int setsPartial;
  final int setsFailed;
  final bool hasNextWeek;
  final bool nextWeekIsDeload;

  double get badShare {
    final total = setsDone + setsPartial + setsFailed;
    return total == 0 ? 0 : (setsPartial + setsFailed) / total;
  }
}

/// Существующая рекомендация — для проверки cooldown и «одна активная на объект».
class RecState {
  const RecState({required this.ruleId, required this.pdeId, required this.status, this.resolvedAt});
  final int ruleId;
  final int? pdeId; // null — объект «программа»
  final String status;
  final DateTime? resolvedAt;
}

class Candidate {
  const Candidate({required this.rule, required this.pdeId, required this.facts, required this.proposal});
  final RuleDef rule;
  final int? pdeId;
  final Map<String, dynamic> facts;
  final Map<String, dynamic> proposal;
}

/// Снижение веса в TWO_RED_IN_ROW: w − max(minStep; round_step(w × p)).
double reducedWeight({required double weight, required double pct, required double step, double minStepKg = 2.5}) {
  final byPct = roundToStep(weight * pct, step);
  final delta = byPct > minStepKg ? byPct : minStepKg;
  final w = weight - delta;
  return w < 0 ? 0 : w;
}

/// Нет роста: максимум последних [weeks] недель меньше значения перед ними × (1 + minGrowthPct%).
/// Нужна история минимум из [weeks] + 1 недели.
bool noGrowth(List<double> weeklyE1rm, {required int weeks, required double minGrowthPct}) {
  if (weeks < 1 || weeklyE1rm.length < weeks + 1) return false;
  final base = weeklyE1rm[weeklyE1rm.length - weeks - 1];
  final recent = weeklyE1rm.sublist(weeklyE1rm.length - weeks);
  final best = recent.reduce((a, b) => a > b ? a : b);
  return best < base * (1 + minGrowthPct / 100);
}

/// Повышение веса в AUTO_PROGRESSION: w + max(minStep; round_step(w × p)).
double increasedWeight({required double weight, required double pct, required double step, double minStepKg = 2.5}) {
  final byPct = roundToStep(weight * pct, step);
  return weight + (byPct > minStepKg ? byPct : minStepKg);
}

bool _blocked(RuleDef rule, int? pdeId, List<RecState> existing, DateTime now) {
  for (final r in existing) {
    if (r.pdeId != pdeId) continue;
    // На одном объекте одновременно активна одна рекомендация.
    if (r.status == 'new') return true;
    if (r.ruleId == rule.id && r.resolvedAt != null && rule.cooldownDays > 0) {
      if (now.difference(r.resolvedAt!).inHours < rule.cooldownDays * 24) return true;
    }
  }
  return false;
}

num _n(Map<String, dynamic> m, String key, num fallback) => (m[key] as num?) ?? fallback;

/// Проверяет правила с указанным триггером и возвращает рекомендации к созданию.
/// Учитывает priority (на одном объекте срабатывает старшее), cooldown,
/// единственную активную рекомендацию на объект и подавление E1RM_PLATEAU
/// сработавшей досрочной разгрузкой.
List<Candidate> evaluateRules({
  required String trigger,
  required List<RuleDef> rules,
  required List<ExerciseFacts> exercises,
  required ProgramFacts program,
  required List<RecState> existing,
  required DateTime now,
  required double weightStep,
}) {
  final active = rules.where((r) => r.isActive && r.trigger == trigger).toList()
    ..sort((a, b) => b.priority.compareTo(a.priority));
  final all = <Candidate>[];

  for (final rule in active) {
    final type = rule.condition['type'];
    if (rule.scope == 'program') {
      if (type == 'stall') {
        final c = _evalStall(rule, exercises, program);
        if (c != null) all.add(c);
      }
    } else {
      for (final e in exercises) {
        final Candidate? c = switch (type) {
          'last_sessions_status' => rule.action['type'] == 'reduce_reps'
              ? _evalRepsCut(rule, e)
              : _evalLastSessions(rule, e, weightStep),
          'progression' => _evalProgression(rule, e, weightStep),
          'e1rm_plateau' => _evalPlateau(rule, e),
          _ => null,
        };
        if (c != null) all.add(c);
      }
    }
  }

  // Досрочная разгрузка подавляет рекомендации по плато на неделю разгрузки.
  final deloadComing = program.nextWeekIsDeload ||
      all.any((c) => c.rule.action['type'] == 'early_deload' && !_blocked(c.rule, null, existing, now));

  final result = <Candidate>[];
  final taken = <int?>{};
  for (final c in all) {
    if (c.rule.condition['type'] == 'e1rm_plateau' && deloadComing) continue;
    if (taken.contains(c.pdeId)) continue;
    if (_blocked(c.rule, c.pdeId, existing, now)) continue;
    taken.add(c.pdeId);
    result.add(c);
  }
  return result;
}

Candidate? _evalLastSessions(RuleDef rule, ExerciseFacts e, double step) {
  final n = _n(rule.condition, 'sessions', 2).toInt();
  final status = rule.condition['status'] ?? 'failed';
  if (e.lastSessions.length < n) return null;
  final recent = e.lastSessions.take(n).toList();
  if (!recent.every((s) => s.status == status)) return null;
  final w = e.currentWeightKg;
  if (w == null || w <= 0) return null;

  final severeMiss = _n(rule.action, 'severe_shortfall', 6).toInt();
  final latest = recent.first.shortfalls;
  // p = 5%, если во второй (последней) сессии недобор ≥ 6 во всех рабочих подходах, иначе 2,5%.
  final severe = latest.isNotEmpty && latest.every((m) => m >= severeMiss);
  final pct = (severe ? _n(rule.action, 'pct_severe', 0.05) : _n(rule.action, 'pct_default', 0.025)).toDouble();
  final newW = reducedWeight(
    weight: w,
    pct: pct,
    step: step,
    minStepKg: _n(rule.action, 'min_step_kg', 2.5).toDouble(),
  );
  return Candidate(
    rule: rule,
    pdeId: e.pdeId,
    facts: {
      'exercise': e.exerciseName,
      'sessions': n,
      'status': status,
      'latest_shortfalls': latest,
      'weight_kg': w,
      'pct': pct,
    },
    proposal: {'type': 'reduce_weight', 'from_kg': w, 'to_kg': newW, 'delta_kg': w - newW},
  );
}

/// AUTO_PROGRESSION: последние N сессий выполнены полностью и с запасом —
/// верх диапазона повторов во всех рабочих подходах или RIR выше целевого на rir_margin.
Candidate? _evalProgression(RuleDef rule, ExerciseFacts e, double step) {
  final n = _n(rule.condition, 'sessions', 2).toInt();
  final margin = _n(rule.condition, 'rir_margin', 1).toInt();
  if (n < 1 || e.lastSessions.length < n) return null;
  final recent = e.lastSessions.take(n).toList();
  bool easy(SessionOutcome s) => s.status == 'done' && (s.topOfRange || (s.rirMargin != null && s.rirMargin! >= margin));
  if (!recent.every(easy)) return null;
  final w = e.currentWeightKg;
  if (w == null || w <= 0) return null;
  final pct = _n(rule.action, 'pct', 0.025).toDouble();
  final newW = increasedWeight(weight: w, pct: pct, step: step, minStepKg: _n(rule.action, 'min_step_kg', 2.5).toDouble());
  return Candidate(
    rule: rule,
    pdeId: e.pdeId,
    facts: {
      'exercise': e.exerciseName,
      'sessions': n,
      'reason': recent.every((s) => s.topOfRange) ? 'top_of_range' : 'rir',
      'rir_margin': margin,
      'weight_kg': w,
      'pct': pct,
    },
    proposal: {'type': 'increase_weight', 'from_kg': w, 'to_kg': newW, 'delta_kg': newW - w},
  );
}

/// REPS_CUT: N сессий подряд с заданным статусом (по умолчанию «частично») —
/// диапазон повторов следующих недель сдвигается вниз, вес остаётся.
Candidate? _evalRepsCut(RuleDef rule, ExerciseFacts e) {
  final n = _n(rule.condition, 'sessions', 2).toInt();
  final status = rule.condition['status'] ?? 'partial';
  if (n < 1 || e.lastSessions.length < n) return null;
  final recent = e.lastSessions.take(n).toList();
  if (!recent.every((s) => s.status == status)) return null;
  final min = e.currentRepsMin, max = e.currentRepsMax;
  if (min == null || max == null) return null;
  final cut = _n(rule.action, 'reps', 2).toInt();
  final floor = _n(rule.action, 'min_reps', 1).toInt();
  final newMin = min - cut < floor ? floor : min - cut;
  final newMax = max - cut < newMin ? newMin : max - cut;
  if (newMin == min && newMax == max) return null;
  return Candidate(
    rule: rule,
    pdeId: e.pdeId,
    facts: {
      'exercise': e.exerciseName,
      'sessions': n,
      'status': status,
      'latest_shortfalls': recent.first.shortfalls,
      'weight_kg': e.currentWeightKg,
    },
    proposal: {'type': 'reduce_reps', 'from_min': min, 'from_max': max, 'to_min': newMin, 'to_max': newMax},
  );
}

Candidate? _evalPlateau(RuleDef rule, ExerciseFacts e) {
  final weeks = _n(rule.condition, 'weeks', 3).toInt();
  final minGrowth = _n(rule.condition, 'min_growth_pct', 1.0).toDouble();
  if (!noGrowth(e.weeklyE1rm, weeks: weeks, minGrowthPct: minGrowth)) return null;
  final tail = e.weeklyE1rm.sublist(e.weeklyE1rm.length - weeks - 1);
  return Candidate(
    rule: rule,
    pdeId: e.pdeId,
    facts: {'exercise': e.exerciseName, 'weeks': weeks, 'min_growth_pct': minGrowth, 'e1rm_kg': tail},
    proposal: {
      'type': 'choice',
      'options': rule.action['options'] ??
          [
            {'type': 'change_variation'},
            {'type': 'add_sets', 'sets': 1},
          ],
    },
  );
}

Candidate? _evalStall(RuleDef rule, List<ExerciseFacts> exercises, ProgramFacts program) {
  if (!program.hasNextWeek || program.nextWeekIsDeload) return null;
  final weeks = _n(rule.condition, 'no_growth_weeks', 2).toInt();
  final minGrowth = _n(rule.condition, 'min_growth_pct', 1.0).toDouble();
  final shareLimit = _n(rule.condition, 'compound_share', 0.5).toDouble();
  final badLimit = _n(rule.condition, 'bad_sets_share', 0.4).toDouble();

  final compounds = exercises.where((e) => e.isCompound).toList();
  final stalled = compounds.where((e) => noGrowth(e.weeklyE1rm, weeks: weeks, minGrowthPct: minGrowth)).toList();
  final stalledShare = compounds.isEmpty ? 0.0 : stalled.length / compounds.length;
  final byStall = compounds.isNotEmpty && stalledShare >= shareLimit;
  final byBadSets = program.badShare >= badLimit;
  if (!byStall && !byBadSets) return null;

  return Candidate(
    rule: rule,
    pdeId: null,
    facts: {
      'reason': byStall ? 'stall' : 'bad_sets',
      'stalled': [for (final e in stalled) e.exerciseName],
      'compounds': compounds.length,
      'stalled_share': stalledShare,
      'no_growth_weeks': weeks,
      'bad_share': program.badShare,
      'sets_done': program.setsDone,
      'sets_partial': program.setsPartial,
      'sets_failed': program.setsFailed,
    },
    proposal: {'type': 'early_deload'},
  );
}
