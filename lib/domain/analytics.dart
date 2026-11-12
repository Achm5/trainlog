/// Недельные агрегаты аналитики (раздел 4 ТЗ). Чистые функции.
library;

import 'strength.dart';

/// Факт одного подхода из завершённой сессии.
class SetFact {
  const SetFact({
    required this.exerciseId,
    required this.isWarmup,
    required this.weightKg,
    required this.reps,
    required this.e1rmKg,
    required this.status,
    required this.isDeloadWeek,
    required this.muscleShares,
  });
  final int exerciseId;
  final bool isWarmup;
  final double? weightKg;
  final int? reps;
  final double? e1rmKg;
  final SetStatus? status;
  final bool isDeloadWeek;

  /// Доли групп мышц в упражнении: id группы → доля.
  final Map<int, double> muscleShares;

  bool get isWork => !isWarmup && status != SetStatus.skipped && (reps ?? 0) > 0;
}

class ExerciseWeekAgg {
  double? bestE1rm;
  double tonnage = 0;
  int workSets = 0;
  int setsDone = 0;
  int setsPartial = 0;
  int setsFailed = 0;
  bool isDeload = false;
}

class MuscleWeekAgg {
  double sets = 0;
  double tonnage = 0;
}

class WeekAggregates {
  final Map<int, ExerciseWeekAgg> byExercise = {};
  final Map<int, MuscleWeekAgg> byMuscle = {};
}

/// Агрегаты недели из рабочих (не разминочных) подходов.
/// 1ПМ недели = максимум по подходам; подходы на группу = Σ доля; тоннаж = Σ вес × повторы × доля.
WeekAggregates aggregateWeek(Iterable<SetFact> facts) {
  final out = WeekAggregates();
  for (final f in facts) {
    if (f.isWarmup) continue;
    final ex = out.byExercise.putIfAbsent(f.exerciseId, ExerciseWeekAgg.new);
    if (f.isDeloadWeek) ex.isDeload = true;
    switch (f.status) {
      case SetStatus.done || SetStatus.minorMiss:
        ex.setsDone++;
      case SetStatus.partial:
        ex.setsPartial++;
      case SetStatus.failed:
        ex.setsFailed++;
      case SetStatus.skipped || null:
        break;
    }
    if (!f.isWork) continue;
    ex.workSets++;
    final ton = (f.weightKg ?? 0) * f.reps!;
    ex.tonnage += ton;
    final e = f.e1rmKg;
    if (e != null && (ex.bestE1rm == null || e > ex.bestE1rm!)) ex.bestE1rm = e;
    f.muscleShares.forEach((muscleId, share) {
      final m = out.byMuscle.putIfAbsent(muscleId, MuscleWeekAgg.new);
      m.sets += share;
      m.tonnage += ton * share;
    });
  }
  return out;
}
