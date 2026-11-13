import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/database.dart';
import '../../domain/dates.dart';
import '../../domain/nutrition.dart';
import '../../providers.dart';
import '../common.dart';
import 'package:trainlog/i18n.dart';

String _n(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString().replaceAll('.', decSep);

/// Профиль и параметры питания (таблица settings). Любая правка пересчитывает норму.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(targetProvider(ymd(today()))).value;

    Future<void> save(SettingsCompanion data, {bool keepAdaptive = true}) async {
      await ref.read(referenceRepoProvider).updateSettings(data);
      await ref.read(nutritionRepoProvider).recalcFormulaTarget(keepAdaptive: keepAdaptive);
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr('Профиль и питание'))),
      body: AsyncView(
        value: ref.watch(settingsProvider),
        builder: (s) {
          final adjustRange = switch (s.goal) { 'gain' => (5.0, 15.0), 'cut' => (10.0, 20.0), _ => (0.0, 0.0) };
          final proteinRange = switch (s.goal) { 'gain' => (1.6, 2.0), 'cut' => (2.0, 2.2), _ => (1.6, 1.8) };
          return ListView(
            children: [
              ListTile(
                title: Text(tr('Имя')),
                trailing: Text(s.name.isEmpty ? tr('не указано') : s.name),
                onTap: () async {
                  final v = await askText(context, tr('Имя'), initial: s.name);
                  if (v != null) await save(SettingsCompanion(name: Value(v.trim())));
                },
              ),
              ListTile(
                title: Text(tr('Пол')),
                subtitle: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [ButtonSegment(value: 'm', label: Text(tr('Муж.'))), ButtonSegment(value: 'f', label: Text(tr('Жен.')))],
                  selected: {s.sex},
                  onSelectionChanged: (v) => save(SettingsCompanion(sex: Value(v.first))),
                ),
              ),
              ListTile(
                title: Text(tr('Дата рождения')),
                trailing: Text(s.birthDate == null ? tr('не указана') : ruDate(parseYmd(s.birthDate!))),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: s.birthDate == null ? DateTime(1995) : parseYmd(s.birthDate!),
                    firstDate: DateTime(1930),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) await save(SettingsCompanion(birthDate: Value(ymd(d))));
                },
              ),
              ListTile(
                title: Text(tr('Рост')),
                trailing: Text(s.heightCm == null ? tr('не указан') : tr('{0} см', [_n(s.heightCm!)])),
                onTap: () async {
                  final v = await askNumber(context, tr('Рост, см'), initial: s.heightCm);
                  if (v != null && v >= 100 && v <= 250) await save(SettingsCompanion(heightCm: Value(v)));
                },
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: DropdownButtonFormField<double>(
                  initialValue: activityLevels.containsKey(s.activityK) ? s.activityK : 1.375,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: tr('Активность')),
                  items: [
                    for (final e in activityLevels.entries)
                      DropdownMenuItem(value: e.key, child: Text('${e.value} (×${_n(e.key)})')),
                  ],
                  onChanged: (v) => v == null ? null : save(SettingsCompanion(activityK: Value(v)), keepAdaptive: false),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [for (final e in goalLabels.entries) ButtonSegment(value: e.key, label: Text(e.value))],
                  selected: {s.goal},
                  onSelectionChanged: (v) {
                    final d = goalDefaults(v.first);
                    save(SettingsCompanion(
                        goal: Value(v.first), goalAdjustPct: Value(d.adjustPct), proteinGPerKg: Value(d.proteinPerKg)));
                  },
                ),
              ),
              if (s.goal != 'maintain')
                ListTile(
                  title: Text(tr('Поправка на цель: {0}{1}%', [s.goal == 'gain' ? '+' : '−', _n(s.goalAdjustPct)])),
                  subtitle: Slider(
                    value: s.goalAdjustPct.clamp(adjustRange.$1, adjustRange.$2).toDouble(),
                    min: adjustRange.$1,
                    max: adjustRange.$2,
                    divisions: (adjustRange.$2 - adjustRange.$1).round(),
                    onChanged: (v) => save(SettingsCompanion(goalAdjustPct: Value(v.roundToDouble()))),
                  ),
                ),
              ListTile(
                title: Text(tr('Белок: {0} г/кг', [_n(s.proteinGPerKg)])),
                subtitle: Slider(
                  value: s.proteinGPerKg.clamp(proteinRange.$1, proteinRange.$2).toDouble(),
                  min: proteinRange.$1,
                  max: proteinRange.$2,
                  divisions: ((proteinRange.$2 - proteinRange.$1) * 10).round(),
                  onChanged: (v) => save(SettingsCompanion(proteinGPerKg: Value((v * 10).round() / 10))),
                ),
              ),
              ListTile(
                title: Text(tr('Жиры, не менее')),
                trailing: Text(tr('{0} г/кг', [_n(s.fatGPerKgMin)])),
                onTap: () async {
                  final v = await askNumber(context, tr('Жиры, г/кг (не менее 0,8)'), initial: s.fatGPerKgMin);
                  if (v != null && v >= 0.8 && v <= 2) await save(SettingsCompanion(fatGPerKgMin: Value(v)));
                },
              ),
              ListTile(
                title: Text(trKeepKg('Калорий в 1 кг массы')),
                subtitle: Text(tr('Приближённая константа для адаптивного расхода')),
                trailing: Text(_n(s.kcalPerKg)),
                onTap: () async {
                  final v = await askNumber(context, trKeepKg('ккал на 1 кг'), initial: s.kcalPerKg, integer: true);
                  if (v != null && v >= 5000 && v <= 9500) await save(SettingsCompanion(kcalPerKg: Value(v)));
                },
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: target == null
                    ? Text(tr('Норма появится, когда будут указаны дата рождения и рост и записан вес на вкладке «Питание».'))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('Текущая норма: {0} ккал', [target.kcalTarget.round()]),
                              style: Theme.of(context).textTheme.titleMedium),
                          Text(tr('Белки {0} г · жиры {1} г · углеводы {2} г', [target.proteinG.round(), target.fatG.round(), target.carbsG.round()])),
                          Text(tr('Базовый обмен {0} · расход {1} ккал '
                              '({2}) · действует с {3}', [target.bmr.round(), target.tdee.round(), target.tdeeSource == 'adaptive' ? tr('адаптивный') : tr('по формуле'), ruDate(parseYmd(target.validFrom))])),
                          if (target.kcalTarget.round() == target.bmr.round())
                            Text(tr('Норма поднята до базового обмена: ниже него калорийность не опускается.')),
                          if (target.tdeeSource == 'adaptive')
                            TextButton(
                              onPressed: () => ref.read(nutritionRepoProvider).recalcFormulaTarget(keepAdaptive: false),
                              child: Text(tr('Сбросить расход к формульному')),
                            ),
                        ],
                      ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Text(tr('Приложение не даёт медицинских рекомендаций.')),
              ),
            ],
          );
        },
      ),
    );
  }
}
