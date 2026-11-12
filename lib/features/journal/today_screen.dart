import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/database.dart';
import '../../domain/dates.dart';
import '../../providers.dart';
import '../common.dart';
import '../data/data_screen.dart';
import '../motion.dart';
import '../recommendations/recommendations.dart';

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
      appBar: AppBar(title: Text('Журнал · ${weekdayShort[now.weekday - 1]}, ${ruDate(now)}')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          BackupReminderCard(onOpen: () => context.push('/data')),
          for (final r in newRecs) Appear(key: ValueKey('rec-${r.rec.id}'), child: RecommendationCard(r)),
          if (inProgress != null)
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: ListTile(
                leading: const Icon(Icons.play_arrow),
                title: const Text('Незавершённая тренировка'),
                subtitle: Text('Начата ${ruDate(parseYmd(inProgress.date))}'),
                trailing: FilledButton(
                  onPressed: () => context.push('/session/${inProgress.id}'),
                  child: const Text('Продолжить'),
                ),
              ),
            ),
          if (program == null)
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Нет активной программы'),
                subtitle: Text('Создайте программу на вкладке «План» и сделайте её активной — '
                    'тренировки дня будут предзаполняться из плана.'),
              ),
            )
          else if (week == null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.event_busy),
                title: Text(program.name),
                subtitle: Text(parseYmd(program.startDate).isAfter(now)
                    ? 'Цикл начнётся ${ruDate(parseYmd(program.startDate))}'
                    : 'Цикл завершён. Создайте следующую программу на вкладке «План».'),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: Text(
                '${program.name} · неделя ${week.weekNo} из ${program.weeksCount}${week.isDeload ? ' · разгрузка' : ''}',
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
                  title: Text(d.name.isEmpty ? weekdayFull[d.weekday - 1] : d.name),
                  subtitle: Text(d.weekday == now.weekday ? 'Сегодня' : weekdayFull[d.weekday - 1]),
                  trailing: doneDayIds.contains(d.id)
                      ? TextButton(onPressed: () => start(d), child: const Text('Открыть'))
                      : (d.weekday == now.weekday
                          ? FilledButton(onPressed: () => start(d), child: const Text('Начать'))
                          : OutlinedButton(onPressed: () => start(d), child: const Text('Начать'))),
                ),
              )),
          ],
          const SizedBox(height: 4),
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Свободная тренировка'),
            onPressed: () async {
              final id = await journal.startFreeSession(now);
              if (context.mounted) context.push('/session/$id');
            },
          ),
          const SizedBox(height: 16),
          Text('История', style: Theme.of(context).textTheme.titleMedium),
          if (history.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('Тренировок пока нет')),
          for (final h in history)
            ListTile(
              leading: Icon(h.session.status == 'completed' ? Icons.check_circle_outline : Icons.timelapse),
              title: Text(h.day == null
                  ? 'Свободная тренировка'
                  : (h.day!.name.isEmpty ? weekdayFull[h.day!.weekday - 1] : h.day!.name)),
              subtitle: Text([
                ruDate(parseYmd(h.session.date)),
                if (h.session.finishedAt != null)
                  formatDuration((h.session.finishedAt! - h.session.startedAt) ~/ 1000)
                else
                  'не завершена',
              ].join(' · ')),
              onTap: () => context.push('/session/${h.session.id}'),
            ),
        ],
      ),
    );
  }
}
