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

const programStatusLabels = {'draft': 'Черновик', 'active': 'Активная', 'archived': 'Архив'};

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
          const ListTile(
            title: Text('Готовые программы', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Создаётся черновик: упражнения, подходы и повторы уже расставлены, '
                'последняя неделя — разгрузка. Веса и дни недели можно поменять.'),
          ),
          for (final t in programTemplates)
            ListTile(
              leading: const Icon(Icons.auto_awesome_motion_outlined),
              title: Text(t.name),
              subtitle: Text('${t.description}\n${t.weeks} нед. · ${t.exercisesCount} упражнений'),
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
      toast(context, 'Черновик создан. Задайте веса и сделайте программу активной.');
      context.push('/program/$id');
    }
  } catch (e) {
    if (context.mounted) toast(context, 'Не удалось создать программу: $e');
  }
}

/// Список программ (мезоциклов).
class ProgramsScreen extends ConsumerWidget {
  const ProgramsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Программы'),
        actions: [
          IconButton(
            tooltip: 'Готовые программы',
            icon: const Icon(Icons.auto_awesome_motion_outlined),
            onPressed: () => pickProgramTemplate(context, ref),
          ),
          IconButton(
            tooltip: 'Импорт программы из CSV',
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
                  toast(context, 'Программа импортирована как черновик');
                  context.push('/program/$id');
                }
              } on FormatException catch (e) {
                if (context.mounted) toast(context, 'Не удалось импортировать: ${e.message}');
              } catch (e) {
                if (context.mounted) toast(context, 'Не удалось импортировать: $e');
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/program/new'),
        icon: const Icon(Icons.add),
        label: const Text('Программа'),
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
                    const Text('Программ пока нет. Возьмите готовую и поправьте под себя или соберите мезоцикл '
                        'с нуля: дни недели, упражнения и прогрессию по неделям.', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.auto_awesome_motion_outlined),
                      label: const Text('Готовые программы'),
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
                      '${programStatusLabels[p.status]} · ${p.weeksCount} нед. · с ${ruDate(parseYmd(p.startDate))}'),
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
