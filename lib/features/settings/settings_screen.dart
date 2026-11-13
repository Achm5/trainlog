import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/database.dart';
import '../../domain/planning.dart';
import '../../providers.dart';
import '../../app.dart' show navSections;
import '../common.dart';
import 'package:trainlog/i18n.dart';


/// Параметры расчётов из таблицы settings.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(referenceRepoProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Настройки'))),
      body: AsyncView(
        value: ref.watch(settingsProvider),
        builder: (s) => ListView(
          children: [
            ListTile(title: Text(tr('Язык и единицы'), style: const TextStyle(fontWeight: FontWeight.bold))),
            ListTile(leading: const Icon(Icons.language), title: Text(tr('Язык'))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<AppLang>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: AppLang.ru, label: Text('Русский')),
                    ButtonSegment(value: AppLang.en, label: Text('English')),
                  ],
                  selected: {ref.watch(localeProvider).lang},
                  onSelectionChanged: (v) => ref.read(localeProvider.notifier).setLang(v.first),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.scale_outlined),
              title: Text(tr('Единицы веса')),
              subtitle: Text(tr('Штанга и вес тела. В базе веса хранятся в килограммах')),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: false, label: Text(I18n.lang == AppLang.en ? 'kg' : 'кг')),
                    const ButtonSegment(value: true, label: Text('lb')),
                  ],
                  selected: {ref.watch(localeProvider).pounds},
                  onSelectionChanged: (v) => ref.read(localeProvider.notifier).setPounds(v.first),
                ),
              ),
            ),
            const Divider(),
            ListTile(title: Text(tr('Нижнее меню'), style: TextStyle(fontWeight: FontWeight.bold))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(tr('«Журнал» и «Ещё» закреплены. Скрытые разделы открываются из «Ещё». '
                  'Если разделов больше пяти, в меню остаются только значки.')),
            ),
            for (final t in navSections.where((t) => !t.fixed))
              SwitchListTile(
                secondary: Icon(t.icon),
                title: Text(tr(t.title)),
                value: ref.watch(navTabsProvider).contains(t.id),
                onChanged: (v) => ref.read(navTabsProvider.notifier).toggle(t.id, v),
              ),
            const Divider(),
            ListTile(title: Text(tr('Уведомления и предупреждения'), style: TextStyle(fontWeight: FontWeight.bold))),
            SwitchListTile(
              secondary: const Icon(Icons.lock_clock_outlined),
              title: Text(tr('Ход тренировки на экране блокировки')),
              subtitle: Text(tr('Постоянное уведомление во время тренировки: следующий подход и отсчёт отдыха')),
              value: ref.watch(workoutNotificationProvider),
              onChanged: (v) => ref.read(workoutNotificationProvider.notifier).toggle(v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.monitor_heart_outlined),
              title: Text(tr('Предупреждать о перетренированности')),
              subtitle: Text(tr('Карточка в «Журнале» после закрытия недели, если совпало два признака и больше: '
                  'падение 1ПМ, много недоборов, скачок тоннажа, объём выше коридора, 6+ недель без разгрузки')),
              value: ref.watch(overtrainingEnabledProvider),
              onChanged: (v) => ref.read(overtrainingEnabledProvider.notifier).toggle(v),
            ),
            const Divider(),
            ListTile(title: Text(tr('Расчёты тренировок'), style: TextStyle(fontWeight: FontWeight.bold))),
            ListTile(
              title: Text(tr('Шаг округления веса')),
              subtitle: Text(tr('Целевые веса плана округляются вниз до шага')),
              trailing: DropdownButton<double>(
                value: roundingSteps.contains(s.weightRoundingKg) ? s.weightRoundingKg : defaultRoundingStep,
                items: [for (final v in roundingSteps) DropdownMenuItem(value: v, child: Text(tr('{0} кг', [formatKg(v)])))],
                onChanged: (v) async {
                  if (v == null) return;
                  await repo.updateSettings(SettingsCompanion(weightRoundingKg: Value(v)));
                  final active = await ref.read(plannerRepoProvider).activeProgram();
                  if (active != null) await ref.read(plannerRepoProvider).recalcProgram(active.id);
                },
              ),
            ),
            SwitchListTile(
              title: Text(tr('Учитывать RIR в расчётном 1ПМ')),
              subtitle: Text(tr('В формулу Эпли подставляется «повторы + RIR»')),
              value: s.e1rmUseRir,
              onChanged: (v) async {
                await repo.updateSettings(SettingsCompanion(e1rmUseRir: Value(v)));
                await ref.read(journalRepoProvider).recalcAll();
                if (context.mounted) toast(context, tr('Расчётный 1ПМ пересчитан'));
              },
            ),
            ListTile(
              title: Text(tr('Время одного подхода')),
              subtitle: Text(tr('Для расчёта длительности тренировки')),
              trailing: Text(tr('{0} с', [s.setDurationSec])),
              onTap: () async {
                final v = await askNumber(context, tr('Время подхода, с'), initial: s.setDurationSec.toDouble(), integer: true);
                if (v != null && v >= 10 && v <= 300) {
                  await repo.updateSettings(SettingsCompanion(setDurationSec: Value(v.round())));
                }
              },
            ),
            ListTile(
              title: Text(tr('Разминка')),
              subtitle: Text(tr('Добавляется к длительности каждого дня')),
              trailing: Text(tr('{0} мин', [s.warmupMin])),
              onTap: () async {
                final v = await askNumber(context, tr('Разминка, мин'), initial: s.warmupMin.toDouble(), integer: true);
                if (v != null && v >= 0 && v <= 60) {
                  await repo.updateSettings(SettingsCompanion(warmupMin: Value(v.round())));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
