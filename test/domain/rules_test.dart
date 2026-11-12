import 'package:flutter_test/flutter_test.dart';
import 'package:trainlog/domain/rules.dart';

const twoRed = RuleDef(
  id: 1,
  code: 'TWO_RED_IN_ROW',
  name: 'Два провала подряд',
  trigger: 'session_completed',
  scope: 'exercise',
  condition: {'type': 'last_sessions_status', 'sessions': 2, 'status': 'failed'},
  action: {'type': 'reduce_weight', 'pct_default': 0.025, 'pct_severe': 0.05, 'severe_shortfall': 6, 'min_step_kg': 2.5},
  priority: 100,
  cooldownDays: 7,
);
const plateau = RuleDef(
  id: 2,
  code: 'E1RM_PLATEAU',
  name: 'Плато',
  trigger: 'week_closed',
  scope: 'exercise',
  condition: {'type': 'e1rm_plateau', 'weeks': 3, 'min_growth_pct': 1.0, 'exclude_deload': true},
  action: {
    'type': 'choice',
    'options': [
      {'type': 'change_variation'},
      {'type': 'add_sets', 'sets': 1},
    ],
  },
  priority: 50,
  cooldownDays: 21,
);
const earlyDeload = RuleDef(
  id: 3,
  code: 'EARLY_DELOAD',
  name: 'Досрочная разгрузка',
  trigger: 'week_closed',
  scope: 'program',
  condition: {'type': 'stall', 'no_growth_weeks': 2, 'compound_share': 0.5, 'min_growth_pct': 1.0, 'bad_sets_share': 0.4},
  action: {'type': 'early_deload'},
  priority: 80,
  cooldownDays: 28,
);
const rules = [twoRed, plateau, earlyDeload];
final now = DateTime(2026, 11, 16, 12);

const failed6 = SessionOutcome(status: 'failed', shortfalls: [6, 7, 6]);
const failedMixed = SessionOutcome(status: 'failed', shortfalls: [2, 4, 6]);

List<Candidate> run(
  String trigger, {
  List<ExerciseFacts> ex = const [],
  ProgramFacts program = const ProgramFacts(),
  List<RecState> existing = const [],
}) =>
    evaluateRules(
        trigger: trigger, rules: rules, exercises: ex, program: program, existing: existing, now: now, weightStep: 2.5);

ExerciseFacts e(int id, {List<SessionOutcome> s = const [], List<double> w = const [], double? weight, bool compound = true}) =>
    ExerciseFacts(pdeId: id, exerciseName: 'Упр. $id', isCompound: compound, lastSessions: s, weeklyE1rm: w, currentWeightKg: weight);

