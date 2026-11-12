import 'package:drift/drift.dart';

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
}

class ExerciseStatView {
  ExerciseStatView(this.stat, this.exercise);
  final WeeklyExerciseStat stat;
  final Exercise exercise;
}
