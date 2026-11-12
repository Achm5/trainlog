import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/strength.dart';

/// Отрисовка AsyncValue с единым видом загрузки и ошибки.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.builder});
  final AsyncValue<T> value;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
      error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Ошибка: $e'))),
    );
  }
}

/// Цвета статусов подхода (таблица 3.2 ТЗ).
Color statusColor(SetStatus? s, BuildContext context) => switch (s) {
      SetStatus.done || SetStatus.minorMiss => const Color(0xFF2E9E4F),
      SetStatus.partial => const Color(0xFFE0A800),
      SetStatus.failed => const Color(0xFFD64545),
      SetStatus.skipped => const Color(0xFF8A8F98),
      null => Theme.of(context).colorScheme.outlineVariant,
    };

class StatusDot extends StatelessWidget {
  const StatusDot(this.status, {super.key, this.size = 14});
  final SetStatus? status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = statusColor(status, context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      alignment: Alignment.center,
      // Метка «небольшой недобор» — зелёный с точкой.
      child: status == SetStatus.minorMiss
          ? Container(
              width: size * 0.4,
              height: size * 0.4,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            )
          : null,
    );
  }
}

double? parseNum(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

final decimalInput = <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
final intInput = <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly];

Future<bool> confirm(BuildContext context, String title, {String? message, String ok = 'Да'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok)),
      ],
    ),
  );
  return r ?? false;
}

/// Диалог ввода числа. Возвращает null при отмене.
Future<double?> askNumber(BuildContext context, String title, {double? initial, bool integer = false, String? suffix}) {
  final c = TextEditingController(
      text: initial == null ? '' : (integer ? initial.round().toString() : initial.toString().replaceAll('.', ',')));
  return showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        keyboardType: TextInputType.numberWithOptions(decimal: !integer),
        inputFormatters: integer ? intInput : decimalInput,
        decoration: InputDecoration(suffixText: suffix),
        onSubmitted: (v) => Navigator.pop(ctx, parseNum(v)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
        FilledButton(onPressed: () => Navigator.pop(ctx, parseNum(c.text)), child: const Text('Сохранить')),
      ],
    ),
  );
}

Future<String?> askText(BuildContext context, String title, {String initial = '', int maxLines = 1}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: c, autofocus: true, maxLines: maxLines),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Сохранить')),
      ],
    ),
  );
}

void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

String formatDuration(int seconds) {
  final m = seconds ~/ 60;
  if (m < 60) return '$m мин';
  return '${m ~/ 60} ч ${m % 60} мин';
}
