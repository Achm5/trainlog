import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/database.dart';
import '../../domain/dates.dart';
import '../../domain/planning.dart';
import '../../providers.dart';
import '../common.dart';
import '../settings/settings_screen.dart' show roundingSteps;

/// Параметры программы (раздел 2.1 ТЗ). Для новой программы задаются дни недели и длина цикла;
/// у существующей меняются название, лимит времени, неделя разгрузки и коэффициенты.
class ProgramFormScreen extends ConsumerStatefulWidget {
  const ProgramFormScreen({super.key, this.programId});
  final int? programId;

  @override
  ConsumerState<ProgramFormScreen> createState() => _ProgramFormScreenState();
}

class _ProgramFormScreenState extends ConsumerState<ProgramFormScreen> {
  final _name = TextEditingController(text: 'Мезоцикл');
  Set<int> _weekdays = {1, 3, 5};
  int _timeLimit = 75;
  int _weeks = 5;
  int? _deloadWeek = 5;
  DateTime _start = nearestMonday(today());
  double _setsK = 0.5;
  double _weightK = 0.9;
  int _rirAdd = 2;
  double _step = 2.5;
  bool _ready = false;

  bool get _isNew => widget.programId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(plannerRepoProvider);
    final s = await ref.read(databaseProvider).getSettings();
    _step = s.weightRoundingKg;
    final id = widget.programId;
    if (id != null) {
      final p = await repo.watchProgram(id).first;
      if (p != null) {
        _name.text = p.name;
        _timeLimit = p.timeLimitMin;
        _weeks = p.weeksCount;
        _start = parseYmd(p.startDate);
        _setsK = p.deloadSetsK;
        _weightK = p.deloadWeightK;
        _rirAdd = p.deloadRirAdd;
        final weeks = await repo.weeksOf(id);
        _deloadWeek = weeks.where((w) => w.isDeload).map((w) => w.weekNo).firstOrNull;
        _weekdays = (await repo.daysOf(id)).map((d) => d.weekday).toSet();
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
    if (_weekdays.isEmpty) return toast(context, 'Выберите хотя бы один день недели');
    final planner = ref.read(plannerRepoProvider);
    await ref.read(referenceRepoProvider).updateSettings(SettingsCompanion(weightRoundingKg: Value(_step)));
    if (_isNew) {
      final id = await planner.createProgram(
        name: name,
        startDate: _start,
        weeksCount: _weeks,
        timeLimitMin: _timeLimit,
        weekdays: _weekdays.toList(),
        deloadWeekNo: _deloadWeek,
        deloadSetsK: _setsK,
        deloadWeightK: _weightK,
        deloadRirAdd: _rirAdd,
      );
      if (mounted) context.pushReplacement('/program/$id');
    } else {
      final id = widget.programId!;
      await planner.updateProgram(
        id,
        ProgramsCompanion(
          name: Value(name),
          timeLimitMin: Value(_timeLimit),
          deloadSetsK: Value(_setsK),
          deloadWeightK: Value(_weightK),
          deloadRirAdd: Value(_rirAdd),
        ),
      );
      await planner.setDeloadWeek(id, _deloadWeek);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? 'Новая программа' : 'Параметры программы')),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'Название')),
                const SizedBox(height: 20),
                Text('Дни недели', style: t.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    for (var d = 1; d <= 7; d++)
                      FilterChip(
                        label: Text(weekdayShort[d - 1]),
                        selected: _weekdays.contains(d),
                        onSelected: _isNew
                            ? (on) => setState(() => on ? _weekdays.add(d) : _weekdays.remove(d))
                            : null,
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Лимит времени на тренировку: $_timeLimit мин', style: t.titleSmall),
                Slider(
                  value: _timeLimit.toDouble(),
                  min: 20,
                  max: 180,
                  divisions: 32,
                  label: '$_timeLimit мин',
                  onChanged: (v) => setState(() => _timeLimit = v.round()),
                ),
                Text('Длина мезоцикла: $_weeks нед.', style: t.titleSmall),
                Slider(
                  value: _weeks.toDouble(),
                  min: 3,
                  max: 12,
                  divisions: 9,
                  label: '$_weeks',
                  onChanged: _isNew
                      ? (v) => setState(() {
                            final wasLast = _deloadWeek == _weeks;
                            _weeks = v.round();
                            if (_deloadWeek != null && (wasLast || _deloadWeek! > _weeks)) _deloadWeek = _weeks;
                          })
                      : null,
                ),
                DropdownButtonFormField<int?>(
                  key: ValueKey('deload-$_deloadWeek-$_weeks'),
                  initialValue: _deloadWeek,
                  decoration: const InputDecoration(labelText: 'Неделя разгрузки'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Нет')),
                    for (var n = 2; n <= _weeks; n++)
                      DropdownMenuItem<int?>(value: n, child: Text(n == _weeks ? 'Неделя $n (последняя)' : 'Неделя $n')),
                  ],
                  onChanged: (v) => setState(() => _deloadWeek = v),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<double>(
                  initialValue: roundingSteps.contains(_step) ? _step : 2.5,
                  decoration: const InputDecoration(labelText: 'Шаг округления веса'),
                  items: [for (final v in roundingSteps) DropdownMenuItem(value: v, child: Text('${formatKg(v)} кг'))],
                  onChanged: (v) => setState(() => _step = v ?? 2.5),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Стартовая дата'),
                  subtitle: Text('${ruDate(_start)} · неделя с ${ruDate(weekStart(_start))}'),
                  trailing: const Icon(Icons.event),
                  enabled: _isNew,
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _start,
                      firstDate: addDays(today(), -365),
                      lastDate: addDays(today(), 365),
                    );
                    if (d != null) setState(() => _start = dateOnly(d));
                  },
                ),
                const Divider(height: 32),
                Text('Разгрузка', style: t.titleMedium),
                const SizedBox(height: 8),
                Text('Подходы × ${_setsK.toStringAsFixed(2).replaceAll('.', ',')} (округление вверх, не меньше 1)'),
                Slider(
                  value: _setsK,
                  min: 0.3,
                  max: 1.0,
                  divisions: 14,
                  onChanged: (v) => setState(() => _setsK = (v * 20).round() / 20),
                ),
                Text('Вес × ${_weightK.toStringAsFixed(2).replaceAll('.', ',')}'),
                Slider(
                  value: _weightK,
                  min: 0.7,
                  max: 1.0,
                  divisions: 30,
                  onChanged: (v) => setState(() => _weightK = (v * 100).round() / 100),
                ),
                Text('Целевой RIR +$_rirAdd'),
                Slider(
                  value: _rirAdd.toDouble(),
                  min: 0,
                  max: 3,
                  divisions: 3,
                  onChanged: (v) => setState(() => _rirAdd = v.round()),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _save, child: Text(_isNew ? 'Создать программу' : 'Сохранить')),
              ],
            ),
    );
  }
}
