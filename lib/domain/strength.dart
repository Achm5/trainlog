/// Расчёты журнала и аналитики силы (разделы 3.2 и 4.1 ТЗ). Чистые функции.
library;

enum SetStatus {
  done('done'),
  minorMiss('minor_miss'),
  partial('partial'),
  failed('failed'),
  skipped('skipped');

  const SetStatus(this.db);
  final String db;

  static SetStatus? fromDb(String? v) {
    if (v == null) return null;
    for (final s in values) {
      if (s.db == v) return s;
    }
    return null;
  }

  String get label => switch (this) {
        done => 'Выполнен',
        minorMiss => 'Небольшой недобор',
        partial => 'Частично',
        failed => 'Провал',
        skipped => 'Пропущен',
      };
}

/// Недобор = плановые повторы (нижняя граница) − фактические.
int shortfall(int plannedRepsMin, int actualReps) => plannedRepsMin - actualReps;

/// Статус выполненного подхода по недобору (таблица 3.2).
SetStatus statusForShortfall(int miss) {
  if (miss <= 0) return SetStatus.done;
  if (miss <= 2) return SetStatus.minorMiss;
  if (miss <= 5) return SetStatus.partial;
  return SetStatus.failed;
}

/// Статус подхода. Для свободной тренировки ([plannedRepsMin] == null) статус не считается.
SetStatus? setStatus({required int? plannedRepsMin, required int? actualReps, bool skipped = false}) {
  if (skipped) return SetStatus.skipped;
  if (plannedRepsMin == null || actualReps == null) return null;
  return statusForShortfall(shortfall(plannedRepsMin, actualReps));
}

/// Флаг «вес снижен»: фактический вес ниже планового.
bool isWeightReduced(double? plannedWeight, double? actualWeight) =>
    plannedWeight != null && actualWeight != null && actualWeight < plannedWeight - 1e-9;

int _severity(SetStatus s) => switch (s) {
      SetStatus.done => 0,
      SetStatus.minorMiss => 1,
      SetStatus.partial => 2,
      SetStatus.failed => 3,
      SetStatus.skipped => -1,
    };

/// Статус упражнения = худший статус его рабочих подходов.
/// Пропущенные подходы не ухудшают статус; если пропущены все — skipped.
SetStatus? worstStatus(Iterable<SetStatus?> statuses) {
  SetStatus? worst;
  var anySkipped = false;
  for (final s in statuses) {
    if (s == null) continue;
    if (s == SetStatus.skipped) {
      anySkipped = true;
      continue;
    }
    if (worst == null || _severity(s) > _severity(worst)) worst = s;
  }
  return worst ?? (anySkipped ? SetStatus.skipped : null);
}

/// Расчётный 1ПМ по Эпли: w × (1 + r / 30).
/// При [useRir] в формулу подставляется r + RIR. r = 1 → вес.
/// Подходы с r > 12 (с учётом RIR, если он включён) в расчёт не идут → null.
double? epley1rm({required double weight, required int reps, int? rir, bool useRir = true}) {
  if (weight <= 0 || reps <= 0) return null;
  final r = reps + (useRir ? (rir ?? 0) : 0);
  if (r > 12) return null;
  if (r == 1) return weight;
  return weight * (1 + r / 30);
}

/// Изменение в процентах к предыдущему значению.
double? deltaPct(double? current, double? previous) {
  if (current == null || previous == null || previous <= 0) return null;
  return (current - previous) / previous * 100;
}
