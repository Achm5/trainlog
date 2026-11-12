import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/database.dart';
import '../../data/journal_repo.dart';
import '../../domain/dates.dart';
import '../../domain/planning.dart';
import '../../domain/strength.dart';
import '../../providers.dart';
import '../common.dart';
import '../reference/exercises_screen.dart';

const defaultRestSec = 120;

/// Экран тренировки: подходы с предзаполнением из плана, статусы, таймер отдыха.
/// Этот же экран используется для правки прошлых сессий.
class SessionScreen extends ConsumerWidget {
  const SessionScreen({super.key, required this.sessionId});
  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider(sessionId)).value;
    final journal = ref.read(journalRepoProvider);
    if (session == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    final inProgress = session.status == 'in_progress';
    final step = ref.watch(settingsProvider).value?.weightRoundingKg ?? 2.5;

    Future<void> finish() async {
      final list = ref.read(sessionExercisesProvider(sessionId)).value ?? const <SessionExerciseView>[];
      final pending = list.expand((e) => e.sets).where((s) => s.reps == null && s.status == null).length;
      if (pending > 0 &&
          !await confirm(context, 'Завершить тренировку?',
              message: 'Невыполненных подходов: $pending. Они будут отмечены как пропущенные.', ok: 'Завершить')) {
        return;
      }
      for (final s in list.expand((e) => e.sets).where((s) => s.reps == null && s.status == null)) {
        await journal.skipSet(s.id);
      }
      await journal.finishSession(sessionId);
      ref.read(restTimerProvider.notifier).stop();
      if (!context.mounted) return;
      final done = await journal.session(sessionId);
      if (!context.mounted) return;
      toast(context, 'Тренировка завершена · ${formatDuration(((done.finishedAt ?? 0) - done.startedAt) ~/ 1000)}');
      Navigator.of(context).pop();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${inProgress ? 'Тренировка' : 'Сессия'} · ${ruDate(parseYmd(session.date))}'),
        actions: [
          IconButton(
            tooltip: 'Заметка к тренировке',
            icon: Icon(session.note == null ? Icons.sticky_note_2_outlined : Icons.sticky_note_2),
            onPressed: () async {
              final t = await askText(context, 'Заметка к тренировке', initial: session.note ?? '', maxLines: 4);
              if (t != null) await journal.setSessionNote(sessionId, t);
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'add') {
                final exId = await pickExercise(context);
                if (exId != null) await journal.addExerciseToSession(sessionId, exId);
              } else if (v == 'delete') {
                if (await confirm(context, 'Удалить тренировку?', message: 'Все подходы этой сессии будут удалены.')) {
                  await journal.deleteSession(sessionId);
                  if (context.mounted) Navigator.of(context).pop();
                }
              }
            },
            itemBuilder: (c) => const [
              PopupMenuItem(value: 'add', child: Text('Добавить упражнение')),
              PopupMenuItem(value: 'delete', child: Text('Удалить тренировку')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (inProgress) const _KeepScreenOn(),
          const RestTimerBar(),
          Expanded(
            child: AsyncView(
              value: ref.watch(sessionExercisesProvider(sessionId)),
              builder: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: FilledButton.tonalIcon(
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить упражнение'),
                      onPressed: () async {
                        final exId = await pickExercise(context);
                        if (exId != null) await journal.addExerciseToSession(sessionId, exId);
                      },
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                  children: [
                    if (session.note != null)
                      Padding(padding: const EdgeInsets.all(8), child: Text('Заметка: ${session.note}')),
                    for (final e in list) _ExerciseCard(view: e, step: step, timerEnabled: inProgress),
                  ],
                );
              },
            ),
          ),
          if (inProgress)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(onPressed: finish, child: const Text('Завершить тренировку')),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Не даёт экрану гаснуть, пока открыта незавершённая тренировка.
class _KeepScreenOn extends StatefulWidget {
  const _KeepScreenOn();

  @override
  State<_KeepScreenOn> createState() => _KeepScreenOnState();
}

class _KeepScreenOnState extends State<_KeepScreenOn> {
  @override
  void initState() {
    super.initState();
    WakelockPlus.enable().catchError((_) {});
  }

  @override
  void dispose() {
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _ExerciseCard extends ConsumerWidget {
  const _ExerciseCard({required this.view, required this.step, required this.timerEnabled});
  final SessionExerciseView view;
  final double step;
  final bool timerEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journal = ref.read(journalRepoProvider);
    final plan = view.plan;
    final sets = [...view.sets]..sort((a, b) {
        if (a.isWarmup != b.isWarmup) return a.isWarmup ? -1 : 1;
        return a.setNo.compareTo(b.setNo);
      });
    var workNo = 0;

    void startRest() {
      if (timerEnabled) ref.read(restTimerProvider.notifier).start(view.restSec ?? defaultRestSec);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: StatusDot(view.status, size: 16)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(view.exercise.name, style: Theme.of(context).textTheme.titleMedium),
                      if (plan != null)
                        Text(
                          'План: ${plan.sets} × ${plan.repsMin}–${plan.repsMax} · ${formatKg(plan.weightKg)} кг · RIR ${plan.targetRir}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    switch (v) {
                      case 'set':
                        await journal.addSet(view.se.id);
                      case 'warmup':
                        await journal.addSet(view.se.id, warmup: true);
                      case 'remove':
                        if (await confirm(context, 'Убрать упражнение из тренировки?')) {
                          await journal.removeSessionExercise(view.se.id);
                        }
                    }
                  },
                  itemBuilder: (c) => const [
                    PopupMenuItem(value: 'set', child: Text('Добавить подход')),
                    PopupMenuItem(value: 'warmup', child: Text('Добавить разминочный подход')),
                    PopupMenuItem(value: 'remove', child: Text('Убрать упражнение')),
                  ],
                ),
              ],
            ),
            for (final s in sets)
              _SetRow(
                set: s,
                label: s.isWarmup ? 'Р' : '${++workNo}',
                targetRir: plan?.targetRir,
                onPlanned: () async {
                  await journal.completeAsPlanned(s.id, targetRir: plan?.targetRir);
                  startRest();
                },
                onEdit: () async {
                  final saved = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => SetEditor(set: s, step: step, targetRir: plan?.targetRir, previous: _previous(sets, s)),
                  );
                  if (saved == true && !s.isWarmup) startRest();
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Последний выполненный подход перед данным — для подстановки значений в свободной тренировке.
  static SetLog? _previous(List<SetLog> sets, SetLog current) {
    SetLog? prev;
    for (final s in sets) {
      if (s.id == current.id) break;
      if (s.reps != null) prev = s;
    }
    return prev;
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.set,
    required this.label,
    required this.targetRir,
    required this.onPlanned,
    required this.onEdit,
  });
  final SetLog set;
  final String label;
  final int? targetRir;
  final VoidCallback onPlanned;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final status = SetStatus.fromDb(set.status);
    final done = set.reps != null;
    final skipped = status == SetStatus.skipped;
    final hasPlan = set.plannedReps != null;
    final t = Theme.of(context).textTheme;

    final String main;
    if (done) {
      main = '${formatKg(set.weightKg)} кг × ${set.reps}${set.rir != null ? ' · RIR ${set.rir}' : ''}';
    } else if (skipped) {
      main = 'Пропущен';
    } else if (hasPlan) {
      main = '${formatKg(set.plannedWeightKg)} кг × ${set.plannedReps}';
    } else {
      main = set.isWarmup ? 'Разминочный подход' : 'Подход без плана';
    }

    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(label, textAlign: TextAlign.center, style: t.titleMedium),
            ),
            Container(
              width: 6,
              height: 40,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: done && set.isWarmup ? Theme.of(context).colorScheme.outline : statusColor(status, context),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(main, style: done ? t.titleMedium : t.titleMedium?.copyWith(color: Theme.of(context).hintColor)),
                  if (done && (status != null || set.weightReduced || set.note != null || set.isWarmup))
                    Text(
                      [
                        if (set.isWarmup) 'разминка',
                        if (status != null) status.label.toLowerCase(),
                        if (set.weightReduced) 'вес снижен',
                        if (set.note != null) set.note!,
                      ].join(' · '),
                      style: t.bodySmall,
                    ),
                ],
              ),
            ),
            if (!done && !skipped && hasPlan)
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: onPlanned,
                  icon: const Icon(Icons.check),
                  label: const Text('По плану'),
                ),
              )
            else if (!done && !skipped)
              SizedBox(height: 48, child: FilledButton.tonal(onPressed: onEdit, child: const Text('Ввести')))
            else
              IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
          ],
        ),
      ),
    );
  }
}

