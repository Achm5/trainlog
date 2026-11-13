import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/database.dart';
import '../../data/planner_repo.dart';
import '../../domain/dates.dart';
import '../../domain/planning.dart';
import '../../providers.dart';
import '../common.dart';
import '../reference/exercises_screen.dart';
import 'programs_screen.dart' show programStatusLabels;

/// Экран программы: дни, упражнения с перетаскиванием, контроль лимита времени.
class ProgramScreen extends ConsumerStatefulWidget {
  const ProgramScreen({super.key, required this.programId});
  final int programId;

  @override
  ConsumerState<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends ConsumerState<ProgramScreen> {
  int? _weekId;

  @override
  Widget build(BuildContext context) {
    final id = widget.programId;
    final program = ref.watch(programProvider(id)).value;
    final weeks = ref.watch(programWeeksProvider(id)).value ?? const <ProgramWeek>[];
    final days = ref.watch(programDaysProvider(id)).value ?? const <ProgramDay>[];
    if (program == null || weeks.isEmpty || days.isEmpty) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    final currentWs = ymd(weekStart(today()));
    final week = weeks.firstWhere(
      (w) => w.id == _weekId,
      orElse: () => weeks.firstWhere((w) => w.startDate == currentWs, orElse: () => weeks.first),
    );
    final planner = ref.read(plannerRepoProvider);

    return DefaultTabController(
      length: days.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(program.name),
          actions: [
            IconButton(
              tooltip: 'Параметры программы',
              icon: const Icon(Icons.tune),
              onPressed: () => context.push('/program/$id/edit'),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                switch (v) {
                  case 'activate':
                    await planner.activate(id);
                    if (context.mounted) toast(context, 'Программа активна');
                  case 'copy':
                    final delta = await askNumber(context, 'Копия программы: прибавить к весам, кг',
                        initial: 0, suffix: 'кг (можно 0)');
                    if (delta == null) return;
                    final end = addDays(weekStart(parseYmd(program.startDate)), 7 * program.weeksCount);
                    final start = end.isAfter(today()) ? end : nearestMonday(today());
                    final newId = await planner.copyProgram(id, startDate: start, weightDeltaKg: delta);
                    if (context.mounted) {
                      toast(context, 'Копия создана, старт ${ruDate(start)}. Веса можно поправить в упражнениях.');
                      context.pushReplacement('/program/$newId');
                    }
                  case 'archive':
                    await planner.archive(id);
                  case 'delete':
                    if (await confirm(context, 'Удалить программу?',
                        message: 'План будет удалён. Записи журнала сохранятся, но потеряют связь с планом.')) {
                      await planner.deleteProgram(id);
                      if (context.mounted) Navigator.of(context).pop();
                    }
                }
              },
              itemBuilder: (c) => [
                if (program.status != 'active') const PopupMenuItem(value: 'activate', child: Text('Сделать активной')),
                if (program.status != 'archived') const PopupMenuItem(value: 'archive', child: Text('В архив')),
                const PopupMenuItem(value: 'copy', child: Text('Создать копию')),
                const PopupMenuItem(value: 'delete', child: Text('Удалить')),
              ],
            ),
          ],
          bottom: TabBar(
            isScrollable: days.length > 4,
            tabs: [for (final d in days) Tab(text: weekdayShort[d.weekday - 1])],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Chip(label: Text(programStatusLabels[program.status] ?? '')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: week.id,
                      items: [
                        for (final w in weeks)
                          DropdownMenuItem(
                            value: w.id,
                            child: Text('Неделя ${w.weekNo} · с ${ruDate(parseYmd(w.startDate))}'
                                '${w.isDeload ? ' · разгрузка' : ''}'),
                          ),
                      ],
                      onChanged: (v) => setState(() => _weekId = v),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [for (final d in days) _DayTab(program: program, day: d, days: days, week: week)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayTab extends ConsumerWidget {
  const _DayTab({required this.program, required this.day, required this.days, required this.week});
  final Program program;
  final ProgramDay day;
  final List<ProgramDay> days;
  final ProgramWeek week;

  WeekPlanView? _plan(DayExerciseView v) => v.plans.where((p) => p.week.id == week.id).firstOrNull;

  Future<void> _move(BuildContext context, WidgetRef ref, DayExerciseView v) async {
    final others = days.where((d) => d.id != day.id).toList();
    if (others.isEmpty) return toast(context, 'В программе один тренировочный день');
    final target = await showDialog<int>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text('Перенести «${v.exercise.name}»'),
        children: [
          for (final d in others)
            SimpleDialogOption(onPressed: () => Navigator.pop(c, d.id), child: Text(weekdayFull[d.weekday - 1])),
        ],
      ),
    );
    if (target != null) await ref.read(plannerRepoProvider).moveToDay(v.item.id, target);
  }

  /// Копирует тренировку этого дня в другой день программы.
  Future<void> _copyDay(BuildContext context, WidgetRef ref, int count) async {
    final planner = ref.read(plannerRepoProvider);
    final target = await showDialog<ProgramDay>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text('Скопировать «${weekdayFull[day.weekday - 1]}» в день'),
        children: [
          for (final d in days.where((d) => d.id != day.id))
            SimpleDialogOption(onPressed: () => Navigator.pop(c, d), child: Text(weekdayFull[d.weekday - 1])),
        ],
      ),
    );
    if (target == null || !context.mounted) return;
    var replace = false;
    if ((await planner.dayExercises(target.id)).isNotEmpty) {
      if (!context.mounted) return;
      final choice = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('В дне «${weekdayFull[target.weekday - 1]}» уже есть упражнения'),
          content: const Text('Заменить их копией или добавить копию в конец списка?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Отмена')),
            TextButton(onPressed: () => Navigator.pop(c, 'add'), child: const Text('Добавить')),
            FilledButton(onPressed: () => Navigator.pop(c, 'replace'), child: const Text('Заменить')),
          ],
        ),
      );
      if (choice == null) return;
      replace = choice == 'replace';
    }
    final n = await planner.copyDay(fromDayId: day.id, toDayId: target.id, replace: replace);
    if (context.mounted) toast(context, 'Скопировано упражнений: $n → ${weekdayFull[target.weekday - 1]}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planner = ref.read(plannerRepoProvider);
    final settings = ref.watch(settingsProvider).value;
    return AsyncView(
      value: ref.watch(dayExercisesProvider(day.id)),
      builder: (items) {
        final sec = settings == null
            ? 0
            : dayDurationSec(
                [
                  for (final v in items)
                    if (_plan(v) != null) DayLoadItem(sets: _plan(v)!.plan.sets, restSec: v.item.restSec),
                ],
                setDurationSec: settings.setDurationSec,
                warmupMin: settings.warmupMin,
              );
        final over = sec > program.timeLimitMin * 60;
        final isolation = items.reversed
            .where((v) => v.exercise.kind == 'isolation' && (_plan(v)?.plan.sets ?? 0) > 1)
            .firstOrNull;

        return Column(
          children: [
            ListTile(
              dense: true,
              leading: Icon(over ? Icons.warning_amber : Icons.timer_outlined,
                  color: over ? Theme.of(context).colorScheme.error : null),
              title: Text('Расчётная длительность: ${formatDuration(sec)} из ${program.timeLimitMin} мин'),
            ),
            if (over)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Превышен лимит времени на ${formatDuration(sec - program.timeLimitMin * 60)}',
                          style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (isolation != null)
                            ActionChip(
                              label: Text('Убрать подход: ${isolation.exercise.name}'),
                              onPressed: () => planner.removeOneSet(isolation.item.id),
                            ),
                          ActionChip(
                            label: const Text('Сократить отдых на 30 с'),
                            onPressed: () => planner.shortenRest(day.id),
                          ),
                          if (items.isNotEmpty && days.length > 1)
                            ActionChip(
                              label: const Text('Перенести упражнение'),
                              onPressed: () => _move(context, ref, items.last),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('В этом дне пока нет упражнений'))
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: items.length,
                      onReorderItem: (oldIndex, newIndex) {
                        final ids = [for (final v in items) v.item.id];
                        final moved = ids.removeAt(oldIndex);
                        ids.insert(newIndex, moved);
                        planner.reorder(day.id, ids);
                      },
                      itemBuilder: (c, i) {
                        final v = items[i];
                        final p = _plan(v)?.plan;
                        return ListTile(
                          key: ValueKey(v.item.id),
                          title: Text(v.exercise.name),
                          subtitle: Text(p == null
                              ? 'Нет плана на эту неделю'
                              : '${p.sets} × ${p.repsMin}–${p.repsMax} · ${formatKg(p.weightKg)} кг · RIR ${p.targetRir}'
                                  ' · отдых ${v.item.restSec} с'),
                          leading: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (a) async {
                              if (a == 'move') {
                                await _move(context, ref, v);
                              } else if (a == 'delete') {
                                if (await confirm(context, 'Убрать упражнение из дня?')) {
                                  await planner.removeExercise(v.item.id);
                                }
                              }
                            },
                            itemBuilder: (c) => const [
                              PopupMenuItem(value: 'move', child: Text('Перенести в другой день')),
                              PopupMenuItem(value: 'delete', child: Text('Убрать из дня')),
                            ],
                          ),
                          onTap: () => context.push('/plan/${v.item.id}'),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить упражнение'),
                      onPressed: () async {
                        final exId = await pickExercise(context);
                        if (exId == null) return;
                        final pdeId = await planner.addExercise(dayId: day.id, exerciseId: exId);
                        if (context.mounted) context.push('/plan/$pdeId');
                      },
                    ),
                  ),
                  if (items.isNotEmpty && days.length > 1) ...[
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      tooltip: 'Скопировать день в другой',
                      icon: const Icon(Icons.copy_all_outlined),
                      onPressed: () => _copyDay(context, ref, items.length),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
