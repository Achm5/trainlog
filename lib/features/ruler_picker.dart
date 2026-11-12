import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Горизонтальная линейка для выбора числа листанием: значения «прилипают» к центру,
/// каждое деление отдаётся лёгким тактильным щелчком.
class RulerPicker extends StatefulWidget {
  const RulerPicker({
    super.key,
    required this.value,
    required this.step,
    required this.max,
    required this.onChanged,
    required this.label,
    this.majorEvery = 4,
  });
  final double value;
  final double step;
  final double max;
  final ValueChanged<double> onChanged;

  /// Подпись крупного деления.
  final String Function(double value) label;
  final int majorEvery;

  @override
  State<RulerPicker> createState() => _RulerPickerState();
}

class _RulerPickerState extends State<RulerPicker> {
  late final FixedExtentScrollController _controller = FixedExtentScrollController(initialItem: _index(widget.value));
  bool _programmatic = false;

  int get _count => (widget.max / widget.step).floor() + 1;

  int _index(double v) => (v / widget.step).round().clamp(0, _count - 1);

  @override
  void didUpdateWidget(RulerPicker old) {
    super.didUpdateWidget(old);
    // Значение изменили снаружи (кнопки ± или ручной ввод) — докручиваем линейку.
    final target = _index(widget.value);
    if (_controller.hasClients && target != _controller.selectedItem && !_programmatic) {
      _programmatic = true;
      _controller
          .animateToItem(target, duration: const Duration(milliseconds: 180), curve: Curves.easeOut)
          .whenComplete(() => _programmatic = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 64,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          RotatedBox(
            quarterTurns: -1,
            child: ListWheelScrollView.useDelegate(
              controller: _controller,
              itemExtent: 14,
              diameterRatio: 100,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (i) {
                if (_programmatic) return;
                HapticFeedback.selectionClick();
                widget.onChanged(i * widget.step);
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: _count,
                builder: (context, i) {
                  final major = i % widget.majorEvery == 0;
                  return RotatedBox(
                    quarterTurns: 1,
                    child: Column(
                      children: [
                        Container(
                          width: major ? 2 : 1,
                          height: major ? 28 : 16,
                          color: major ? scheme.onSurface : scheme.outline,
                        ),
                        if (major)
                          SizedBox(
                            height: 18,
                            child: OverflowBox(
                              maxWidth: 64,
                              child: Text(
                                widget.label(i * widget.step),
                                softWrap: false,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          IgnorePointer(
            child: Container(
              width: 3,
              height: 40,
              decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(2)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Число, плавно «докручивающееся» до нового значения.
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber(this.value, {super.key, this.style, this.format});
  final double value;
  final TextStyle? style;
  final String Function(double v)? format;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(format?.call(v) ?? v.round().toString(), style: style),
    );
  }
}