/// Редактор подхода с крупными кнопками ± (ввод одной рукой).
class SetEditor extends ConsumerStatefulWidget {
  const SetEditor({super.key, required this.set, required this.step, this.targetRir, this.previous});
  final SetLog set;
  final double step;
  final int? targetRir;
  final SetLog? previous;

  @override
  ConsumerState<SetEditor> createState() => _SetEditorState();
}

class _SetEditorState extends ConsumerState<SetEditor> {
  late double _weight;
  late int _reps;
  int? _rir;
  late bool _warmup;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    final s = widget.set;
    final p = widget.previous;
    _weight = s.weightKg ?? s.plannedWeightKg ?? p?.weightKg ?? 0;
    _reps = s.reps ?? s.plannedReps ?? p?.reps ?? 8;
    _rir = s.reps != null ? s.rir : (s.isWarmup ? null : widget.targetRir);
    _warmup = s.isWarmup;
    _note = TextEditingController(text: s.note ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref.read(journalRepoProvider).saveSet(
          widget.set.id,
          weightKg: _weight,
          reps: _reps,
          rir: _warmup ? null : _rir,
          isWarmup: _warmup,
          note: _note.text,
        );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final journal = ref.read(journalRepoProvider);
    final s = widget.set;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (s.plannedReps != null)
              Text('План: ${formatKg(s.plannedWeightKg)} кг × ${s.plannedReps}', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            _Stepper(
              label: 'Вес, кг',
              value: formatKg(_weight),
              onMinus: () => setState(() => _weight = (_weight - widget.step).clamp(0, 1000).toDouble()),
              onPlus: () => setState(() => _weight = (_weight + widget.step).clamp(0, 1000).toDouble()),
              onTapValue: () async {
                final v = await askNumber(context, 'Вес, кг', initial: _weight);
                if (v != null && v >= 0) setState(() => _weight = v);
              },
            ),
            const SizedBox(height: 12),
            _Stepper(
              label: 'Повторы',
              value: '$_reps',
              onMinus: () => setState(() => _reps = (_reps - 1).clamp(0, 100)),
              onPlus: () => setState(() => _reps = (_reps + 1).clamp(0, 100)),
              onTapValue: () async {
                final v = await askNumber(context, 'Повторы', initial: _reps.toDouble(), integer: true);
                if (v != null && v >= 0) setState(() => _reps = v.round());
              },
            ),
            const SizedBox(height: 12),
            if (!_warmup) ...[
              Align(alignment: Alignment.centerLeft, child: Text('RIR — повторов в запасе', style: Theme.of(context).textTheme.labelLarge)),
              const SizedBox(height: 4),
              Row(
                children: [
                  for (var r = 0; r <= 5; r++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: ChoiceChip(
                          label: SizedBox(width: double.infinity, child: Text('$r', textAlign: TextAlign.center)),
                          selected: _rir == r,
                          showCheckmark: false,
                          onSelected: (on) => setState(() => _rir = on ? r : null),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Разминочный подход'),
              subtitle: const Text('Не идёт в аналитику'),
              value: _warmup,
              onChanged: (v) => setState(() => _warmup = v),
            ),
            TextField(controller: _note, decoration: const InputDecoration(labelText: 'Заметка к подходу', isDense: true)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(onPressed: _save, child: const Text('Сохранить подход')),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () async {
                    await journal.skipSet(s.id);
                    if (context.mounted) Navigator.of(context).pop(false);
                  },
                  child: const Text('Пропустить'),
                ),
                if (s.reps != null || s.status != null)
                  TextButton(
                    onPressed: () async {
                      await journal.resetSet(s.id);
                      if (context.mounted) Navigator.of(context).pop(false);
                    },
                    child: const Text('Сбросить'),
                  ),
                TextButton(
                  onPressed: () async {
                    await journal.deleteSet(s.id);
                    if (context.mounted) Navigator.of(context).pop(false);
                  },
                  child: const Text('Удалить подход'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    required this.onTapValue,
  });
  final String label;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onTapValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 72, height: 64, child: FilledButton.tonal(onPressed: onMinus, child: const Icon(Icons.remove, size: 32))),
        Expanded(
          child: InkWell(
            onTap: onTapValue,
            child: Column(
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                Text(value, style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
          ),
        ),
        SizedBox(width: 72, height: 64, child: FilledButton.tonal(onPressed: onPlus, child: const Icon(Icons.add, size: 32))),
      ],
    );
  }
}

/// Полоса таймера отдыха. Отсчёт идёт от момента окончания, поэтому переживает сворачивание приложения.
class RestTimerBar extends ConsumerStatefulWidget {
  const RestTimerBar({super.key});

  @override
  ConsumerState<RestTimerBar> createState() => _RestTimerBarState();
}

class _RestTimerBarState extends ConsumerState<RestTimerBar> {
  Timer? _ticker;
  bool _signaled = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted && ref.read(restTimerProvider) != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final end = ref.watch(restTimerProvider);
    ref.listen(restTimerProvider, (_, _) => _signaled = false);
    if (end == null) return const SizedBox.shrink();
    final left = end.difference(DateTime.now()).inSeconds;
    final over = left <= 0;
    if (over && !_signaled) {
      _signaled = true;
      HapticFeedback.vibrate();
    }
    final scheme = Theme.of(context).colorScheme;
    final shown = over ? 0 : left;
    return Material(
      color: over ? scheme.tertiaryContainer : scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(over ? Icons.notifications_active : Icons.timer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                over
                    ? 'Отдых окончен'
                    : 'Отдых: ${shown ~/ 60}:${(shown % 60).toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (!over)
              TextButton(
                onPressed: () => ref.read(restTimerProvider.notifier).start(left + 30),
                child: const Text('+30 с'),
              ),
            TextButton(onPressed: () => ref.read(restTimerProvider.notifier).stop(), child: Text(over ? 'Закрыть' : 'Стоп')),
          ],
        ),
      ),
    );
  }
}
