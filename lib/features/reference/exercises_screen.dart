import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/reference_repo.dart';
import '../../providers.dart';
import '../common.dart';

/// Справочник упражнений с фильтрами: группа мышц, оборудование, тип.
/// В режиме выбора ([pickMode]) нажатие возвращает id упражнения.
class ExercisesScreen extends ConsumerStatefulWidget {
  const ExercisesScreen({super.key, this.pickMode = false});
  final bool pickMode;

  @override
  ConsumerState<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends ConsumerState<ExercisesScreen> {
  String _query = '';
  int? _muscleId;
  int? _equipmentId;
  String? _kind;
  bool _archived = false;

  bool _match(ExerciseView v) {
    final e = v.exercise;
    if (_query.isNotEmpty && !e.name.toLowerCase().contains(_query.toLowerCase())) return false;
    if (_kind != null && e.kind != _kind) return false;
    if (_equipmentId != null && e.equipmentId != _equipmentId) return false;
    if (_muscleId != null && !v.muscles.any((m) => m.muscleGroupId == _muscleId)) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(exercisesProvider(_archived));
    final muscles = ref.watch(muscleGroupsProvider).value ?? const [];
    final equipment = ref.watch(equipmentProvider).value ?? const [];
    final muscleNames = {for (final m in muscles) m.id: m.name};

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pickMode ? 'Выбор упражнения' : 'Упражнения'),
        actions: [
          if (!widget.pickMode)
            IconButton(
              tooltip: _archived ? 'Скрыть архивные' : 'Показать архивные',
              icon: Icon(_archived ? Icons.inventory_2 : Icons.inventory_2_outlined),
              onPressed: () => setState(() => _archived = !_archived),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/exercise/new'),
        icon: const Icon(Icons.add),
        label: const Text('Своё упражнение'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Поиск по названию', isDense: true),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _FilterMenu<int>(
                  label: 'Группа мышц',
                  value: _muscleId,
                  items: {for (final m in muscles) m.id: m.name},
                  onChanged: (v) => setState(() => _muscleId = v),
                ),
                const SizedBox(width: 8),
                _FilterMenu<int>(
                  label: 'Оборудование',
                  value: _equipmentId,
                  items: {for (final e in equipment) e.id: e.name},
                  onChanged: (v) => setState(() => _equipmentId = v),
                ),
                const SizedBox(width: 8),
                _FilterMenu<String>(
                  label: 'Тип',
                  value: _kind,
                  items: const {'compound': 'Базовое', 'isolation': 'Изолирующее'},
                  onChanged: (v) => setState(() => _kind = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncView(
              value: exercises,
              builder: (list) {
                final items = list.where(_match).toList();
                if (items.isEmpty) return const Center(child: Text('Ничего не найдено'));
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: items.length,
                  itemBuilder: (c, i) {
                    final v = items[i];
                    final e = v.exercise;
                    final ms = [...v.muscles]..sort((a, b) => b.share.compareTo(a.share));
                    return ListTile(
                      title: Text(e.name + (e.isArchived ? ' (в архиве)' : '')),
                      subtitle: Text([
                        e.kind == 'compound' ? 'Базовое' : 'Изолирующее',
                        ms.map((m) => '${muscleNames[m.muscleGroupId] ?? ''} ${m.share.toString().replaceAll('.', ',')}').join(', '),
                      ].join(' · ')),
                      trailing: widget.pickMode
                          ? null
                          : (e.baseExerciseId != null ? const Icon(Icons.subdirectory_arrow_right, size: 18) : null),
                      onTap: () => widget.pickMode ? Navigator.of(context).pop(e.id) : context.push('/exercise/${e.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterMenu<T> extends StatelessWidget {
  const _FilterMenu({required this.label, required this.value, required this.items, required this.onChanged});
  final String label;
  final T? value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T?>(
      onSelected: onChanged,
      itemBuilder: (c) => [
        PopupMenuItem<T?>(value: null, child: Text('Все · $label')),
        for (final e in items.entries) PopupMenuItem<T?>(value: e.key, child: Text(e.value)),
      ],
      child: Chip(
        label: Text(value == null ? label : items[value] ?? label),
        avatar: Icon(value == null ? Icons.filter_list : Icons.check, size: 18),
      ),
    );
  }
}

/// Открывает справочник в режиме выбора и возвращает id упражнения.
Future<int?> pickExercise(BuildContext context) => Navigator.of(context)
    .push<int>(MaterialPageRoute(builder: (_) => const ExercisesScreen(pickMode: true)));
