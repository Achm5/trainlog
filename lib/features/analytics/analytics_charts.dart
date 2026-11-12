import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/analytics_repo.dart';
import '../../data/database.dart';
import '../../domain/dates.dart';

const colorGood = Color(0xFF2E9E4F);
const colorWarn = Color(0xFFE0A800);
const colorBad = Color(0xFFD64545);

/// Общая основа столбчатых графиков «неделя × значение».
class WeekBarChart extends StatelessWidget {
  const WeekBarChart({
    super.key,
    required this.weeks,
    required this.rods,
    this.minY,
    this.maxY,
    this.lines = const [],
    this.shaded = const {},
  });

  /// Понедельники недель по порядку (ось X).
  final List<String> weeks;

  /// Столбец для недели с индексом i.
  final BarChartRodData Function(int i, double width) rods;
  final double? minY;
  final double? maxY;
  final List<HorizontalLine> lines;

  /// Индексы затенённых (разгрузочных) недель.
  final Set<int> shaded;

  @override
  Widget build(BuildContext context) {
    final width = weeks.length > 16 ? 6.0 : (weeks.length > 8 ? 10.0 : 18.0);
    final labelEvery = weeks.length <= 8 ? 1 : (weeks.length / 6).ceil();
    final scheme = Theme.of(context).colorScheme;
    return BarChart(
      BarChartData(
        minY: minY,
        maxY: maxY,
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(horizontalLines: lines),
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, meta) => Text(
                  v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1),
                  style: Theme.of(context).textTheme.labelSmall),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if (i < 0 || i >= weeks.length || i % labelEvery != 0) return const SizedBox.shrink();
                final d = parseYmd(weeks[i]);
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.labelSmall),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < weeks.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                shaded.contains(i)
                    ? rods(i, width).copyWith(
                        backDrawRodData: BackgroundBarChartRodData(
                            show: true, toY: maxY, fromY: minY, color: scheme.onSurface.withValues(alpha: 0.08)))
                    : rods(i, width),
              ],
            ),
        ],
      ),
    );
  }
}

/// Все недели от первой до последней недели с данными, без пропусков.
List<String> continuousWeeks(Iterable<String> weekStarts) {
  final sorted = weekStarts.toSet().toList()..sort();
  if (sorted.isEmpty) return const [];
  final out = <String>[];
  var d = parseYmd(sorted.first);
  final end = parseYmd(sorted.last);
  while (!d.isAfter(end)) {
    out.add(ymd(d));
    d = addDays(d, 7);
  }
  return out;
}

/// Просадки: % изменения 1ПМ к прошлой неделе, падение красным, рост зелёным.
class DipsChart extends StatelessWidget {
  const DipsChart({super.key, required this.rows});
  final List<ExerciseStatView> rows; // одно упражнение

  @override
  Widget build(BuildContext context) {
    final weeks = continuousWeeks(rows.map((r) => r.stat.weekStart));
    final byWeek = {for (final r in rows) r.stat.weekStart: r.stat};
    var bound = 5.0;
    for (final r in rows) {
      final d = r.stat.e1rmDeltaPct?.abs() ?? 0;
      if (d > bound) bound = d;
    }
    bound = (bound * 1.15).ceilToDouble();
    return WeekBarChart(
      weeks: weeks,
      minY: -bound,
      maxY: bound,
      shaded: {
        for (var i = 0; i < weeks.length; i++)
          if (byWeek[weeks[i]]?.isDeload ?? false) i,
      },
      lines: [HorizontalLine(y: 0, color: Theme.of(context).colorScheme.outline, strokeWidth: 1)],
      rods: (i, w) {
        final d = byWeek[weeks[i]]?.e1rmDeltaPct ?? 0;
        return BarChartRodData(toY: d, fromY: 0, width: w, color: d < 0 ? colorBad : colorGood, borderRadius: BorderRadius.zero);
      },
    );
  }
}

/// Объём по группе мышц: подходы за неделю и целевой коридор.
class VolumeChart extends StatelessWidget {
  const VolumeChart({super.key, required this.rows, required this.group, required this.allWeeks});
  final List<WeeklyMuscleVolumeRow> rows; // одна группа
  final MuscleGroup group;
  final List<String> allWeeks;

