import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/database.dart';
import '../../providers.dart';
import '../common.dart';

const _shareOptions = [0.25, 0.5, 0.75, 1.0];

/// Создание и правка упражнения: название, тип, оборудование, базовое движение, доли групп мышц.
class ExerciseEditScreen extends ConsumerStatefulWidget {
  const ExerciseEditScreen({super.key, this.exerciseId});
  final int? exerciseId;

  @override
  ConsumerState<ExerciseEditScreen> createState() => _ExerciseEditScreenState();
}

class _ExerciseEditScreenState extends ConsumerState<ExerciseEditScreen> {
  final _name = TextEditingController();
  String _kind = 'compound';
  int? _equipmentId;
  int? _baseId;
  final Map<int, double> _shares = {};
  Exercise? _loaded;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.exerciseId;
    if (id != null) {
      final repo = ref.read(referenceRepoProvider);
      final e = await repo.exercise(id);
      if (e != null) {
        _loaded = e;
        _name.text = e.name;
        _kind = e.kind;
        _equipmentId = e.equipmentId;
        _baseId = e.baseExerciseId;
        for (final m in await repo.musclesOf(id)) {
          _shares[m.muscleGroupId] = m.share;
        }
      }
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return toast(context, 'Введите название');
    if (_shares.isEmpty) return toast(context, 'Укажите хотя бы одну группу мышц');
    if (!_shares.values.any((s) => s == 1.0)) return toast(context, 'У основной группы мышц доля должна быть 1,0');
    await ref.read(referenceRepoProvider).saveExercise(
          id: widget.exerciseId,
          name: name,
          kind: _kind,
          baseExerciseId: _baseId,
          equipmentId: _equipmentId,
          shares: _shares,
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final id = widget.exerciseId!;
    if (!await confirm(context, 'Удалить упражнение?',
        message: 'Если упражнение есть в журнале или программах, оно будет перенесено в архив.')) {
      return;
    }
    final deleted = await ref.read(referenceRepoProvider).deleteOrArchive(id);
    if (!mounted) return;
    toast(context, deleted ? 'Упражнение удалено' : 'Упражнение используется — перенесено в архив');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final muscles = ref.watch(muscleGroupsProvider).value ?? const <MuscleGroup>[];
    final equipment = ref.watch(equipmentProvider).value ?? const <EquipmentItem>[];
    final all = ref.watch(exercisesProvider(false)).value ?? const [];
    final bases = all.where((v) => v.exercise.baseExerciseId == null && v.exercise.id != widget.exerciseId).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exerciseId == null ? 'Новое упражнение' : 'Упражнение'),
        actions: [
          if (_loaded != null && _loaded!.isArchived)
            IconButton(
              tooltip: 'Вернуть из архива',
              icon: const Icon(Icons.unarchive),
              onPressed: () async {
                await ref.read(referenceRepoProvider).setArchived(_loaded!.id, false);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          if (widget.exerciseId != null) IconButton(tooltip: 'Удалить', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'Название')),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'compound', label: Text('Базовое')),
                    ButtonSegment(value: 'isolation', label: Text('Изолирующее')),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (s) => setState(() => _kind = s.first),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int?>(
                  initialValue: _equipmentId,
                  decoration: const InputDecoration(labelText: 'Оборудование'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Не указано')),
                    for (final e in equipment) DropdownMenuItem<int?>(value: e.id, child: Text(e.name)),
                  ],
                  onChanged: (v) => setState(() => _equipmentId = v),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int?>(
                  initialValue: bases.any((b) => b.exercise.id == _baseId) ? _baseId : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Базовое движение',
                    helperText: 'Заполните, если это вариация другого упражнения',
                  ),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Это базовое движение')),
                    for (final b in bases) DropdownMenuItem<int?>(value: b.exercise.id, child: Text(b.exercise.name)),
                  ],
                  onChanged: (v) => setState(() => _baseId = v),
                ),
                const SizedBox(height: 24),
                Text('Группы мышц и доли', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                const Text('Основная группа — 1,0; вторичные — 0,25–0,75.'),
                const SizedBox(height: 8),
                for (final m in muscles)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(child: Text(m.name)),
                        for (final s in _shareOptions)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: ChoiceChip(
                              label: Text(s.toString().replaceAll('.', ',')),
                              selected: _shares[m.id] == s,
                              visualDensity: VisualDensity.compact,
                              onSelected: (on) => setState(() => on ? _shares[m.id] = s : _shares.remove(m.id)),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton(onPressed: _save, child: const Text('Сохранить')),
              ],
            ),
    );
  }
}
