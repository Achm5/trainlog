import 'package:drift/drift.dart';

import '../domain/dates.dart';
import '../domain/overtraining.dart';
import 'database.dart';

/// Чтение недельных агрегатов для графиков.
class AnalyticsRepo {
  AnalyticsRepo(this.db);
  final AppDatabase db;

  /// Недельная статистика упражнений начиная с недели [fromYmd] (null — за всё время).
  Stream<List<ExerciseStatView>> watchExerciseStats({String? fromYmd, String? toYmd}) {
    final q = db.select(db.weeklyExerciseStats).join([
      innerJoin(db.exercises, db.exercises.id.equalsExp(db.weeklyExerciseStats.exerciseId)),
    ])
      ..orderBy([OrderingTerm.asc(db.weeklyExerciseStats.weekStart)]);
    if (fromYmd != null) q.where(db.weeklyExerciseStats.weekStart.isBiggerOrEqualValue(fromYmd));
    if (toYmd != null) q.where(db.weeklyExerciseStats.weekStart.isSmallerOrEqualValue(toYmd));
    return q.watch().map((rows) =>
        [for (final r in rows) ExerciseStatView(r.readTable(db.weeklyExerciseStats), r.readTable(db.exercises))]);
  }

  /// Недельный объём по группам мышц.
  Stream<List<WeeklyMuscleVolumeRow>> watchMuscleVolume({String? fromYmd, String? toYmd}) {
    final q = db.select(db.weeklyMuscleVolume)..orderBy([(v) => OrderingTerm.asc(v.weekStart)]);
    if (fromYmd != null) q.where((v) => v.weekStart.isBiggerOrEqualValue(fromYmd));
    if (toYmd != null) q.where((v) => v.weekStart.isSmallerOrEqualValue(toYmd));
    return q.watch();
  }

  /// [count] календарных недель подряд, последняя начинается в [lastWeekStart].
  Future<List<LoadWeek>> loadWeeks(DateTime lastWeekStart, {int count = 8}) async {
    final first = addDays(weekStart(lastWeekStart), -7 * (count - 1));
    final q = db.select(db.weeklyExerciseStats).join([
      innerJoin(db.exercises, db.exercises.id.equalsExp(db.weeklyExerciseStats.exerciseId)),
    ])
      ..where(db.weeklyExerciseStats.weekStart.isBetweenValues(ymd(first), ymd(weekStart(lastWeekStart))));
    final byWeek = <String, List<(WeeklyExerciseStat, Exercise)>>{};
    for (final r in await q.get()) {
      final st = r.readTable(db.weeklyExerciseStats);
      byWeek.putIfAbsent(st.weekStart, () => []).add((st, r.readTable(db.exercises)));
    }
    return [
      for (var i = 0; i < count; i++)
        () {
          final ws = ymd(addDays(first, 7 * i));
          final rows = byWeek[ws] ?? const [];
          var ton = 0.0;
          var done = 0, partial = 0, failed = 0;
          var deload = false;
          final e1rm = <String, double>{};
          for (final (st, ex) in rows) {
            ton += st.tonnageKg;
            done += st.setsDone;
            partial += st.setsPartial;
            failed += st.setsFailed;
            deload = deload || st.isDeload;
            if (st.bestE1rmKg != null) e1rm[ex.name] = st.bestE1rmKg!;
          }
          return LoadWeek(
            weekStart: ws,
            tonnageKg: ton,
            setsDone: done,
            setsPartial: partial,
            setsFailed: failed,
            isDeload: deload,
            e1rmByExercise: e1rm,
          );
        }(),
    ];
  }

  /// Подходы по группам мышц за неделю [weekStartYmd] и их целевые коридоры.
  Future<List<MuscleLoad>> muscleLoad(String weekStartYmd) async {
    final q = db.select(db.weeklyMuscleVolume).join([
      innerJoin(db.muscleGroups, db.muscleGroups.id.equalsExp(db.weeklyMuscleVolume.muscleGroupId)),
    ])
      ..where(db.weeklyMuscleVolume.weekStart.equals(weekStartYmd));
    return [
      for (final r in await q.get())
        MuscleLoad(
          name: r.readTable(db.muscleGroups).name,
          sets: r.readTable(db.weeklyMuscleVolume).sets,
          targetMax: r.readTable(db.muscleGroups).targetSetsMax,
        ),
    ];
  }

  /// Признаки перетренированности по закрытым неделям до недели [anyDay] (не включая её).
  Future<OvertrainingCheck> overtraining(DateTime anyDay) async {
    final lastClosed = addDays(weekStart(anyDay), -7);
    final weeks = await loadWeeks(lastClosed);
    final signals = overtrainingSignals(weeks, await muscleLoad(ymd(lastClosed)));
    return OvertrainingCheck(ymd(lastClosed), signals);
  }
}

class OvertrainingCheck {
  OvertrainingCheck(this.weekStart, this.signals);
  final String weekStart;
  final List<OvertrainingSignal> signals;
  bool get warn => overtrainingWarning(signals);
}

class ExerciseStatView {
  ExerciseStatView(this.stat, this.exercise);
  final WeeklyExerciseStat stat;
  final Exercise exercise;
}
