import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/analytics_repo.dart';
import '../../domain/dates.dart';
import '../../domain/planning.dart';
import '../../providers.dart';
import '../../data/database.dart';
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

/// Аналитика по темам: сила, объём, выполнение плана, вес тела.
/// Сверху — сводка периода, в каждой вкладке — вывод одной фразой, график и расшифровка.
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

  String _pct(double v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1).replaceAll('.', ',')}%';

  @override
  Widget build(BuildContext context) {
    final range = _range();
    final rows = ref.watch(_statsProvider(range)).value ?? const <ExerciseStatView>[];
    final volume = ref.watch(_volumeProvider(range)).value ?? const <WeeklyMuscleVolumeRow>[];
    final weights = ref.watch(weightsProvider(range.from)).value ?? const <BodyWeightLog>[];
    final groups = ref.watch(muscleGroupsProvider).value ?? const <MuscleGroup>[];
    final history = ref.watch(historyProvider).value ?? const [];
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    // ---- Сила ----
    final withE1rm = rows.where((r) => r.stat.bestE1rmKg != null).toList();
    final counts = <int, int>{};
    final names = <int, String>{};
    final compound = <int>{};
    final series = <int, List<ExerciseStatView>>{};
    for (final r in withE1rm) {
      counts[r.exercise.id] = (counts[r.exercise.id] ?? 0) + 1;
      names[r.exercise.id] = r.exercise.name;
      if (r.exercise.kind == 'compound') compound.add(r.exercise.id);
      series.putIfAbsent(r.exercise.id, () => []).add(r);
    }
    final ids = counts.keys.toList()
      ..sort((a, b) {
        final ca = compound.contains(a) ? 0 : 1, cb = compound.contains(b) ? 0 : 1;
        if (ca != cb) return ca - cb;
        return counts[b]!.compareTo(counts[a]!);
      });
    final selected = (_selected ?? ids.take(3).toSet()).where(ids.contains).toSet();
    final colorOf = {for (var i = 0; i < ids.length; i++) ids[i]: chartPalette[i % chartPalette.length]};
    // Рост за период: последний 1ПМ к первому.
    double? growth(int id) {
      final s = series[id]!;
      final first = s.first.stat.bestE1rmKg!, last = s.last.stat.bestE1rmKg!;
      return s.length < 2 || first <= 0 ? null : (last - first) / first * 100;
    }

    final growing = [for (final id in ids) if ((growth(id) ?? 0) > 0.5) id];
    final falling = [for (final id in ids) if ((growth(id) ?? 0) < -0.5) id];
    int? bestId;
    for (final id in ids) {
      final g = growth(id);
      if (g != null && (bestId == null || g > growth(bestId)!)) bestId = id;
    }

    // ---- План ----
    var done = 0, partial = 0, failed = 0;
    for (final r in rows) {
      done += r.stat.setsDone;
      partial += r.stat.setsPartial;
      failed += r.stat.setsFailed;
    }
    final totalSets = done + partial + failed;
    final donePct = totalSets == 0 ? null : done / totalSets * 100;

    // ---- Сводка ----
    final sessions = history
        .where((h) =>
            h.session.status == 'completed' &&
            (range.from == null || h.session.date.compareTo(range.from!) >= 0) &&
            (range.to == null || h.session.date.compareTo(range.to!) <= 0))
        .length;
    final weightDelta = weights.length < 2
        ? null
        : (weights.last.trendKg ?? weights.last.weightKg) - (weights.first.trendKg ?? weights.first.weightKg);

    Widget empty(String text) =>
        Padding(padding: const EdgeInsets.all(32), child: Text(text, textAlign: TextAlign.center));

    Widget headline(String text, {IconData icon = Icons.insights, Color? color}) => Card(
          color: scheme.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: color ?? scheme.primary),
                const SizedBox(width: 12),
                Expanded(child: Text(text, style: t.titleSmall)),
              ],
            ),
          ),
        );

    Widget legend(List<(Color, String)> items) => Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            for (final (c, label) in items)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(label, style: t.bodySmall),
                ],
              ),
          ],
        );

    // ================= Вкладка «Сила» =================
    Widget strengthTab() {
      if (withE1rm.isEmpty) {
        return empty('За выбранный период нет завершённых тренировок. Графики появятся после первой сессии.');
      }
      final dipId = ids.contains(_dipsExerciseId) ? _dipsExerciseId! : (selected.isEmpty ? ids.first : selected.first);
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          headline(
            growing.isEmpty && falling.isEmpty
                ? 'Сила без заметных изменений за период.'
                : 'Растут: ${growing.length} из ${ids.length} упражнений'
                    '${falling.isEmpty ? '' : ', снижаются: ${falling.length}'}.'
                    '${bestId == null || (growth(bestId) ?? 0) <= 0 ? '' : ' Лучший рост — ${names[bestId]} (${_pct(growth(bestId)!)}).'}',
            icon: falling.length > growing.length ? Icons.trending_down : Icons.trending_up,
            color: falling.length > growing.length ? colorBad : colorGood,
          ),
          const SizedBox(height: 8),
          Text('Расчётный максимум (1ПМ) по неделям, кг', style: t.titleMedium),
          Text('Линия вверх — становитесь сильнее. Серые полосы — недели разгрузки.', style: t.bodySmall),
          const SizedBox(height: 8),
          SizedBox(
            height: 260,
            child: E1rmChart(rows: withE1rm.where((r) => selected.contains(r.exercise.id)).toList(), colorOf: colorOf),
          ),
          const SizedBox(height: 12),
          Text('Упражнения — нажмите, чтобы показать на графике', style: t.bodySmall),
          for (final id in ids)
            Builder(builder: (context) {
              final last = series[id]!.last.stat;
              final g = growth(id);
              final on = selected.contains(id);
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Icon(on ? Icons.check_circle : Icons.circle_outlined, color: on ? colorOf[id] : scheme.outline),
                title: Text(names[id]!),
                subtitle: Text('${formatKg((last.bestE1rmKg! * 10).round() / 10)} кг'
                    '${last.e1rmDeltaPct == null ? '' : ' · к прошлой неделе ${_pct(last.e1rmDeltaPct!)}'}'),
                trailing: g == null
                    ? null
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (g < -0.5 ? colorBad : (g > 0.5 ? colorGood : scheme.outline)).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_pct(g),
                            style: t.labelLarge
                                ?.copyWith(color: g < -0.5 ? colorBad : (g > 0.5 ? colorGood : scheme.onSurface))),
                      ),
                onTap: () => setState(() {
                  final s = {...selected};
                  on ? s.remove(id) : s.add(id);
                  _selected = s;
                  _dipsExerciseId = id;
                }),
              );
            }),
          const Divider(height: 28),
          Text('Изменение за неделю: ${names[dipId]}', style: t.titleMedium),
          Text('Столбец вверх (зелёный) — 1ПМ вырос к прошлой неделе, вниз (красный) — просел, %.', style: t.bodySmall),
          const SizedBox(height: 8),
          SizedBox(height: 180, child: DipsChart(rows: series[dipId]!)),
        ],
      );
    }

    // ================= Вкладка «Объём» =================
    Widget volumeTab() {
      if (volume.isEmpty || groups.isEmpty) {
        return empty('Нет данных об объёме за период. Они появятся после завершённой тренировки.');
      }
      final weeks = continuousWeeks(rows.map((r) => r.stat.weekStart));
      final lastWeek = volume.map((v) => v.weekStart).reduce((a, b) => a.compareTo(b) > 0 ? a : b);
      final lastByGroup = {for (final v in volume.where((v) => v.weekStart == lastWeek)) v.muscleGroupId: v};
      var low = 0, ok = 0, high = 0;
      for (final g in groups) {
        final sets = lastByGroup[g.id]?.sets ?? 0;
        if (sets < g.targetSetsMin) {
          low++;
        } else if (sets > g.targetSetsMax) {
          high++;
        } else {
          ok++;
        }
      }
      final group = groups.firstWhere((g) => g.id == _muscleId, orElse: () => groups.first);
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          headline('Неделя с ${ruDate(parseYmd(lastWeek))}: в целевом коридоре $ok из ${groups.length} групп, '
              'ниже — $low, выше — $high.', icon: Icons.stacked_bar_chart),
          const SizedBox(height: 8),
          Text('Рабочие подходы за неделю по группам мышц', style: t.titleMedium),
          Text('Светлая зона — целевой коридор. Нажмите на группу, чтобы увидеть её динамику.', style: t.bodySmall),
          const SizedBox(height: 4),
          for (final g in groups)
            _VolumeRow(
              group: g,
              sets: lastByGroup[g.id]?.sets ?? 0,
              selected: g.id == group.id,
              onTap: () => setState(() => _muscleId = g.id),
            ),
          const SizedBox(height: 4),
          legend(const [(colorGood, 'в коридоре'), (colorWarn, 'ниже цели'), (colorBad, 'выше цели')]),
          const Divider(height: 28),
          Text('${group.name}: подходы по неделям', style: t.titleMedium),
          Text('Пунктир — коридор ${group.targetSetsMin}–${group.targetSetsMax} подходов.', style: t.bodySmall),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: VolumeChart(
                rows: volume.where((v) => v.muscleGroupId == group.id).toList(), group: group, allWeeks: weeks),
          ),
        ],
      );
    }

    // ================= Вкладка «План» =================
    Widget planTab() {
      if (totalSets == 0) return empty('Нет подходов по плану за период. Свободные тренировки сюда не попадают.');
      String share(int n) => '${(n / totalSets * 100).round()}%';
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          headline(
            'По плану выполнено ${share(done)} подходов из $totalSets; частично — ${share(partial)}, провалено — ${share(failed)}.',
            icon: Icons.fact_check_outlined,
            color: donePct! >= 80 ? colorGood : (donePct >= 60 ? colorWarn : colorBad),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 18,
              child: Row(
                children: [
                  if (done > 0) Expanded(flex: done, child: Container(color: colorGood)),
                  if (partial > 0) Expanded(flex: partial, child: Container(color: colorWarn)),
                  if (failed > 0) Expanded(flex: failed, child: Container(color: colorBad)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          legend([
            (colorGood, 'выполнено: $done'),
            (colorWarn, 'частично (недобор 3–5): $partial'),
            (colorBad, 'провал (недобор 6+): $failed'),
          ]),
          const Divider(height: 28),
          Text('Доля подходов по статусам по неделям, %', style: t.titleMedium),
          Text('Чем больше зелёного, тем точнее план попадает в ваши силы.', style: t.bodySmall),
          const SizedBox(height: 8),
          SizedBox(height: 200, child: AdherenceChart(rows: rows)),
        ],
      );
    }

    // ================= Вкладка «Вес» =================
    Widget weightTab() {
      if (weights.length < 2) {
        return empty('Запишите вес хотя бы два раза на вкладке «Питание» — здесь появится график с трендом.');
      }
      final last = weights.last;
      final trend = last.trendKg ?? last.weightKg;
      final d = weightDelta!;
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          headline(
            d.abs() < 0.2
                ? 'Вес стабилен: тренд ${trend.toStringAsFixed(1).replaceAll('.', ',')} кг.'
                : 'Тренд веса ${d > 0 ? 'вырос' : 'снизился'} на '
                    '${d.abs().toStringAsFixed(1).replaceAll('.', ',')} кг за период и сейчас '
                    '${trend.toStringAsFixed(1).replaceAll('.', ',')} кг.',
            icon: Icons.monitor_weight_outlined,
          ),
          const SizedBox(height: 8),
          Text('Вес тела, кг', style: t.titleMedium),
          Text('Точки — взвешивания, линия — сглаженный тренд без суточных колебаний.', style: t.bodySmall),
          const SizedBox(height: 8),
          SizedBox(height: 240, child: WeightChart(logs: weights)),
          const SizedBox(height: 8),
          Text('Последнее взвешивание: ${formatKg(last.weightKg)} кг (${ruDate(parseYmd(last.date))}). '
              'Взвешиваний за период: ${weights.length}.'),
        ],
      );
    }

    Widget tile(String label, String value, {Color? color, IconData? icon}) => Expanded(
          child: Card(
            margin: const EdgeInsets.all(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: t.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (icon != null) Padding(padding: const EdgeInsets.only(right: 4), child: Icon(icon, size: 18, color: color)),
                      Flexible(child: Text(value, style: t.titleLarge?.copyWith(color: color), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(title: const Text('Аналитика')),
        body: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SegmentedButton<AnalyticsPeriod>(
                showSelectedIcon: false,
                segments: [for (final p in AnalyticsPeriod.values) ButtonSegment(value: p, label: Text(p.label))],
                selected: {_period},
                onSelectionChanged: (s) => setState(() => _period = s.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  tile('Тренировок', '$sessions'),
                  tile('План', donePct == null ? '—' : '${donePct.round()}%',
                      color: donePct == null ? null : (donePct >= 80 ? colorGood : (donePct >= 60 ? colorWarn : colorBad))),
                  tile('Сила растёт', ids.isEmpty ? '—' : '${growing.length}/${ids.length}',
                      icon: ids.isEmpty ? null : Icons.trending_up, color: growing.isEmpty ? null : colorGood),
                  tile('Вес', weightDelta == null
                      ? '—'
                      : '${weightDelta >= 0 ? '+' : '−'}${weightDelta.abs().toStringAsFixed(1).replaceAll('.', ',')}'),
                ],
              ),
            ),
            const TabBar(tabs: [Tab(text: 'Сила'), Tab(text: 'Объём'), Tab(text: 'План'), Tab(text: 'Вес')]),
            Expanded(child: TabBarView(children: [strengthTab(), volumeTab(), planTab(), weightTab()])),
          ],
        ),
      ),
    );
  }
}

