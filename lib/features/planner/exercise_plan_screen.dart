import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/database.dart';
import '../../data/planner_repo.dart';
import '../../domain/dates.dart';
import '../../domain/planning.dart';
import '../../providers.dart';
import '../common.dart';

final _exerciseNameProvider = FutureProvider.family<String, int>(
    (ref, exerciseId) async => (await ref.watch(referenceRepoProvider).exercise(exerciseId))?.name ?? '');
final _latestE1rmProvider =
    FutureProvider.family<double?, int>((ref, exerciseId) => ref.watch(plannerRepoProvider).latestE1rm(exerciseId));

/// План упражнения по неделям цикла (раздел 2.3 ТЗ): режим веса, подходы, повторы, вес, RIR, отдых.
class ExercisePlanScreen extends ConsumerWidget {
  const ExercisePlanScreen({super.key, required this.pdeId});
  final int pdeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(pdeProvider(pdeId)).value;
    final plans = ref.watch(weekPlansProvider(pdeId)).value ?? const <WeekPlanView>[];
    if (item == null) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    final planner = ref.read(plannerRepoProvider);
    final mode = LoadMode.fromDb(item.loadMode);
    final name = ref.watch(_exerciseNameProvider(item.exerciseId)).value ?? '';
    final e1rm = ref.watch(_latestE1rmProvider(item.exerciseId)).value;

