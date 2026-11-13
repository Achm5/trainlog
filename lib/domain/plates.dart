/// Калькулятор блинов: какие диски вешать на каждую сторону грифа. Чистые функции.
library;

import 'package:trainlog/i18n.dart';

/// Стандартный набор дисков (кг), от большего к меньшему.
const defaultPlates = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25];

class PlateLoad {
  const PlateLoad({required this.perSide, required this.achievedKg, required this.remainderKg});

  /// Диски на одну сторону: вес диска → количество.
  final Map<double, int> perSide;

  /// Фактический итоговый вес штанги с дисками.
  final double achievedKg;

  /// Сколько кг не набирается (на одну сторону, из-за отсутствия мелких дисков). 0 — точно.
  final double remainderKg;

  bool get exact => remainderKg < 1e-9;
}

/// Раскладывает [targetKg] на гриф [barKg] жадным алгоритмом по [plates] (диски без ограничения количества).
/// Возвращает null, если цель меньше веса грифа.
PlateLoad? platesFor({
  required double targetKg,
  double barKg = 20,
  List<double> plates = defaultPlates,
}) {
  if (targetKg < barKg) return null;
  final sides = (targetKg - barKg) / 2;
  var left = sides;
  final perSide = <double, int>{};
  final sorted = [...plates]..sort((a, b) => b.compareTo(a));
  for (final p in sorted) {
    if (p <= 0) continue;
    // Небольшой допуск на погрешность двоичной арифметики.
    final n = ((left + 1e-9) / p).floor();
    if (n > 0) {
      perSide[p] = n;
      left -= n * p;
    }
  }
  final used = sides - left;
  return PlateLoad(
    perSide: perSide,
    achievedKg: barKg + 2 * used,
    remainderKg: left < 1e-9 ? 0 : left,
  );
}

String _kg(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString().replaceAll('.', decSep);

/// «25 × 2 + 10 + 1,25» — диски одной стороны от большего к меньшему.
String platesLabel(PlateLoad load) {
  if (load.perSide.isEmpty) return tr('только гриф');
  final keys = load.perSide.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final k in keys) load.perSide[k]! > 1 ? '${_kg(k)} × ${load.perSide[k]}' : _kg(k),
  ].join(' + ');
}

/// Диски одной стороны списком, от грифа наружу (для рисунка).
List<double> platesSequence(PlateLoad load) {
  final keys = load.perSide.keys.toList()..sort((a, b) => b.compareTo(a));
  return [for (final k in keys) for (var i = 0; i < load.perSide[k]!; i++) k];
}