void main() {
  group('TWO_RED_IN_ROW', () {
    test('формула: 100 кг → 95 кг при p = 5%', () {
      expect(reducedWeight(weight: 100, pct: 0.05, step: 2.5), 95);
    });
    test('формула: 60 кг × 2,5% = 1,5 кг → минимальный шаг 2,5 кг → 57,5 кг', () {
      expect(reducedWeight(weight: 60, pct: 0.025, step: 2.5), 57.5);
    });
    test('формула: 200 кг × 2,5% = 5 кг → 195 кг; шаг округления 1 кг', () {
      expect(reducedWeight(weight: 200, pct: 0.025, step: 2.5), 195);
      expect(reducedWeight(weight: 130, pct: 0.05, step: 1), 123); // 6,5 → 7
    });
    test('две последние сессии failed, недобор ≥ 6 во второй → −5%', () {
      final c = run('session_completed', ex: [e(1, s: [failed6, failedMixed], weight: 100)]).single;
      expect(c.rule.code, 'TWO_RED_IN_ROW');
      expect(c.pdeId, 1);
      expect(c.proposal['to_kg'], 95);
      expect(c.facts['pct'], 0.05);
    });
    test('остальные случаи → −2,5%, но не меньше 2,5 кг', () {
      final c = run('session_completed', ex: [e(1, s: [failedMixed, failed6], weight: 60)]).single;
      expect(c.proposal['to_kg'], 57.5);
      expect(c.proposal['delta_kg'], 2.5);
    });
    test('не срабатывает: одна сессия, не подряд, нет веса', () {
      const ok = SessionOutcome(status: 'done', shortfalls: [0, 0]);
      expect(run('session_completed', ex: [e(1, s: [failed6], weight: 100)]), isEmpty);
      expect(run('session_completed', ex: [e(1, s: [failed6, ok, failed6], weight: 100)]), isEmpty);
      expect(run('session_completed', ex: [e(1, s: [ok, failed6], weight: 100)]), isEmpty);
      expect(run('session_completed', ex: [e(1, s: [failed6, failed6])]), isEmpty);
    });
    test('не проверяется на week_closed', () {
      expect(run('week_closed', ex: [e(1, s: [failed6, failed6], weight: 100)]), isEmpty);
    });
  });

  group('cooldown и одна активная рекомендация', () {
    final ex = [e(1, s: [failed6, failed6], weight: 100)];
    test('cooldown после решения: 7 дней', () {
      RecState rec(int daysAgo, String status) =>
          RecState(ruleId: 1, pdeId: 1, status: status, resolvedAt: now.subtract(Duration(days: daysAgo)));
      expect(run('session_completed', ex: ex, existing: [rec(3, 'rejected')]), isEmpty);
      expect(run('session_completed', ex: ex, existing: [rec(6, 'accepted')]), isEmpty);
      expect(run('session_completed', ex: ex, existing: [rec(8, 'rejected')]), hasLength(1));
    });
    test('cooldown другого правила и другого объекта не мешает', () {
      final other = [
        RecState(ruleId: 2, pdeId: 1, status: 'rejected', resolvedAt: now),
        RecState(ruleId: 1, pdeId: 2, status: 'rejected', resolvedAt: now),
      ];
      expect(run('session_completed', ex: ex, existing: other), hasLength(1));
    });
    test('на объекте уже есть новая рекомендация — вторая не создаётся', () {
      expect(run('session_completed', ex: ex, existing: const [RecState(ruleId: 2, pdeId: 1, status: 'new')]), isEmpty);
    });
  });

  group('E1RM_PLATEAU', () {
    test('нет роста ≥ 1% три недели подряд', () {
      expect(noGrowth([100, 100.5, 100, 100.9], weeks: 3, minGrowthPct: 1), isTrue);
      expect(noGrowth([100, 100.5, 101, 100], weeks: 3, minGrowthPct: 1), isFalse); // 101 = +1%
      expect(noGrowth([100, 100, 100], weeks: 3, minGrowthPct: 1), isFalse); // мало истории
      expect(noGrowth([90, 95, 100, 100, 100, 100], weeks: 3, minGrowthPct: 1), isTrue);
    });
    test('срабатывает на week_closed и предлагает выбор', () {
      final c = run('week_closed', ex: [e(1, w: [100, 100, 100.5, 100], compound: false)]).single;
      expect(c.rule.code, 'E1RM_PLATEAU');
      expect(c.proposal['type'], 'choice');
      expect((c.proposal['options'] as List).map((o) => o['type']), ['change_variation', 'add_sets']);
    });
    test('растущее упражнение не трогается', () {
      expect(run('week_closed', ex: [e(1, w: [100, 102, 104, 106], compound: false)]), isEmpty);
    });
  });

  group('EARLY_DELOAD', () {
    final stalled = [100.0, 100.0, 100.0];
    final growing = [100.0, 102.0, 104.0];
    test('≥ 50% базовых без роста 2 недели', () {
      final c = run('week_closed', ex: [e(1, w: stalled), e(2, w: growing), e(3, w: stalled, compound: false)]).single;
      expect(c.rule.code, 'EARLY_DELOAD');
      expect(c.pdeId, isNull);
      expect(c.facts['reason'], 'stall');
    });
    test('меньше половины базовых — не срабатывает', () {
      expect(run('week_closed', ex: [e(1, w: stalled), e(2, w: growing), e(3, w: growing)]), isEmpty);
    });
    test('доля жёлтых и красных подходов ≥ 40%', () {
      final c = run('week_closed',
          ex: [e(1, w: growing)], program: const ProgramFacts(setsDone: 6, setsPartial: 3, setsFailed: 1)).single;
      expect(c.facts['reason'], 'bad_sets');
      expect(run('week_closed',
          ex: [e(1, w: growing)], program: const ProgramFacts(setsDone: 7, setsPartial: 2, setsFailed: 1)), isEmpty);
    });
    test('не ставится, если следующая неделя уже разгрузка или цикл закончился', () {
      final ex = [e(1, w: stalled)];
      expect(run('week_closed', ex: ex, program: const ProgramFacts(nextWeekIsDeload: true)), isEmpty);
      expect(run('week_closed', ex: ex, program: const ProgramFacts(hasNextWeek: false)), isEmpty);
    });
    test('подавляет E1RM_PLATEAU на неделю разгрузки', () {
      final plateaued = [100.0, 100.0, 100.0, 100.0];
      final res = run('week_closed', ex: [e(1, w: plateaued), e(2, w: plateaued)]);
      expect(res.map((c) => c.rule.code), ['EARLY_DELOAD']);
      // Плановая разгрузка на следующей неделе тоже подавляет плато.
      expect(run('week_closed', ex: [e(1, w: plateaued)], program: const ProgramFacts(nextWeekIsDeload: true)), isEmpty);
    });
    test('в cooldown досрочная разгрузка не подавляет плато', () {
      final plateaued = [100.0, 100.0, 100.0, 100.0];
      final res = run('week_closed',
          ex: [e(1, w: plateaued)],
          existing: [RecState(ruleId: 3, pdeId: null, status: 'rejected', resolvedAt: now.subtract(const Duration(days: 5)))]);
      expect(res.map((c) => c.rule.code), ['E1RM_PLATEAU']);
    });
  });

  test('выключенное правило не срабатывает', () {
    const off = RuleDef(
        id: 1, code: 'TWO_RED_IN_ROW', name: '', trigger: 'session_completed', scope: 'exercise',
        condition: {'type': 'last_sessions_status', 'sessions': 2, 'status': 'failed'},
        action: {'type': 'reduce_weight'}, priority: 100, cooldownDays: 7, isActive: false);
    expect(
      evaluateRules(trigger: 'session_completed', rules: const [off], exercises: [e(1, s: [failed6, failed6], weight: 100)],
          program: const ProgramFacts(), existing: const [], now: now, weightStep: 2.5),
      isEmpty,
    );
  });
}