    Future<void> editAll() async {
      final first = plans.where((p) => !p.week.isDeload).firstOrNull?.plan;
      if (first == null) return;
      final sets = await askNumber(context, 'Подходы (все рабочие недели)', initial: first.sets.toDouble(), integer: true);
      if (sets == null || sets < 1 || !context.mounted) return;
      final rMin = await askNumber(context, 'Повторы: нижняя граница', initial: first.repsMin.toDouble(), integer: true);
      if (rMin == null || rMin < 1 || !context.mounted) return;
      final rMax = await askNumber(context, 'Повторы: верхняя граница', initial: first.repsMax.toDouble(), integer: true);
      if (rMax == null || rMax < rMin || !context.mounted) return;
      final rir = await askNumber(context, 'Целевой RIR (0–5)', initial: first.targetRir.toDouble(), integer: true);
      if (rir == null || rir < 0 || rir > 5) return;
      for (final p in plans.where((p) => !p.week.isDeload)) {
        await planner.updatePlan(
          p.plan.id,
          ExerciseWeekPlansCompanion(
            sets: Value(sets.round()),
            repsMin: Value(rMin.round()),
            repsMax: Value(rMax.round()),
            targetRir: Value(rir.round()),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [IconButton(tooltip: 'Задать для всех недель', icon: const Icon(Icons.playlist_add_check), onPressed: editAll)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text('Способ задания веса', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<LoadMode>(
            segments: [for (final m in LoadMode.values) ButtonSegment(value: m, label: Text(m.label))],
            selected: {mode},
            onSelectionChanged: (s) => planner.updatePde(pdeId, ProgramDayExercisesCompanion(loadMode: Value(s.first.db))),
          ),
          const SizedBox(height: 8),
          if (mode == LoadMode.linear)
            Row(
              children: [
                Expanded(
                  child: _Field(
                    label: 'Стартовый вес',
                    value: '${formatKg(item.startWeightKg)} кг',
                    onTap: () async {
                      final v = await askNumber(context, 'Стартовый вес, кг', initial: item.startWeightKg);
                      if (v != null && v >= 0) {
                        await planner.updatePde(pdeId, ProgramDayExercisesCompanion(startWeightKg: Value(v)));
                      }
                    },
                  ),
                ),
                Expanded(
                  child: _Field(
                    label: 'Шаг в неделю',
                    value: '+${formatKg(item.weeklyStepKg ?? 0)} кг',
                    onTap: () async {
                      final v = await askNumber(context, 'Прибавка в неделю, кг', initial: item.weeklyStepKg ?? 0);
                      if (v != null) {
                        await planner.updatePde(pdeId, ProgramDayExercisesCompanion(weeklyStepKg: Value(v)));
                      }
                    },
                  ),
                ),
              ],
            ),
          if (mode == LoadMode.percent)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(e1rm == null
                  ? 'Расчётного 1ПМ пока нет: веса появятся после первой завершённой тренировки с этим упражнением.'
                  : 'Расчётный 1ПМ: ${formatKg(e1rm)} кг'),
            ),
          _Field(
            label: 'Отдых между подходами',
            value: '${item.restSec} с',
            onTap: () async {
              final v = await askNumber(context, 'Отдых, с', initial: item.restSec.toDouble(), integer: true);
              if (v != null && v >= 0 && v <= 900) {
                await planner.updatePde(pdeId, ProgramDayExercisesCompanion(restSec: Value(v.round())));
              }
            },
          ),
          const Divider(height: 24),
          for (final v in plans) _WeekCard(view: v, mode: mode),
          const SizedBox(height: 8),
          const Text('Веса округляются вниз до шага округления. Вес, исправленный вручную, не пересчитывается, '
              'пока не нажать «Сбросить».'),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _WeekCard extends ConsumerWidget {
  const _WeekCard({required this.view, required this.mode});
  final WeekPlanView view;
  final LoadMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planner = ref.read(plannerRepoProvider);
    final p = view.plan;
    final deload = view.week.isDeload;

    Future<void> save(ExerciseWeekPlansCompanion c) =>
        planner.updatePlan(p.id, deload ? c.copyWith(isManual: const Value(true)) : c);

    return Card(
      color: deload ? Theme.of(context).colorScheme.surfaceContainerHighest : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    'Неделя ${view.week.weekNo} · ${ruDate(parseYmd(view.week.startDate))}${deload ? ' · разгрузка' : ''}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const Spacer(),
                if (p.isManual)
                  TextButton(
                    onPressed: () => planner.updatePlan(p.id, const ExerciseWeekPlansCompanion(isManual: Value(false))),
                    child: const Text('Сбросить'),
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _Field(
                    label: 'Подходы',
                    value: '${p.sets}',
                    onTap: () async {
                      final v = await askNumber(context, 'Подходы', initial: p.sets.toDouble(), integer: true);
                      if (v != null && v >= 1 && v <= 20) await save(ExerciseWeekPlansCompanion(sets: Value(v.round())));
                    },
                  ),
                ),
                Expanded(
                  child: _Field(
                    label: 'Повторы',
                    value: '${p.repsMin}–${p.repsMax}',
                    onTap: () async {
                      final a = await askNumber(context, 'Повторы: нижняя граница', initial: p.repsMin.toDouble(), integer: true);
                      if (a == null || a < 1 || !context.mounted) return;
                      final b = await askNumber(context, 'Повторы: верхняя граница',
                          initial: (p.repsMax < a ? a : p.repsMax).toDouble(), integer: true);
                      if (b == null || b < a) return;
                      await save(ExerciseWeekPlansCompanion(repsMin: Value(a.round()), repsMax: Value(b.round())));
                    },
                  ),
                ),
                if (mode == LoadMode.percent && !deload)
                  Expanded(
                    child: _Field(
                      label: '% от 1ПМ',
                      value: p.percent1rm == null ? '—' : '${formatKg(p.percent1rm)}%',
                      onTap: () async {
                        final v = await askNumber(context, 'Процент от расчётного 1ПМ', initial: p.percent1rm, suffix: '%');
                        if (v != null && v > 0 && v <= 120) {
                          await planner.updatePlan(
                              p.id, ExerciseWeekPlansCompanion(percent1rm: Value(v), isManual: const Value(false)));
                        }
                      },
                    ),
                  ),
                Expanded(
                  child: _Field(
                    label: p.isManual ? 'Вес (вручную)' : 'Вес',
                    value: '${formatKg(p.weightKg)} кг',
                    onTap: () async {
                      final v = await askNumber(context, 'Целевой вес, кг', initial: p.weightKg);
                      if (v == null || v < 0) return;
                      // В ручном режиме вес недели — исходное значение; в остальных правка ставит is_manual.
                      final manualFlag = deload || mode != LoadMode.manual;
                      await planner.updatePlan(
                          p.id, ExerciseWeekPlansCompanion(weightKg: Value(v), isManual: Value(manualFlag)));
                    },
                  ),
                ),
                Expanded(
                  child: _Field(
                    label: 'RIR',
                    value: '${p.targetRir}',
                    onTap: () async {
                      final v = await askNumber(context, 'Целевой RIR (0–5)', initial: p.targetRir.toDouble(), integer: true);
                      if (v != null && v >= 0 && v <= 5) await save(ExerciseWeekPlansCompanion(targetRir: Value(v.round())));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
