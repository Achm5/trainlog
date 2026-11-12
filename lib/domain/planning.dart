/// Расчёты планировщика (раздел 2 ТЗ). Чистые функции.
library;

const _eps = 1e-9;

/// Округление вниз до шага.
double roundDownToStep(double value, double step) {
  if (step <= 0) return value;
  return ((value + _eps) / step).floorToDouble() * step;
}

/// Округление до ближайшего шага.
double roundToStep(double value, double step) {
  if (step <= 0) return value;
  return ((value + _eps) / step).roundToDouble() * step;
}

enum LoadMode {
  manual('manual', 'Вручную'),
  percent('percent', '% от 1ПМ'),
  linear('linear', 'Линейный шаг');

  const LoadMode(this.db, this.label);
  final String db;
  final String label;

  static LoadMode fromDb(String v) => values.firstWhere((m) => m.db == v, orElse: () => manual);
}

/// Целевой вес недели по режиму нагрузки, округлённый вниз до шага.
/// [workWeekIndex] — номер рабочей недели с нуля (разгрузочные не считаются).
double? plannedWeight({
  required LoadMode mode,
  required int workWeekIndex,
  required double step,
  double? manualWeight,
  double? percent1rm,
  double? e1rm,
  double? startWeight,
  double? weeklyStep,
}) {
  switch (mode) {
    case LoadMode.manual:
      return manualWeight == null ? null : roundDownToStep(manualWeight, step);
    case LoadMode.percent:
      if (percent1rm == null || e1rm == null) return null;
      return roundDownToStep(e1rm * percent1rm / 100, step);
    case LoadMode.linear:
      if (startWeight == null) return null;
      return roundDownToStep(startWeight + (weeklyStep ?? 0) * workWeekIndex, step);
  }
}

class WeekTargets {
  const WeekTargets({required this.sets, required this.weightKg, required this.targetRir});
  final int sets;
  final double? weightKg;
  final int targetRir;
}

/// Разгрузочная неделя из предыдущей рабочей (раздел 2.4):
/// подходы × k (вверх, не меньше 1), вес × k (вниз до шага), RIR + добавка (не больше 5).
WeekTargets deloadFrom({
  required int sets,
  required double? weightKg,
  required int targetRir,
  required double setsK,
  required double weightK,
  required int rirAdd,
  required double step,
}) {
  final s = (sets * setsK - _eps).ceil();
  final rir = targetRir + rirAdd;
  return WeekTargets(
    sets: s < 1 ? 1 : s,
    weightKg: weightKg == null ? null : roundDownToStep(weightKg * weightK, step),
    targetRir: rir > 5 ? 5 : rir,
  );
}

class DayLoadItem {
  const DayLoadItem({required this.sets, required this.restSec});
  final int sets;
  final int restSec;
}

/// Расчётная длительность дня в секундах (раздел 2.5):
/// Σ подходы × (время подхода + отдых) + разминка.
int dayDurationSec(Iterable<DayLoadItem> items, {required int setDurationSec, required int warmupMin}) {
  var total = 0;
  var any = false;
  for (final i in items) {
    any = true;
    total += i.sets * (setDurationSec + i.restSec);
  }
  return any ? total + warmupMin * 60 : 0;
}

String formatKg(double? v) {
  if (v == null) return '—';
  final r = (v * 100).round() / 100;
  if (r == r.roundToDouble()) return r.toStringAsFixed(0);
  final s = r.toStringAsFixed(2);
  return (s.endsWith('0') ? s.substring(0, s.length - 1) : s).replaceAll('.', ',');
}