  @override
  Widget build(BuildContext context) {
    final byWeek = {for (final r in rows) r.weekStart: r.sets};
    var top = group.targetSetsMax.toDouble();
    for (final r in rows) {
      if (r.sets > top) top = r.sets;
    }
    final scheme = Theme.of(context).colorScheme;
    return WeekBarChart(
      weeks: allWeeks,
      minY: 0,
      maxY: (top * 1.15).ceilToDouble(),
      lines: [
        HorizontalLine(y: group.targetSetsMin.toDouble(), color: scheme.outline, strokeWidth: 1, dashArray: [6, 4]),
        HorizontalLine(y: group.targetSetsMax.toDouble(), color: scheme.outline, strokeWidth: 1, dashArray: [6, 4]),
      ],
      rods: (i, w) {
        final v = byWeek[allWeeks[i]] ?? 0;
        final inCorridor = v >= group.targetSetsMin && v <= group.targetSetsMax;
        return BarChartRodData(
            toY: v, width: w, color: inCorridor ? colorGood : (v > group.targetSetsMax ? colorBad : colorWarn),
            borderRadius: BorderRadius.zero);
      },
    );
  }
}

/// Выполнение плана: доли зелёных / жёлтых / красных подходов по неделям.
class AdherenceChart extends StatelessWidget {
  const AdherenceChart({super.key, required this.rows});
  final List<ExerciseStatView> rows;

  @override
  Widget build(BuildContext context) {
    final done = <String, int>{}, partial = <String, int>{}, failed = <String, int>{};
    for (final r in rows) {
      final w = r.stat.weekStart;
      done[w] = (done[w] ?? 0) + r.stat.setsDone;
      partial[w] = (partial[w] ?? 0) + r.stat.setsPartial;
      failed[w] = (failed[w] ?? 0) + r.stat.setsFailed;
    }
    final weeks = continuousWeeks(rows.map((r) => r.stat.weekStart));
    return WeekBarChart(
      weeks: weeks,
      minY: 0,
      maxY: 100,
      rods: (i, w) {
        final d = done[weeks[i]] ?? 0, p = partial[weeks[i]] ?? 0, f = failed[weeks[i]] ?? 0;
        final total = d + p + f;
        if (total == 0) return BarChartRodData(toY: 0, width: w);
        final a = d / total * 100, b = a + p / total * 100;
        return BarChartRodData(
          toY: 100,
          width: w,
          color: Colors.transparent,
          borderRadius: BorderRadius.zero,
          rodStackItems: [
            BarChartRodStackItem(0, a, colorGood),
            BarChartRodStackItem(a, b, colorWarn),
            BarChartRodStackItem(b, 100, colorBad),
          ],
        );
      },
    );
  }
}

/// Вес тела: точки взвешиваний и сглаженный тренд.
class WeightChart extends StatelessWidget {
  const WeightChart({super.key, required this.logs});
  final List<BodyWeightLog> logs;

  @override
  Widget build(BuildContext context) {
    final origin = parseYmd(logs.first.date);
    double x(String d) => daysBetween(origin, parseYmd(d)).toDouble();
    var minY = double.infinity, maxY = 0.0;
    for (final l in logs) {
      for (final v in [l.weightKg, l.trendKg ?? l.weightKg]) {
        if (v < minY) minY = v;
        if (v > maxY) maxY = v;
      }
    }
    final maxX = x(logs.last.date);
    final scheme = Theme.of(context).colorScheme;
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX < 1 ? 1 : maxX,
        minY: (minY - 1).floorToDouble(),
        maxY: (maxY + 1).ceilToDouble(),
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, meta) => Text(v.round().toString(), style: Theme.of(context).textTheme.labelSmall),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: maxX <= 7 ? 1 : (maxX / 5).ceilToDouble(),
              getTitlesWidget: (v, meta) {
                if (v != v.roundToDouble()) return const SizedBox.shrink();
                final d = addDays(origin, v.round());
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.labelSmall),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (final l in logs) FlSpot(x(l.date), l.weightKg)],
            color: scheme.outline,
            barWidth: 0,
            dotData: const FlDotData(show: true),
          ),
          LineChartBarData(
            spots: [for (final l in logs) if (l.trendKg != null) FlSpot(x(l.date), l.trendKg!)],
            color: scheme.primary,
            barWidth: 3,
            isCurved: true,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}
