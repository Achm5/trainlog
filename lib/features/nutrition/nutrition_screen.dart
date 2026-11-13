import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/nutrition_repo.dart';
import '../../domain/dates.dart';
import '../../domain/nutrition.dart';
import '../../domain/planning.dart';
import '../../providers.dart';
import '../common.dart';
import '../motion.dart';
import '../ruler_picker.dart';
import 'product_picker.dart';

String g0(double v) => v.round().toString();

/// Экран дня: съедено / норма по калориям и БЖУ, вес дня и тренд, дневник по приёмам пищи.
class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key});

  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen> {
  DateTime _day = today();

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(nutritionRepoProvider);
    final d = ymd(_day);
    final entries = ref.watch(foodDayProvider(d)).value ?? const <FoodEntry>[];
    final target = ref.watch(targetProvider(d)).value;
    final weight = ref.watch(dayWeightProvider(d)).value;
    final t = Theme.of(context).textTheme;

    var kcal = 0.0, protein = 0.0, fat = 0.0, carbs = 0.0;
    for (final e in entries) {
      kcal += e.log.kcal;
      protein += e.log.proteinG;
      fat += e.log.fatG;
      carbs += e.log.carbsG;
    }

    Future<void> editWeight() async {
      final v = await askNumber(context, 'Вес ${ruDate(_day)}, кг', initial: weight?.weightKg);
      if (v != null && v > 20 && v < 400) await repo.setWeight(_day, v);
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _day = addDays(_day, -1))),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final p = await showDatePicker(
                      context: context, initialDate: _day, firstDate: DateTime(2020), lastDate: addDays(today(), 7));
                  if (p != null) setState(() => _day = dateOnly(p));
                },
                child: Text(_day == today() ? 'Сегодня' : '${weekdayShort[_day.weekday - 1]}, ${ruDate(_day)}',
                    textAlign: TextAlign.center),
              ),
            ),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => _day = addDays(_day, 1))),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: target == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Съедено: ${g0(kcal)} ккал', style: t.titleLarge),
                        Text('Б ${g0(protein)} · Ж ${g0(fat)} · У ${g0(carbs)} г'),
                        const SizedBox(height: 8),
                        const Text('Норма не рассчитана: заполните профиль (пол, дата рождения, рост) и запишите вес.'),
                        TextButton(onPressed: () => context.push('/profile'), child: const Text('Заполнить профиль')),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            AnimatedNumber(kcal, style: t.headlineMedium),
                            Text(' / ${g0(target.kcalTarget)} ккал', style: t.titleMedium),
                            const Spacer(),
                            Text(
                              kcal <= target.kcalTarget
                                  ? 'осталось ${g0(target.kcalTarget - kcal)}'
                                  : 'сверх нормы ${g0(kcal - target.kcalTarget)}',
                              style: t.bodyMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(end: (kcal / target.kcalTarget).clamp(0, 1).toDouble()),
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.easeOutCubic,
                          builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 8),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _Macro('Белки', protein, target.proteinG),
                            _Macro('Жиры', fat, target.fatG),
                            _Macro('Углеводы', carbs, target.carbsG),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Расход ${g0(target.tdee)} ккал (${target.tdeeSource == 'adaptive' ? 'адаптивный' : 'по формуле'}) · '
                          'базовый обмен ${g0(target.bmr)}',
                          style: t.bodySmall,
                        ),
                      ],
                    ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.monitor_weight_outlined),
              title: Text(weight == null ? 'Вес не записан' : 'Вес: ${formatKg(weight.weightKg)} кг'),
              subtitle: Text(weight?.trendKg == null
                  ? 'Взвешивайтесь утром — по тренду считается расход'
                  : 'Тренд: ${weight!.trendKg!.toStringAsFixed(1).replaceAll('.', ',')} кг'),
              trailing: weight == null
                  ? IconButton.filledTonal(tooltip: 'Записать вес', onPressed: editWeight, icon: const Icon(Icons.add))
                  : IconButton(icon: const Icon(Icons.edit_outlined), onPressed: editWeight),
              onLongPress: weight == null ? null : () => repo.setWeight(_day, null),
            ),
          ),
          _WaterCard(day: _day),
          for (final (i, meal) in mealOrder.indexed)
            Appear(
              key: ValueKey('meal-$meal'),
              index: i + 1,
              child: _MealCard(
                day: _day,
                meal: meal,
                entries: entries.where((e) => e.log.meal == meal).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

/// Трекер воды: выпито / норма и быстрые кнопки.
class _WaterCard extends ConsumerWidget {
  const _WaterCard({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(nutritionRepoProvider);
    final d = ymd(day);
    final drunk = ref.watch(waterProvider(d)).value ?? 0;
    final target = ref.watch(waterTargetProvider(d)).value;
    final t = Theme.of(context).textTheme;
    const blue = Color(0xFF3F9BD8);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.water_drop_outlined, color: blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    target == null ? 'Вода: $drunk мл' : 'Вода: $drunk / $target мл',
                    style: t.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Отменить последнюю запись',
                  icon: const Icon(Icons.undo),
                  onPressed: drunk == 0 ? null : () => repo.undoWater(day),
                ),
              ],
            ),
            if (target != null) ...[
              const SizedBox(height: 4),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(end: (drunk / target).clamp(0, 1).toDouble()),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 8, color: blue),
              ),
            ] else
              Text('Запишите вес — рассчитаю дневную норму.', style: t.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final ml in const [200, 250, 500])
                  ActionChip(label: Text('+$ml мл'), onPressed: () => repo.addWater(day, ml)),
                ActionChip(
                  label: const Text('Другое'),
                  onPressed: () async {
                    final v = await askNumber(context, 'Сколько выпито, мл', integer: true, suffix: 'мл');
                    if (v != null && v > 0 && v <= 5000) await repo.addWater(day, v.round());
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro(this.label, this.value, this.target);
  final String label;
  final double value;
  final double target;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          Text('${g0(value)} / ${g0(target)} г', style: Theme.of(context).textTheme.titleSmall),
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 2),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: target <= 0 ? 0 : (value / target).clamp(0, 1).toDouble()),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(value: v),
            ),
          ),
        ],
      ),
    );
  }
}