/// Строка объёма группы мышц: столбик подходов на фоне целевого коридора.
class _VolumeRow extends StatelessWidget {
  const _VolumeRow({required this.group, required this.sets, required this.selected, required this.onTap});
  final MuscleGroup group;
  final double sets;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final scaleMax = [group.targetSetsMax * 1.3, sets * 1.05, 1.0].reduce((a, b) => a > b ? a : b);
    final color = sets < group.targetSetsMin ? colorWarn : (sets > group.targetSetsMax ? colorBad : colorGood);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? scheme.surfaceContainerHigh : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            SizedBox(width: 118, child: Text(group.name, style: t.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
            Expanded(
              child: LayoutBuilder(builder: (context, c) {
                final w = c.maxWidth;
                double x(num v) => (v / scaleMax).clamp(0, 1).toDouble() * w;
                return SizedBox(
                  height: 16,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                              color: scheme.onSurface.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                      Positioned(
                        left: x(group.targetSetsMin),
                        width: x(group.targetSetsMax) - x(group.targetSetsMin),
                        top: 0,
                        bottom: 0,
                        child: Container(color: scheme.onSurface.withValues(alpha: 0.16)),
                      ),
                      Positioned(
                        left: 0,
                        top: 3,
                        bottom: 3,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.easeOutCubic,
                          width: x(sets),
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
            SizedBox(
              width: 44,
              child: Text(formatKg(sets), textAlign: TextAlign.right, style: t.titleSmall?.copyWith(color: color)),
            ),
          ],
        ),
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
