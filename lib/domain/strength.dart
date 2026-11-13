/// Расчёты журнала и аналитики силы (разделы 3.2 и 4.1 ТЗ). Чистые функции.
library;

import 'package:trainlog/i18n.dart';
import 'planning.dart';

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
        done => tr('Выполнен'),
        minorMiss => tr('Небольшой недобор'),
        partial => tr('Частично'),
        failed => tr('Провал'),
        skipped => tr('Пропущен'),
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

/// Ход тренировки: закрытые рабочие подходы, их общее число и тоннаж.
class SessionProgress {
  const SessionProgress({required this.closed, required this.total, required this.tonnageKg});

  /// Рабочие подходы с результатом или пропущенные.
  final int closed;
  final int total;
  final double tonnageKg;

  double get share => total == 0 ? 0 : closed / total;
  bool get complete => total > 0 && closed >= total;
}

/// Подход для расчёта хода тренировки и строки «прошлый раз».
typedef SetBrief = ({bool isWarmup, double? weightKg, int? reps, bool skipped});

SessionProgress sessionProgress(Iterable<SetBrief> sets) {
  var closed = 0, total = 0;
  var ton = 0.0;
  for (final s in sets) {
    if (s.isWarmup) continue;
    total++;
    if (s.skipped) {
      closed++;
    } else if (s.reps != null) {
      closed++;
      ton += (s.weightKg ?? 0) * s.reps!;
    }
  }
  return SessionProgress(closed: closed, total: total, tonnageKg: ton);
}

/// Краткая запись рабочих подходов: «100 × 8, 8, 7 · 102,5 × 6» — повторы группируются по весу.
String setsSummary(Iterable<SetBrief> sets) {
  final groups = <(double?, List<int>)>[];
  for (final s in sets) {
    if (s.isWarmup || s.skipped || s.reps == null) continue;
    if (groups.isNotEmpty && groups.last.$1 == s.weightKg) {
      groups.last.$2.add(s.reps!);
    } else {
      groups.add((s.weightKg, [s.reps!]));
    }
  }
  return [
    for (final (w, reps) in groups) w == null || w == 0 ? reps.join(', ') : '${formatKg(w)} × ${reps.join(', ')}',
  ].join(' · ');
}

/// Подход для подсказки «что дальше»: у невыполненного — плановые вес и повторы.
typedef PendingSet = ({bool isWarmup, bool closed, double? weightKg, int? reps});

/// Следующий невыполненный рабочий подход тренировки.
class NextSet {
  const NextSet({
    required this.exercise,
    required this.setNo,
    required this.setsTotal,
    required this.weightKg,
    required this.reps,
  });
  final String exercise;

  /// Номер рабочего подхода в упражнении, с единицы.
  final int setNo;
  final int setsTotal;
  final double? weightKg;
  final int? reps;
}

/// Первый по порядку невыполненный рабочий подход; null — все подходы закрыты (или их нет).
NextSet? nextSet(Iterable<({String name, List<PendingSet> sets})> exercises) {
  for (final e in exercises) {
    final work = [for (final s in e.sets) if (!s.isWarmup) s];
    for (var i = 0; i < work.length; i++) {
      if (work[i].closed) continue;
      return NextSet(
        exercise: e.name,
        setNo: i + 1,
        setsTotal: work.length,
        weightKg: work[i].weightKg,
        reps: work[i].reps,
      );
    }
  }
  return null;
}
