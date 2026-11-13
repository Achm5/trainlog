import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/database.dart';
import '../../domain/planning.dart';
import '../../providers.dart';
import '../../app.dart' show navSections;
import '../common.dart';

const roundingSteps = [0.5, 1.0, 1.25, 2.5];

/// Параметры расчётов из таблицы settings.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(referenceRepoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: AsyncView(
        value: ref.watch(settingsProvider),
        builder: (s) => ListView(
          children: [
            const ListTile(title: Text('Нижнее меню', style: TextStyle(fontWeight: FontWeight.bold))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('«Журнал» и «Ещё» закреплены. Скрытые разделы открываются из «Ещё». '
                  'Если разделов больше пяти, в меню остаются только значки.'),
            ),
            for (final t in navSections.where((t) => !t.fixed))
              SwitchListTile(
                secondary: Icon(t.icon),
                title: Text(t.title),
                value: ref.watch(navTabsProvider).contains(t.id),
                onChanged: (v) => ref.read(navTabsProvider.notifier).toggle(t.id, v),
              ),
            const Divider(),
            const ListTile(title: Text('Предупреждения', style: TextStyle(fontWeight: FontWeight.bold))),
            SwitchListTile(
              secondary: const Icon(Icons.monitor_heart_outlined),
              title: const Text('Предупреждать о перетренированности'),
              subtitle: const Text('Карточка в «Журнале» после закрытия недели, если совпало два признака и больше: '
                  'падение 1ПМ, много недоборов, скачок тоннажа, объём выше коридора, 6+ недель без разгрузки'),
              value: ref.watch(overtrainingEnabledProvider),
              onChanged: (v) => ref.read(overtrainingEnabledProvider.notifier).toggle(v),
            ),
            const Divider(),
            const ListTile(title: Text('Расчёты тренировок', style: TextStyle(fontWeight: FontWeight.bold))),
            ListTile(
              title: const Text('Шаг округления веса'),
              subtitle: const Text('Целевые веса плана округляются вниз до шага'),
              trailing: DropdownButton<double>(
                value: roundingSteps.contains(s.weightRoundingKg) ? s.weightRoundingKg : 2.5,
                items: [for (final v in roundingSteps) DropdownMenuItem(value: v, child: Text('${formatKg(v)} кг'))],
                onChanged: (v) async {
                  if (v == null) return;
                  await repo.updateSettings(SettingsCompanion(weightRoundingKg: Value(v)));
                  final active = await ref.read(plannerRepoProvider).activeProgram();
                  if (active != null) await ref.read(plannerRepoProvider).recalcProgram(active.id);
                },
              ),
            ),
            SwitchListTile(
              title: const Text('Учитывать RIR в расчётном 1ПМ'),
              subtitle: const Text('В формулу Эпли подставляется «повторы + RIR»'),
              value: s.e1rmUseRir,
              onChanged: (v) async {
                await repo.updateSettings(SettingsCompanion(e1rmUseRir: Value(v)));
                await ref.read(journalRepoProvider).recalcAll();
                if (context.mounted) toast(context, 'Расчётный 1ПМ пересчитан');
              },
            ),
            ListTile(
              title: const Text('Время одного подхода'),
              subtitle: const Text('Для расчёта длительности тренировки'),
              trailing: Text('${s.setDurationSec} с'),
              onTap: () async {
                final v = await askNumber(context, 'Время подхода, с', initial: s.setDurationSec.toDouble(), integer: true);
                if (v != null && v >= 10 && v <= 300) {
                  await repo.updateSettings(SettingsCompanion(setDurationSec: Value(v.round())));
                }
              },
            ),
            ListTile(
              title: const Text('Разминка'),
              subtitle: const Text('Добавляется к длительности каждого дня'),
              trailing: Text('${s.warmupMin} мин'),
              onTap: () async {
                final v = await askNumber(context, 'Разминка, мин', initial: s.warmupMin.toDouble(), integer: true);
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
