import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/dates.dart';
import '../../providers.dart';
import '../common.dart';

const programStatusLabels = {'draft': 'Черновик', 'active': 'Активная', 'archived': 'Архив'};

/// Список программ (мезоциклов).
class ProgramsScreen extends ConsumerWidget {
  const ProgramsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Программы')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/program/new'),
        icon: const Icon(Icons.add),
        label: const Text('Программа'),
      ),
      body: AsyncView(
        value: ref.watch(programsProvider),
        builder: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Программ пока нет. Создайте мезоцикл: дни недели, упражнения и прогрессию по неделям.',
                    textAlign: TextAlign.center),
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
