/// Готовые программы-заготовки. Чистые данные: названия упражнений совпадают со справочником (seed).
library;

class TemplateExercise {
  const TemplateExercise(this.name, this.sets, this.repsMin, this.repsMax);
  final String name;
  final int sets;
  final int repsMin;
  final int repsMax;
}

class TemplateDay {
  const TemplateDay(this.weekday, this.name, this.exercises);

  /// 1 — понедельник … 7 — воскресенье.
  final int weekday;
  final String name;
  final List<TemplateExercise> exercises;
}

class ProgramTemplate {
  const ProgramTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.weeks,
    required this.days,
  });
  final String id;
  final String name;
  final String description;

  /// Длина цикла; последняя неделя — разгрузочная.
  final int weeks;
  final List<TemplateDay> days;

  int get exercisesCount => days.fold(0, (a, d) => a + d.exercises.length);
}


const programTemplates = <ProgramTemplate>[
  ProgramTemplate(
    id: 'fullbody3',
    name: 'Всё тело, 3 дня',
    description: 'Пн, Ср, Пт. Базовые движения на всё тело в каждой тренировке — для старта и возвращения после перерыва.',
    weeks: 6,
    days: [
      TemplateDay(1, 'Всё тело А', [
        TemplateExercise('Приседания со штангой', 3, 5, 8),
        TemplateExercise('Жим лёжа', 3, 5, 8),
        TemplateExercise('Тяга штанги в наклоне', 3, 8, 10),
        TemplateExercise('Махи гантелями в стороны', 2, 12, 15),
        TemplateExercise('Скручивания', 2, 12, 15),
      ]),
      TemplateDay(3, 'Всё тело Б', [
        TemplateExercise('Становая тяга', 3, 4, 6),
        TemplateExercise('Жим стоя', 3, 6, 8),
        TemplateExercise('Подтягивания', 3, 6, 10),
        TemplateExercise('Сгибания рук со штангой', 2, 10, 12),
        TemplateExercise('Подъём на носки стоя', 2, 12, 15),
      ]),
      TemplateDay(5, 'Всё тело В', [
        TemplateExercise('Жим ногами', 3, 10, 12),
        TemplateExercise('Жим на наклонной скамье', 3, 8, 10),
        TemplateExercise('Тяга верхнего блока', 3, 10, 12),
        TemplateExercise('Разгибания рук на блоке', 2, 10, 12),
        TemplateExercise('Лицевая тяга', 2, 12, 15),
      ]),
    ],
  ),
  ProgramTemplate(
    id: 'upperlower4',
    name: 'Верх / низ, 4 дня',
    description: 'Пн, Вт, Чт, Пт. Каждая группа мышц дважды в неделю: силовой и объёмный день.',
    weeks: 6,
    days: [
      TemplateDay(1, 'Верх: сила', [
        TemplateExercise('Жим лёжа', 4, 5, 8),
        TemplateExercise('Тяга штанги в наклоне', 4, 6, 10),
        TemplateExercise('Жим стоя', 3, 8, 10),
        TemplateExercise('Тяга верхнего блока', 3, 10, 12),
        TemplateExercise('Разгибания рук на блоке', 3, 10, 12),
        TemplateExercise('Сгибания рук со штангой', 3, 10, 12),
      ]),
      TemplateDay(2, 'Низ: сила', [
        TemplateExercise('Приседания со штангой', 4, 5, 8),
        TemplateExercise('Румынская тяга', 3, 8, 10),
        TemplateExercise('Жим ногами', 3, 10, 12),
        TemplateExercise('Сгибания ног лёжа', 3, 10, 12),
        TemplateExercise('Подъём на носки стоя', 3, 12, 15),
      ]),
      TemplateDay(4, 'Верх: объём', [
        TemplateExercise('Жим на наклонной скамье', 4, 8, 10),
        TemplateExercise('Подтягивания', 4, 6, 10),
        TemplateExercise('Жим гантелей сидя', 3, 8, 12),
        TemplateExercise('Тяга горизонтального блока', 3, 10, 12),
        TemplateExercise('Махи гантелями в стороны', 3, 12, 15),
        TemplateExercise('Французский жим', 3, 10, 12),
      ]),
      TemplateDay(5, 'Низ: объём', [
        TemplateExercise('Становая тяга', 3, 4, 6),
        TemplateExercise('Фронтальные приседания', 3, 6, 8),
        TemplateExercise('Разгибания ног в тренажёре', 3, 12, 15),
        TemplateExercise('Ягодичный мост', 3, 8, 12),
        TemplateExercise('Подъём ног в висе', 3, 10, 15),
      ]),
    ],
  ),
  ProgramTemplate(
    id: 'ppl3',
    name: 'Жим / тяга / ноги, 3 дня',
    description: 'Пн, Ср, Пт. Жимовые, тяговые и ноги — по одному дню, больше объёма на группу за тренировку.',
    weeks: 6,
    days: [
      TemplateDay(1, 'Жим', [
        TemplateExercise('Жим лёжа', 4, 6, 8),
        TemplateExercise('Жим стоя', 3, 8, 10),
        TemplateExercise('Отжимания на брусьях', 3, 8, 12),
        TemplateExercise('Махи гантелями в стороны', 3, 12, 15),
        TemplateExercise('Разгибания рук на блоке', 3, 10, 12),
      ]),
      TemplateDay(3, 'Тяга', [
        TemplateExercise('Становая тяга', 3, 4, 6),
        TemplateExercise('Подтягивания', 4, 6, 10),
        TemplateExercise('Тяга штанги в наклоне', 3, 8, 10),
        TemplateExercise('Лицевая тяга', 3, 12, 15),
        TemplateExercise('Сгибания рук со штангой', 3, 10, 12),
      ]),
      TemplateDay(5, 'Ноги', [
        TemplateExercise('Приседания со штангой', 4, 6, 8),
        TemplateExercise('Румынская тяга', 3, 8, 10),
        TemplateExercise('Жим ногами', 3, 10, 12),
        TemplateExercise('Сгибания ног лёжа', 3, 10, 12),
        TemplateExercise('Подъём на носки стоя', 3, 12, 15),
      ]),
    ],
  ),
];
