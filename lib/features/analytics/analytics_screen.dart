import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/analytics_repo.dart';
import '../../domain/dates.dart';
import '../../domain/planning.dart';
import '../../providers.dart';
import '../../data/database.dart';
import '../common.dart';
import 'analytics_charts.dart';

enum AnalyticsPeriod {
  cycle('Мезоцикл'),
  m3('3 мес'),
  m6('6 мес'),
  m12('12 мес'),
  all('Всё время');

  const AnalyticsPeriod(this.label);
  final String label;
}

class AnalyticsRange {
  const AnalyticsRange(this.from, this.to);
  final String? from;
  final String? to;

  @override
  bool operator ==(Object other) => other is AnalyticsRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

final _statsProvider = StreamProvider.family<List<ExerciseStatView>, AnalyticsRange>(
    (ref, r) => ref.watch(analyticsRepoProvider).watchExerciseStats(fromYmd: r.from, toYmd: r.to));

final _volumeProvider = StreamProvider.family<List<WeeklyMuscleVolumeRow>, AnalyticsRange>(
    (ref, r) => ref.watch(analyticsRepoProvider).watchMuscleVolume(fromYmd: r.from, toYmd: r.to));

const chartPalette = [
  Color(0xFFEF233C),
  Color(0xFFD9822B),
  Color(0xFF1F9E8A),
  Color(0xFF3F6FD8),
  Color(0xFFB0408F),
  Color(0xFF7A8B1F),
  Color(0xFF8E5BD9),
];

/// Аналитика: рост расчётного 1ПМ по неделям (раздел 4.3 ТЗ).
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  AnalyticsPeriod _period = AnalyticsPeriod.cycle;
  Set<int>? _selected;
  int? _dipsExerciseId;
  int? _muscleId;

