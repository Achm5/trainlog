import 'dart:convert';

import 'package:drift/drift.dart';

import 'database.dart';

/// Сид-данные первого запуска: настройки, группы мышц, оборудование,
/// упражнения с вариациями и долями групп мышц, правила движка рекомендаций.

const _muscles = <(String, int, int)>[
  ('Грудь', 10, 20),
  ('Спина', 10, 20),
  ('Квадрицепсы', 8, 18),
  ('Бицепс бедра', 6, 16),
  ('Ягодицы', 4, 12),
  ('Передняя дельта', 4, 10),
  ('Средняя дельта', 8, 20),
  ('Задняя дельта', 6, 16),
  ('Бицепс', 8, 18),
  ('Трицепс', 6, 16),
  ('Икры', 6, 14),
  ('Пресс', 6, 16),
  ('Трапеции', 4, 12),
  ('Разгибатели спины', 4, 10),
  ('Предплечья', 2, 10),
];

const _equipment = ['Штанга', 'Гантели', 'Тренажёр', 'Блок', 'Турник', 'Собственный вес'];

class _Ex {
  const _Ex(this.name, this.kind, this.equipment, this.muscles, [this.variations = const []]);
  final String name;
  final String kind;
  final String equipment;
  final Map<String, double> muscles;
  final List<_Ex> variations;
}

const _c = 'compound';
const _i = 'isolation';

const _bench = {'Грудь': 1.0, 'Трицепс': 0.5, 'Передняя дельта': 0.5};
const _squat = {'Квадрицепсы': 1.0, 'Ягодицы': 0.5, 'Разгибатели спины': 0.25};
const _dead = {'Бицепс бедра': 1.0, 'Ягодицы': 0.5, 'Разгибатели спины': 0.5, 'Трапеции': 0.25};
const _ohp = {'Передняя дельта': 1.0, 'Средняя дельта': 0.5, 'Трицепс': 0.5};
const _row = {'Спина': 1.0, 'Бицепс': 0.5, 'Задняя дельта': 0.5};
const _pull = {'Спина': 1.0, 'Бицепс': 0.5};