class _MealCard extends ConsumerWidget {
  const _MealCard({required this.day, required this.meal, required this.entries});
  final DateTime day;
  final String meal;
  final List<FoodEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(nutritionRepoProvider);
    final kcal = entries.fold<double>(0, (s, e) => s + e.log.kcal);
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(mealLabels[meal]!, style: Theme.of(context).textTheme.titleMedium),
            subtitle: entries.isEmpty ? null : Text('${g0(kcal)} ккал'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Скопировать со вчера',
                  icon: const Icon(Icons.copy_all_outlined),
                  onPressed: () async {
                    final n = await repo.copyMeal(from: addDays(day, -1), to: day, meal: meal);
                    if (context.mounted) toast(context, n == 0 ? 'Вчера этот приём пищи пуст' : 'Скопировано записей: $n');
                  },
                ),
                IconButton.filledTonal(
                  tooltip: 'Добавить продукт',
                  icon: const Icon(Icons.add),
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => ProductPickerScreen(day: day, meal: meal))),
                ),
              ],
            ),
          ),
          for (final e in entries)
            Dismissible(
              key: ValueKey(e.log.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Theme.of(context).colorScheme.errorContainer,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                child: const Icon(Icons.delete_outline),
              ),
              onDismissed: (_) => repo.deleteFood(e.log.id),
              child: ListTile(
                dense: true,
                title: Text(e.product?.name ?? 'Продукт удалён'),
                subtitle: Text('${g0(e.log.grams)} г · Б ${g0(e.log.proteinG)} Ж ${g0(e.log.fatG)} У ${g0(e.log.carbsG)}'),
                trailing: Text('${g0(e.log.kcal)} ккал'),
                onTap: () async {
                  final v = await askNumber(context, 'Граммы', initial: e.log.grams, suffix: 'г');
                  if (v != null && v > 0) await repo.updateGrams(e.log, v);
                },
              ),
            ),
        ],
      ),
    );
  }
}
