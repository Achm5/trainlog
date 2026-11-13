/// Признаки перетренированности по журналу. Чистые функции.
/// Это ориентир по нагрузке, а не медицинская оценка.
library;

/// Закрытая календарная неделя (с понедельника) — агрегаты завершённых тренировок.
class LoadWeek {
  const LoadWeek({
    required this.weekStart,
    this.tonnageKg = 0,
    this.setsDone = 0,
    this.setsPartial = 0,
    this.setsFailed = 0,
    this.isDeload = false,
    this.e1rmByExercise = const {},
  });
  final String weekStart;
  final double tonnageKg;
  final int setsDone;
  final int setsPartial;
  final int setsFailed;
  final bool isDeload;

  /// Лучший расчётный 1ПМ недели: название упражнения → кг.
  final Map<String, double> e1rmByExercise;

  int get totalSets => setsDone + setsPartial + setsFailed;
  bool get trained => totalSets > 0 || tonnageKg > 0;
  double get badShare => totalSets == 0 ? 0 : (setsPartial + setsFailed) / totalSets;
}

/// Подходы группы мышц за неделю и верх целевого коридора.
class MuscleLoad {
  const MuscleLoad({required this.name, required this.sets, required this.targetMax});
  final String name;
  final double sets;
  final int targetMax;
}

class OvertrainingThresholds {
  const OvertrainingThresholds({
    this.minSignals = 2,
    this.e1rmDropWeeks = 2,
    this.e1rmDropShare = 0.5,
    this.badSetsShare = 0.3,
    this.badSetsWeeks = 2,
    this.spikeRatio = 1.3,
    this.spikeBaseWeeks = 4,
    this.volumeOverK = 1.2,
    this.weeksWithoutDeload = 6,
  });

  /// Сколько признаков нужно одновременно, чтобы показать предупреждение.
  final int minSignals;
  final int e1rmDropWeeks;
  final double e1rmDropShare;
  final double badSetsShare;
  final int badSetsWeeks;
  final double spikeRatio;
  final int spikeBaseWeeks;
  final double volumeOverK;
  final int weeksWithoutDeload;
}

class OvertrainingSignal {
  const OvertrainingSignal(this.code, this.text);
  final String code;
  final String text;

  @override
  String toString() => '$code: $text';
}

String _pct(double v) => '${(v * 100).round()}%';
String _num(double v) {
  final r = (v * 10).round() / 10;
  return (r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(1)).replaceAll('.', ',');
}

/// Признаки по закрытым неделям [weeks] (подряд по календарю, последняя — только что закрытая)
/// и объёму групп мышц последней недели [lastWeekMuscles].
List<OvertrainingSignal> overtrainingSignals(
  List<LoadWeek> weeks,
  List<MuscleLoad> lastWeekMuscles, {
  OvertrainingThresholds t = const OvertrainingThresholds(),
}) {
  final out = <OvertrainingSignal>[];
  if (weeks.isEmpty) return out;
  final last = weeks.last;
  final work = [for (final w in weeks) if (w.trained && !w.isDeload) w];

  // 1. Расчётный 1ПМ снижается несколько рабочих недель подряд у большинства упражнений.
  if (work.length >= t.e1rmDropWeeks + 1) {
    final window = work.sublist(work.length - t.e1rmDropWeeks - 1);
    final names = window.last.e1rmByExercise.keys.where((n) => window.every((w) => w.e1rmByExercise.containsKey(n)));
    var considered = 0;
    final falling = <String>[];
    for (final n in names) {
      considered++;
      var down = true;
      for (var i = 1; i < window.length; i++) {
        if (window[i].e1rmByExercise[n]! >= window[i - 1].e1rmByExercise[n]!) down = false;
      }
      if (down) falling.add(n);
    }
    if (considered >= 2 && falling.length / considered >= t.e1rmDropShare) {
      out.add(OvertrainingSignal('e1rm_drop',
          'Расчётный 1ПМ снижается ${t.e1rmDropWeeks} нед. подряд в ${falling.length} из $considered упражнений: '
          '${falling.take(4).join(', ')}${falling.length > 4 ? '…' : ''}.'));
    }
  }

  // 2. Много жёлтых и красных подходов несколько рабочих недель подряд.
  if (work.length >= t.badSetsWeeks) {
    final tail = work.sublist(work.length - t.badSetsWeeks);
    if (tail.every((w) => w.totalSets > 0 && w.badShare >= t.badSetsShare)) {
      out.add(OvertrainingSignal('bad_sets',
          'Недоборы повторов: ${tail.map((w) => _pct(w.badShare)).join(', ')} подходов жёлтые и красные '
          '(${t.badSetsWeeks} нед. подряд, порог ${_pct(t.badSetsShare)}).'));
    }
  }

  // 3. Скачок нагрузки: тоннаж последней недели к среднему предыдущих.
  if (last.trained && !last.isDeload && weeks.length > 1) {
    final prev = weeks.sublist(0, weeks.length - 1);
    final base = prev.sublist(prev.length > t.spikeBaseWeeks ? prev.length - t.spikeBaseWeeks : 0).where((w) => w.trained).toList();
    if (base.length >= 3) {
      final avg = base.map((w) => w.tonnageKg).reduce((a, b) => a + b) / base.length;
      if (avg > 0 && last.tonnageKg / avg >= t.spikeRatio) {
        out.add(OvertrainingSignal('load_spike',
            'Тоннаж недели в ${_num(last.tonnageKg / avg)} раза выше среднего за ${base.length} нед. '
            '(${_num(last.tonnageKg / 1000)} т против ${_num(avg / 1000)} т).'));
      }
    }
  }

  // 4. Объём выше верхней границы коридора.
  if (last.trained) {
    final over = [for (final m in lastWeekMuscles) if (m.targetMax > 0 && m.sets > m.targetMax * t.volumeOverK) m];
    if (over.isNotEmpty) {
      out.add(OvertrainingSignal('volume_over',
          'Объём выше коридора больше чем на ${_pct(t.volumeOverK - 1)}: '
          '${over.map((m) => '${m.name} — ${_num(m.sets)} подх. при максимуме ${m.targetMax}').join('; ')}.'));
    }
  }

  // 5. Долго без разгрузки: подряд идущие тренировочные недели без разгрузки и без отдыха.
  var streak = 0;
  for (final w in weeks.reversed) {
    if (!w.trained || w.isDeload) break;
    streak++;
  }
  if (streak >= t.weeksWithoutDeload) {
    out.add(OvertrainingSignal('no_deload', '$streak нед. тренировок подряд без разгрузки и отдыха.'));
  }
  return out;
}

/// Предупреждение показывается, если признаков не меньше [OvertrainingThresholds.minSignals].
bool overtrainingWarning(List<OvertrainingSignal> signals, {OvertrainingThresholds t = const OvertrainingThresholds()}) =>
    signals.length >= t.minSignals;