const _exercises = <_Ex>[
  _Ex('Жим лёжа', _c, 'Штанга', _bench, [
    _Ex('Жим лёжа с паузой', _c, 'Штанга', _bench),
    _Ex('Жим лёжа узким хватом', _c, 'Штанга', {'Трицепс': 1.0, 'Грудь': 0.5, 'Передняя дельта': 0.5}),
    _Ex('Жим на наклонной скамье', _c, 'Штанга', {'Грудь': 1.0, 'Передняя дельта': 0.5, 'Трицепс': 0.5}),
    _Ex('Жим гантелей лёжа', _c, 'Гантели', _bench),
  ]),
  _Ex('Приседания со штангой', _c, 'Штанга', _squat, [
    _Ex('Фронтальные приседания', _c, 'Штанга', _squat),
    _Ex('Приседания с паузой', _c, 'Штанга', _squat),
    _Ex('Приседания на бокс', _c, 'Штанга', _squat),
  ]),
  _Ex('Становая тяга', _c, 'Штанга', _dead, [
    _Ex('Румынская тяга', _c, 'Штанга', {'Бицепс бедра': 1.0, 'Ягодицы': 0.5, 'Разгибатели спины': 0.5}),
    _Ex('Становая тяга сумо', _c, 'Штанга', {'Ягодицы': 1.0, 'Бицепс бедра': 0.5, 'Квадрицепсы': 0.5, 'Разгибатели спины': 0.5}),
    _Ex('Тяга с плинтов', _c, 'Штанга', _dead),
  ]),
  _Ex('Жим стоя', _c, 'Штанга', _ohp, [
    _Ex('Жим гантелей сидя', _c, 'Гантели', _ohp),
    _Ex('Жимовой швунг', _c, 'Штанга', _ohp),
  ]),
  _Ex('Тяга штанги в наклоне', _c, 'Штанга', _row, [
    _Ex('Тяга гантели в наклоне', _c, 'Гантели', _row),
    _Ex('Тяга Т-грифа', _c, 'Штанга', _row),
    _Ex('Тяга горизонтального блока', _c, 'Блок', _row),
  ]),
  _Ex('Подтягивания', _c, 'Турник', _pull, [
    _Ex('Подтягивания обратным хватом', _c, 'Турник', {'Спина': 1.0, 'Бицепс': 0.75}),
    _Ex('Подтягивания с отягощением', _c, 'Турник', _pull),
    _Ex('Тяга верхнего блока', _c, 'Блок', _pull),
  ]),
  _Ex('Жим ногами', _c, 'Тренажёр', {'Квадрицепсы': 1.0, 'Ягодицы': 0.5}),
  _Ex('Отжимания на брусьях', _c, 'Собственный вес', {'Грудь': 1.0, 'Трицепс': 0.75, 'Передняя дельта': 0.5}),
  _Ex('Сгибания рук со штангой', _i, 'Штанга', {'Бицепс': 1.0, 'Предплечья': 0.25}),
  _Ex('Сгибания рук с гантелями «молот»', _i, 'Гантели', {'Бицепс': 1.0, 'Предплечья': 0.5}),
  _Ex('Сгибания рук на скамье Скотта', _i, 'Штанга', {'Бицепс': 1.0}),
  _Ex('Разгибания рук на блоке', _i, 'Блок', {'Трицепс': 1.0}),
  _Ex('Французский жим', _i, 'Штанга', {'Трицепс': 1.0}),
  _Ex('Махи гантелями в стороны', _i, 'Гантели', {'Средняя дельта': 1.0}),
  _Ex('Махи гантелями в наклоне', _i, 'Гантели', {'Задняя дельта': 1.0}),
  _Ex('Обратные разведения в тренажёре', _i, 'Тренажёр', {'Задняя дельта': 1.0, 'Трапеции': 0.25}),
  _Ex('Лицевая тяга', _i, 'Блок', {'Задняя дельта': 1.0, 'Трапеции': 0.5}),
  _Ex('Разведение гантелей лёжа', _i, 'Гантели', {'Грудь': 1.0}),
  _Ex('Сведение рук в кроссовере', _i, 'Блок', {'Грудь': 1.0}),
  _Ex('Разгибания ног в тренажёре', _i, 'Тренажёр', {'Квадрицепсы': 1.0}),
  _Ex('Сгибания ног лёжа', _i, 'Тренажёр', {'Бицепс бедра': 1.0}),
  _Ex('Ягодичный мост', _i, 'Штанга', {'Ягодицы': 1.0, 'Бицепс бедра': 0.5}),
  _Ex('Подъём на носки стоя', _i, 'Тренажёр', {'Икры': 1.0}),
  _Ex('Подъём на носки сидя', _i, 'Тренажёр', {'Икры': 1.0}),
  _Ex('Скручивания', _i, 'Собственный вес', {'Пресс': 1.0}),
  _Ex('Подъём ног в висе', _i, 'Турник', {'Пресс': 1.0}),
  _Ex('Шраги со штангой', _i, 'Штанга', {'Трапеции': 1.0}),
  _Ex('Гиперэкстензия', _i, 'Тренажёр', {'Разгибатели спины': 1.0, 'Ягодицы': 0.5, 'Бицепс бедра': 0.5}),
  _Ex('Сгибания запястий со штангой', _i, 'Штанга', {'Предплечья': 1.0}),
];

