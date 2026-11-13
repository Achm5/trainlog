import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/dates.dart';
import '../../domain/program_templates.dart';
import '../../providers.dart';
import '../common.dart';
import 'package:trainlog/i18n.dart';

Map<String, String> get programStatusLabels => {'draft': tr('Черновик'), 'active': tr('Активная'), 'archived': tr('Архив')};

/// Выбор готовой программы: создаёт черновик, в котором остаётся задать веса.
Future<void> pickProgramTemplate(BuildContext context, WidgetRef ref) async {
  final template = await showModalBottomSheet<ProgramTemplate>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          ListTile(
            title: Text(tr('Готовые программы'), style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(tr('Создаётся черновик: упражнения, подходы и повторы уже расставлены, '
                'последняя неделя — разгрузка. Веса и дни недели можно поменять.')),
          ),
          for (final t in programTemplates)
            ListTile(
              leading: const Icon(Icons.auto_awesome_motion_outlined),
              title: Text(trName(t.name)),
              subtitle: Text(tr('{0}\n{1} нед. · {2} упражнений', [trName(t.description), t.weeks, t.exercisesCount])),
              isThreeLine: true,
              onTap: () => Navigator.pop(c, t),
            ),
        ],
      ),
    ),
  );
  if (template == null) return;
  try {
    final id = await ref.read(plannerRepoProvider).createFromTemplate(template, startDate: nearestMonday(today()));
    if (context.mounted) {
      toast(context, tr('Черновик создан. Задайте веса и сделайте программу активной.'));
      context.push('/program/$id');
    }
  } catch (e) {
    if (context.mounted) toast(context, tr('Не удалось создать программу: {0}', [e]));
  }
}

/// Список программ (мезоциклов).
class ProgramsScreen extends ConsumerWidget {
  const ProgramsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Программы')),
        actions: [
          IconButton(
            tooltip: tr('Готовые программы'),
            icon: const Icon(Icons.auto_awesome_motion_outlined),
            onPressed: () => pickProgramTemplate(context, ref),
          ),
          IconButton(
            tooltip: tr('Импорт программы из CSV'),
            icon: const Icon(Icons.upload_file),
            onPressed: () async {
              try {
                final picked = await FilePicker.pickFiles(type: FileType.any);
                final path = picked.isEmpty ? null : picked.first.path;
                if (path == null) return;
                final csv = utf8.decode(await File(path).readAsBytes(), allowMalformed: true);
                final id = await ref
                    .read(plannerRepoProvider)
                    .importProgramCsv(csv, startDate: nearestMonday(today()));
                if (context.mounted) {
                  toast(context, tr('Программа импортирована как черновик'));
                  context.push('/program/$id');
                }
              } on FormatException catch (e) {
                if (context.mounted) toast(context, tr('Не удалось импортировать: {0}', [e.message]));
              } catch (e) {
                if (context.mounted) toast(context, tr('Не удалось импортировать: {0}', [e]));
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/program/new'),
        icon: const Icon(Icons.add),
        label: Text(tr('Программа')),
      ),
      body: AsyncView(
        value: ref.watch(programsProvider),
        builder: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tr('Программ пока нет. Возьмите готовую и поправьте под себя или соберите мезоцикл '
                        'с нуля: дни недели, упражнения и прогрессию по неделям.'), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.auto_awesome_motion_outlined),
                      label: Text(tr('Готовые программы')),
                      onPressed: () => pickProgramTemplate(context, ref),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              for (final p in list)
                ListTile(
                  leading: Icon(p.status == 'active' ? Icons.play_circle : Icons.event_note,
                      color: p.status == 'active' ? Theme.of(context).colorScheme.primary : null),
                  title: Text(p.name),
                  subtitle: Text(
                      tr('{0} · {1} нед. · с {2}', [programStatusLabels[p.status], p.weeksCount, ruDate(parseYmd(p.startDate))])),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/program/${p.id}'),
                ),
            ],
          );
        },
      ),
    );
  }
}