  AnalyticsRange _range() {
    final now = today();
    switch (_period) {
      case AnalyticsPeriod.cycle:
        final p = ref.watch(activeProgramProvider).value;
        if (p == null) return AnalyticsRange(ymd(addDays(weekStart(now), -7 * 12)), null);
        final start = weekStart(parseYmd(p.startDate));
        return AnalyticsRange(ymd(start), ymd(addDays(start, 7 * p.weeksCount - 1)));
      case AnalyticsPeriod.m3:
        return AnalyticsRange(ymd(weekStart(addDays(now, -91))), null);
      case AnalyticsPeriod.m6:
        return AnalyticsRange(ymd(weekStart(addDays(now, -182))), null);
      case AnalyticsPeriod.m12:
        return AnalyticsRange(ymd(weekStart(addDays(now, -365))), null);
      case AnalyticsPeriod.all:
        return const AnalyticsRange(null, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(_statsProvider(_range()));
    return Scaffold(
      appBar: AppBar(title: const Text('Аналитика')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<AnalyticsPeriod>(
              showSelectedIcon: false,
              segments: [for (final p in AnalyticsPeriod.values) ButtonSegment(value: p, label: Text(p.label))],
              selected: {_period},
              onSelectionChanged: (s) => setState(() => _period = s.first),
            ),
          ),
          const SizedBox(height: 12),
          Builder(builder: (context) {
            final logs = ref.watch(weightsProvider(_range().from)).value ?? const <BodyWeightLog>[];
            if (logs.length < 2) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Вес тела', style: Theme.of(context).textTheme.titleMedium),
                Text('День × кг: точки — взвешивания, линия — сглаженный тренд. '
                    'Сейчас: ${formatKg(logs.last.weightKg)} кг, тренд ${(logs.last.trendKg ?? logs.last.weightKg).toStringAsFixed(1).replaceAll('.', ',')} кг.'),
                const SizedBox(height: 8),
                SizedBox(height: 200, child: WeightChart(logs: logs)),
                const Divider(height: 32),
              ],
            );
          }),
          AsyncView(
            value: stats,
            builder: (rows) {
              final withE1rm = rows.where((r) => r.stat.bestE1rmKg != null).toList();
              if (withE1rm.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('За выбранный период нет завершённых тренировок. '
                      'Графики появятся после первой завершённой сессии.', textAlign: TextAlign.center),
                );
              }
              // Упражнения по убыванию числа недель с данными; базовые — первыми.
              final counts = <int, int>{};
              final names = <int, String>{};
              final compound = <int>{};
              for (final r in withE1rm) {
                counts[r.exercise.id] = (counts[r.exercise.id] ?? 0) + 1;
                names[r.exercise.id] = r.exercise.name;
                if (r.exercise.kind == 'compound') compound.add(r.exercise.id);
              }
              final ids = counts.keys.toList()
                ..sort((a, b) {
                  final ca = compound.contains(a) ? 0 : 1, cb = compound.contains(b) ? 0 : 1;
                  if (ca != cb) return ca - cb;
                  return counts[b]!.compareTo(counts[a]!);
                });
              final selected = (_selected ?? ids.take(3).toSet()).where(ids.contains).toSet();
              final colorOf = {for (var i = 0; i < ids.length; i++) ids[i]: chartPalette[i % chartPalette.length]};

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Рост расчётного 1ПМ', style: Theme.of(context).textTheme.titleMedium),
                  const Text('Неделя × кг. Недели разгрузки затенены.'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final id in ids)
                        FilterChip(
                          label: Text(names[id]!),
                          selected: selected.contains(id),
                          avatar: CircleAvatar(backgroundColor: colorOf[id], radius: 6),
                          showCheckmark: false,
                          onSelected: (on) => setState(() {
                            final s = {...selected};
                            on ? s.add(id) : s.remove(id);
                            _selected = s;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 280,
                    child: E1rmChart(rows: withE1rm.where((r) => selected.contains(r.exercise.id)).toList(), colorOf: colorOf),
                  ),
                  const SizedBox(height: 16),
                  for (final id in ids.where(selected.contains))
                    Builder(builder: (context) {
                      final series = withE1rm.where((r) => r.exercise.id == id).toList();
                      final last = series.last.stat;
                      final d = last.e1rmDeltaPct;
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(backgroundColor: colorOf[id], radius: 8),
                        title: Text(names[id]!),
                        subtitle: Text('Неделя с ${ruDate(parseYmd(last.weekStart))}'
                            '${d == null ? '' : ' · ${d >= 0 ? '+' : ''}${d.toStringAsFixed(1).replaceAll('.', ',')}% к прошлой'}'),
                        trailing: Text('${formatKg(last.bestE1rmKg)} кг', style: Theme.of(context).textTheme.titleMedium),
                      );
                    }),
                  const Divider(height: 32),
                  Text('Просадки', style: Theme.of(context).textTheme.titleMedium),
                  const Text('Изменение 1ПМ к прошлой неделе, %. Падение — красным, рост — зелёным.'),
                  Builder(builder: (context) {
                    final dipId = ids.contains(_dipsExerciseId) ? _dipsExerciseId! : ids.first;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButton<int>(
                          isExpanded: true,
                          value: dipId,
                          items: [for (final id in ids) DropdownMenuItem(value: id, child: Text(names[id]!))],
                          onChanged: (v) => setState(() => _dipsExerciseId = v),
                        ),
                        SizedBox(
                          height: 200,
                          child: DipsChart(rows: withE1rm.where((r) => r.exercise.id == dipId).toList()),
                        ),
                      ],
                    );
                  }),
                  const Divider(height: 32),
                  Text('Объём по группам мышц', style: Theme.of(context).textTheme.titleMedium),
                  const Text('Рабочие подходы в неделю с учётом долей. Пунктир — целевой коридор.'),
                  Builder(builder: (context) {
                    final groups = ref.watch(muscleGroupsProvider).value ?? const <MuscleGroup>[];
                    final volume = ref.watch(_volumeProvider(_range())).value ?? const <WeeklyMuscleVolumeRow>[];
                    if (groups.isEmpty) return const SizedBox.shrink();
                    final group = groups.firstWhere((g) => g.id == _muscleId, orElse: () => groups.first);
                    final weeks = continuousWeeks(rows.map((r) => r.stat.weekStart));
                    final own = volume.where((v) => v.muscleGroupId == group.id).toList();
                    final last = own.isEmpty ? null : own.last;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButton<int>(
                          isExpanded: true,
                          value: group.id,
                          items: [for (final g in groups) DropdownMenuItem(value: g.id, child: Text(g.name))],
                          onChanged: (v) => setState(() => _muscleId = v),
                        ),
                        SizedBox(height: 200, child: VolumeChart(rows: own, group: group, allWeeks: weeks)),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('Цель: ${group.targetSetsMin}–${group.targetSetsMax} подходов. '
                              '${last == null ? 'Данных за период нет.' : 'Последняя неделя: ${formatKg(last.sets)} подх., тоннаж ${last.tonnageKg.round()} кг.'}'),
                        ),
                      ],
                    );
                  }),
                  const Divider(height: 32),
                  Text('Выполнение плана', style: Theme.of(context).textTheme.titleMedium),
                  const Text('Доля подходов по статусам за неделю, %: зелёные / жёлтые / красные.'),
                  const SizedBox(height: 8),
                  SizedBox(height: 180, child: AdherenceChart(rows: rows)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Линейный график 1ПМ: ось X — недели, линия на упражнение, разгрузочные недели затенены.
class E1rmChart extends StatelessWidget {
  const E1rmChart({super.key, required this.rows, required this.colorOf});
  final List<ExerciseStatView> rows;
  final Map<int, Color> colorOf;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const Center(child: Text('Выберите упражнение'));
    final origin = rows.map((r) => parseYmd(r.stat.weekStart)).reduce((a, b) => a.isBefore(b) ? a : b);
    double x(String weekStartYmd) => daysBetween(origin, parseYmd(weekStartYmd)) / 7;

    final byExercise = <int, List<FlSpot>>{};
    final deloadXs = <double>{};
    var minY = double.infinity, maxY = 0.0, maxX = 0.0;
    for (final r in rows) {
      final px = x(r.stat.weekStart);
      final py = r.stat.bestE1rmKg!;
      byExercise.putIfAbsent(r.exercise.id, () => []).add(FlSpot(px, py));
      if (r.stat.isDeload) deloadXs.add(px);
      if (py < minY) minY = py;
      if (py > maxY) maxY = py;
      if (px > maxX) maxX = px;
    }
    final pad = ((maxY - minY) * 0.15).clamp(2.5, 50).toDouble();
    final scheme = Theme.of(context).colorScheme;
    final labelStep = maxX <= 8 ? 1.0 : (maxX / 6).ceilToDouble();

    return LineChart(
      LineChartData(
        minX: -0.5,
        maxX: maxX + 0.5,
        minY: (minY - pad).floorToDouble(),
        maxY: (maxY + pad).ceilToDouble(),
        rangeAnnotations: RangeAnnotations(
          verticalRangeAnnotations: [
            for (final dx in deloadXs)
              VerticalRangeAnnotation(x1: dx - 0.5, x2: dx + 0.5, color: scheme.onSurface.withValues(alpha: 0.08)),
          ],
        ),
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, meta) => Text(v.round().toString(), style: Theme.of(context).textTheme.labelSmall),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: labelStep,
              getTitlesWidget: (v, meta) {
                if (v < 0 || v > maxX || v != v.roundToDouble()) return const SizedBox.shrink();
                final d = addDays(origin, (v * 7).round());
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
          for (final e in byExercise.entries)
            LineChartBarData(
              spots: e.value,
              color: colorOf[e.key],
              barWidth: 3,
              dotData: const FlDotData(show: true),
            ),
        ],
      ),
    );
  }
}
