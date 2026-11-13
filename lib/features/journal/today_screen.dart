import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/app_state.dart';
import '../../data/database.dart';
import '../../domain/dates.dart';
import '../../providers.dart';
import '../common.dart';
import '../data/data_screen.dart';
import '../motion.dart';
import '../recommendations/recommendations.dart';
import 'package:trainlog/i18n.dart';

/// Главный экран журнала: тренировка дня, незавершённая сессия, свободная тренировка, история.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journal = ref.read(journalRepoProvider);
    final inProgress = ref.watch(inProgressSessionProvider).value;
    final program = ref.watch(activeProgramProvider).value;
    final history = ref.watch(historyProvider).value ?? const [];
    final now = today();
    final newRecs = ref.watch(newRecommendationsProvider).value ?? const [];

    final weeks = program == null ? const <ProgramWeek>[] : ref.watch(programWeeksProvider(program.id)).value ?? const [];
    final days = program == null ? const <ProgramDay>[] : ref.watch(programDaysProvider(program.id)).value ?? const [];
    final week = weeks.where((w) => w.startDate == ymd(weekStart(now))).firstOrNull;
    final doneDayIds = {
      for (final h in history)
        if (week != null && h.session.programWeekId == week.id && h.session.programDayId != null) h.session.programDayId!,
    };

    Future<void> start(ProgramDay d) async {
      final id = await journal.startPlannedSession(dayId: d.id, weekId: week!.id, date: now);
      if (context.mounted) context.push('/session/$id');
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr('Журнал · {0}, {1}', [weekdayShort[now.weekday - 1], ruDate(now)]))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          BackupReminderCard(onOpen: () => context.push('/data')),
          const OvertrainingCard(),
          for (final r in newRecs) Appear(key: ValueKey('rec-${r.rec.id}'), child: RecommendationCard(r)),
          if (inProgress != null)
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.play_arrow),
                      title: Text(tr('Незавершённая тренировка')),
                      subtitle: Text(tr('Начата {0}', [ruDate(parseYmd(inProgress.date))])),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => context.push('/session/${inProgress.id}'),
                          child: Text(tr('Продолжить')),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (program == null)
            Card(
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text(tr('Нет активной программы')),
                subtitle: Text(tr('Создайте программу на вкладке «План» и сделайте её активной — '
                    'тренировки дня будут предзаполняться из плана.')),
              ),
            )
          else if (week == null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.event_busy),
                title: Text(program.name),
                subtitle: Text(parseYmd(program.startDate).isAfter(now)
                    ? tr('Цикл начнётся {0}', [ruDate(parseYmd(program.startDate))])
                    : tr('Цикл завершён. Создайте следующую программу на вкладке «План».')),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: Text(
                tr('{0} · неделя {1} из {2}{3}', [program.name, week.weekNo, program.weeksCount, week.isDeload ? tr(' · разгрузка') : '']),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final (i, d) in days.indexed)
              Appear(
                key: ValueKey('day-${d.id}'),
                index: i,
                child: Card(
                child: ListTile(
                  leading: Icon(doneDayIds.contains(d.id)
                      ? Icons.check_circle
                      : (d.weekday == now.weekday ? Icons.today : Icons.calendar_today_outlined)),
                  title: Text(d.name.isEmpty ? weekdayFull[d.weekday - 1] : trName(d.name)),
                  subtitle: Text(d.weekday == now.weekday ? tr('Сегодня') : weekdayFull[d.weekday - 1]),
                  trailing: doneDayIds.contains(d.id)
                      ? TextButton(onPressed: () => start(d), child: Text(tr('Открыть')))
                      : (d.weekday == now.weekday
                          ? FilledButton(onPressed: () => start(d), child: Text(tr('Начать')))
                          : OutlinedButton(onPressed: () => start(d), child: Text(tr('Начать')))),
                ),
              )),
          ],
          const SizedBox(height: 4),
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: Text(tr('Свободная тренировка')),
            onPressed: () async {
              final id = await journal.startFreeSession(now);
              if (context.mounted) context.push('/session/$id');
            },
          ),
          const SizedBox(height: 16),
          Text(tr('История'), style: Theme.of(context).textTheme.titleMedium),
          if (history.isEmpty) Padding(padding: EdgeInsets.all(12), child: Text(tr('Тренировок пока нет'))),
          for (final h in history)
            ListTile(
              leading: Icon(h.session.status == 'completed' ? Icons.check_circle_outline : Icons.timelapse),
              title: Text(h.day == null
                  ? tr('Свободная тренировка')
                  : (h.day!.name.isEmpty ? weekdayFull[h.day!.weekday - 1] : trName(h.day!.name))),
              subtitle: Text([
                ruDate(parseYmd(h.session.date)),
                if (h.session.finishedAt != null)
                  formatDuration((h.session.finishedAt! - h.session.startedAt) ~/ 1000)
                else
                  tr('не завершена'),
              ].join(' · ')),
              onTap: () => context.push('/session/${h.session.id}'),
            ),
        ],
      ),
    );
  }
}

/// Предупреждение о перетренированности по последней закрытой неделе.
class OvertrainingCard extends ConsumerWidget {
  const OvertrainingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final check = ref.watch(overtrainingProvider).value;
    if (check == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monitor_heart_outlined, color: scheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(tr('Возможна перетренированность'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onErrorContainer)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(tr('Неделя с {0}: совпало признаков — {1}.', [ruDate(parseYmd(check.weekStart)), check.signals.length]),
                style: TextStyle(color: scheme.onErrorContainer)),
            for (final sig in check.signals)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('• ${sig.text}', style: TextStyle(color: scheme.onErrorContainer)),
              ),
            const SizedBox(height: 6),
            Text(tr('Стоит подумать о разгрузочной неделе, сне и питании. Это ориентир по журналу, а не медицинская оценка.'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () async {
                    await ref.read(appStateProvider).set(stateOvertrainingDismissed, check.weekStart);
                    ref.invalidate(overtrainingProvider);
                  },
                  child: Text(tr('Скрыть до следующей недели')),
                ),
                TextButton(onPressed: () => context.push('/settings'), child: Text(tr('Отключить'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
