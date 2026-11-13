import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:trainlog/i18n.dart';

/// Индикатор введённых цифр PIN.
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.length, this.error = false});
  final int length;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = length < 4 ? 4 : length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 7),
            width: i < length ? 16 : 13,
            height: i < length ? 16 : 13,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < length ? (error ? scheme.error : scheme.primary) : Colors.transparent,
              border: Border.all(color: error ? scheme.error : scheme.outline, width: 1.5),
            ),
          ),
      ],
    );
  }
}

/// Собственная цифровая клавиатура для PIN (системная клавиатура не открывается).
class PinPad extends StatelessWidget {
  const PinPad({super.key, required this.onDigit, required this.onBackspace, this.extra});
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  /// Кнопка в левом нижнем углу (например, биометрия).
  final Widget? extra;

  Widget _key(BuildContext context, {String? digit, Widget? child, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.all(7),
      child: SizedBox(
        width: 76,
        height: 76,
        child: child == null && digit == null
            ? null
            : Material(
                color: digit == null ? Colors.transparent : Theme.of(context).colorScheme.surfaceContainerHigh,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    digit != null ? onDigit(digit) : onTap?.call();
                  },
                  child: Center(
                    child: child ?? Text(digit!, style: Theme.of(context).textTheme.headlineMedium),
                  ),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9']])
          Row(mainAxisSize: MainAxisSize.min, children: [for (final d in row) _key(context, digit: d)]),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            extra == null
                ? _key(context)
                : Padding(padding: const EdgeInsets.all(7), child: SizedBox(width: 76, height: 76, child: Center(child: extra))),
            _key(context, digit: '0'),
            _key(context, child: const Icon(Icons.backspace_outlined), onTap: onBackspace),
          ],
        ),
      ],
    );
  }
}

/// Полноэкранный ввод PIN своей клавиатурой. Возвращает введённые цифры или null при отмене.
Future<String?> askPinPad(BuildContext context, String title) =>
    Navigator.of(context).push<String>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => _PinEntryScreen(title: title)));

class _PinEntryScreen extends StatefulWidget {
  const _PinEntryScreen({required this.title});
  final String title;

  @override
  State<_PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<_PinEntryScreen> {
  String _pin = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                PinDots(length: _pin.length),
                const SizedBox(height: 24),
                PinPad(
                  onDigit: (d) => setState(() => _pin = _pin.length < 8 ? _pin + d : _pin),
                  onBackspace: () => setState(() => _pin = _pin.isEmpty ? _pin : _pin.substring(0, _pin.length - 1)),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _pin.length >= 4 ? () => Navigator.of(context).pop(_pin) : null,
                  child: Text(tr('Готово')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