/// Базовые правила раздела 5.2 и автопрогрессия (схема v4). Пороги лежат в JSON и меняются без релиза.
final seedRules = <RulesCompanion>[
  RulesCompanion.insert(
    code: 'TWO_RED_IN_ROW',
    name: 'Два провала подряд',
    trigger: 'session_completed',
    scope: 'exercise',
    condition: jsonEncode({'type': 'last_sessions_status', 'sessions': 2, 'status': 'failed'}),
    action: jsonEncode({
      'type': 'reduce_weight',
      'pct_default': 0.025,
      'pct_severe': 0.05,
      'severe_shortfall': 6,
      'min_step_kg': 2.5,
    }),
    priority: const Value(100),
    cooldownDays: const Value(7),
  ),
  RulesCompanion.insert(
    code: 'E1RM_PLATEAU',
    name: 'Плато расчётного 1ПМ',
    trigger: 'week_closed',
    scope: 'exercise',
    condition: jsonEncode({'type': 'e1rm_plateau', 'weeks': 3, 'min_growth_pct': 1.0, 'exclude_deload': true}),
    action: jsonEncode({
      'type': 'choice',
      'options': [
        {'type': 'change_variation'},
        {'type': 'add_sets', 'sets': 1},
      ],
    }),
    priority: const Value(50),
    cooldownDays: const Value(21),
  ),
  RulesCompanion.insert(
    code: 'EARLY_DELOAD',
    name: 'Досрочная разгрузка',
    trigger: 'week_closed',
    scope: 'program',
    condition: jsonEncode({
      'type': 'stall',
      'no_growth_weeks': 2,
      'compound_share': 0.5,
      'min_growth_pct': 1.0,
      'bad_sets_share': 0.4,
    }),
    action: jsonEncode({'type': 'early_deload'}),
    priority: const Value(80),
    cooldownDays: const Value(28),
  ),
  RulesCompanion.insert(
    code: 'REPS_CUT',
    name: 'Снизить повторы',
    trigger: 'session_completed',
    scope: 'exercise',
    condition: jsonEncode({'type': 'last_sessions_status', 'sessions': 2, 'status': 'partial'}),
    action: jsonEncode({'type': 'reduce_reps', 'reps': 2, 'min_reps': 1}),
    priority: const Value(90),
    cooldownDays: const Value(14),
  ),
  RulesCompanion.insert(
    code: 'AUTO_PROGRESSION',
    name: 'Автопрогрессия: прибавить вес',
    trigger: 'session_completed',
    scope: 'exercise',
    condition: jsonEncode({'type': 'progression', 'sessions': 2, 'rir_margin': 1}),
    action: jsonEncode({'type': 'increase_weight', 'pct': 0.025, 'min_step_kg': 2.5}),
    priority: const Value(60),
    cooldownDays: const Value(14),
  ),
];

/// Добавляет правила из [seedRules], которых нет в базе (по коду). Пользовательские правки не трогает.
Future<void> ensureSeedRules(AppDatabase db) async {
  final have = {for (final r in await db.select(db.rules).get()) r.code};
  for (final r in seedRules) {
    if (!have.contains(r.code.value)) await db.into(db.rules).insert(r);
  }
}

Future<void> seedDatabase(AppDatabase db) async {
  await db.into(db.settings).insert(
        SettingsCompanion.insert(id: const Value(1), timezone: Value(DateTime.now().timeZoneName)),
      );

  final muscleIds = <String, int>{};
  for (final (name, min, max) in _muscles) {
    muscleIds[name] = await db.into(db.muscleGroups).insert(
          MuscleGroupsCompanion.insert(name: name, targetSetsMin: Value(min), targetSetsMax: Value(max)),
        );
  }

  final equipmentIds = <String, int>{};
  for (final name in _equipment) {
    equipmentIds[name] = await db.into(db.equipment).insert(EquipmentCompanion.insert(name: name));
  }

  Future<int> insertExercise(_Ex e, int? baseId) async {
    final id = await db.into(db.exercises).insert(
          ExercisesCompanion.insert(
            name: e.name,
            kind: e.kind,
            baseExerciseId: Value(baseId),
            equipmentId: Value(equipmentIds[e.equipment]),
          ),
        );
    for (final m in e.muscles.entries) {
      await db.into(db.exerciseMuscles).insert(
            ExerciseMusclesCompanion.insert(exerciseId: id, muscleGroupId: muscleIds[m.key]!, share: m.value),
          );
    }
    return id;
  }

  for (final e in _exercises) {
    final baseId = await insertExercise(e, null);
    for (final v in e.variations) {
      await insertExercise(v, baseId);
    }
  }

  for (final r in seedRules) {
    await db.into(db.rules).insert(r);
  }
}
