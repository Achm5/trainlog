import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/planning.dart';
import '../../domain/plates.dart';
import '../../providers.dart';
import 'package:trainlog/i18n.dart';

const statePlateBarKg = 'plate_bar_kg';
const statePlateBarLb = 'plate_bar_lb';
const _barsKg = [20.0, 15.0, 10.0];
const _barsLb = [45.0, 35.0, 15.0];
const _platesLb = [45.0, 35.0, 25.0, 10.0, 5.0, 2.5];

Color _plateColor(double kg) => switch (kg) {
      >= 25 => const Color(0xFFD64545),
      >= 20 => const Color(0xFF3F6FD8),
      >= 15 => const Color(0xFFE0A800),
      >= 10 => const Color(0xFF2E9E4F),
      >= 5 => const Color(0xFFE8E8E8),
      _ => const Color(0xFF8A8F98),
    };

/// Калькулятор блинов: какие диски повесить на каждую сторону грифа под нужный вес.
Future<void> showPlateCalculator(BuildContext context, {required double weightKg, required double step}) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _PlateCalculator(weightKg: weightKg, step: step),
    );

class _PlateCalculator extends ConsumerStatefulWidget {
  const _PlateCalculator({required this.weightKg, required this.step});
  final double weightKg;
  final double step;

  @override
  ConsumerState<_PlateCalculator> createState() => _PlateCalculatorState();
}

class _PlateCalculatorState extends ConsumerState<_PlateCalculator> {
  // Калькулятор считает в единицах показа: килограммы или фунты.
  final bool _lb = I18n.pounds;
  late final List<double> _bars = _lb ? _barsLb : _barsKg;
  late final List<double> _plates = _lb ? _platesLb : defaultPlates;
  late final String _barKey = _lb ? statePlateBarLb : statePlateBarKg;
  late double _weight = _lb ? (weightToDisplay(widget.weightKg) / 5).round() * 5.0 : widget.weightKg;
  late double _bar = _bars.first;

  @override
  void initState() {
    super.initState();
    () async {
      final saved = double.tryParse(await ref.read(appStateProvider).get(_barKey) ?? '');
      if (saved != null && _bars.contains(saved) && mounted) setState(() => _bar = saved);
    }();
  }

  void _setBar(double v) {
    setState(() => _bar = v);
    ref.read(appStateProvider).set(_barKey, v.toString());
  }

  void _shift(double delta) => setState(() => _weight = (_weight + delta).clamp(0, 1000).toDouble());

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final load = platesFor(targetKg: _weight, barKg: _bar, plates: _plates);
    final step = _lb ? 5.0 : (widget.step <= 0 ? 2.5 : widget.step);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('Блины на штангу'), style: t.titleLarge),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton.filledTonal(onPressed: () => _shift(-step), icon: const Icon(Icons.remove)),
                Expanded(
                  child: Text(tr('{0} кг', [formatNum(_weight)]), textAlign: TextAlign.center, style: t.headlineMedium),
                ),
                IconButton.filledTonal(onPressed: () => _shift(step), icon: const Icon(Icons.add)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(tr('Гриф'), style: t.bodyMedium),
                const SizedBox(width: 12),
                for (final b in _bars)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(tr('{0} кг', [formatNum(b)])),
                      selected: _bar == b,
                      onSelected: (_) => _setBar(b),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (load == null)
              Text(tr('Вес меньше грифа ({0} кг).', [formatNum(_bar)]), style: t.bodyLarge)
            else ...[
              Text(tr('На каждую сторону'), style: t.bodySmall),
              const SizedBox(height: 4),
              Text(platesLabel(load), style: t.headlineSmall),
              const SizedBox(height: 12),
              // Рисунок одной стороны: гриф слева, диски от втулки наружу.
              SizedBox(
                height: 84,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(width: 36, height: 10, color: scheme.outline),
                    for (final kg in platesSequence(load).take(12).map((v) => _lb ? v * kgPerLb : v))
                      Container(
                        width: kg >= 10 ? 16 : 11,
                        height: 30 + kg.clamp(1.25, 25).toDouble() / 25 * 54,
                        margin: const EdgeInsets.only(right: 2),
                        decoration: BoxDecoration(
                          color: _plateColor(kg),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: scheme.outlineVariant, width: 0.5),
                        ),
                      ),
                    Container(width: 24, height: 10, color: scheme.outline),
                  ],
                ),
              ),
              if (!load.exact) ...[
                const SizedBox(height: 8),
                Text(
                  tr('Стандартными дисками точно не набрать: получится {0} кг, '
                  'не хватает {1} кг на сторону.', [formatNum(load.achievedKg), formatNum(load.remainderKg)]),
                  style: t.bodyMedium?.copyWith(color: scheme.error),
                ),
              ],
            ],
            const SizedBox(height: 8),
            Text(tr('Диски: {0} кг.', [_plates.map(formatNum).join(', ')]), style: t.bodySmall),
          ],
        ),
      ),
    );
  }
}
