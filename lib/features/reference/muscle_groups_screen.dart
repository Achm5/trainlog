import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/database.dart';
import '../../providers.dart';
import '../common.dart';
import 'package:trainlog/i18n.dart';

/// Группы мышц и целевые коридоры рабочих подходов в неделю.
class MuscleGroupsScreen extends ConsumerWidget {
  const MuscleGroupsScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, MuscleGroup m) async {
    var range = RangeValues(m.targetSetsMin.toDouble(), m.targetSetsMax.toDouble());
    final saved = await showDialog<RangeValues>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(trName(m.name)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr('Коридор: {0}–{1} подходов в неделю', [range.start.round(), range.end.round()])),
              RangeSlider(
                values: range,
                min: 0,
                max: 30,
                divisions: 30,
                labels: RangeLabels('${range.start.round()}', '${range.end.round()}'),
                onChanged: (v) => setState(() => range = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Отмена'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, range), child: Text(tr('Сохранить'))),
          ],
        ),
      ),
    );
    if (saved != null) {
      await ref.read(referenceRepoProvider).updateCorridor(m.id, saved.start.round(), saved.end.round());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Группы мышц'))),
      body: AsyncView(
        value: ref.watch(muscleGroupsProvider),
        builder: (list) => ListView(
          children: [
            for (final m in list)
              ListTile(
                title: Text(trName(m.name)),
                subtitle: Text(tr('Цель: {0}–{1} подходов в неделю', [m.targetSetsMin, m.targetSetsMax])),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _edit(context, ref, m),
              ),
          ],
        ),
      ),
    );
  }
}
