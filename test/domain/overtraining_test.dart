import 'package:flutter_test/flutter_test.dart';
import 'package:trainlog/domain/overtraining.dart';

LoadWeek w(int i,
        {double ton = 10000,
        int done = 20,
        int partial = 0,
        int failed = 0,
        bool deload = false,
        Map<String, double> e1rm = const {'Жим': 100, 'Присед': 140}}) =>
    LoadWeek(
      weekStart: '2026-09-${(i + 1).toString().padLeft(2, '0')}',
      tonnageKg: ton,
      setsDone: done,
      setsPartial: partial,
      setsFailed: failed,
      isDeload: deload,
      e1rmByExercise: e1rm,
    );

const rest = LoadWeek(weekStart: '2026-09-00');

Set<String> codes(List<LoadWeek> weeks, [List<MuscleLoad> muscles = const []]) =>
    overtrainingSignals(weeks, muscles).map((s) => s.code).toSet();

void main() {
  test('спокойная история без признаков', () {
    final weeks = [w(0), w(1), w(2, deload: true), w(3), w(4)];
    expect(codes(weeks), isEmpty);
    expect(overtrainingWarning(overtrainingSignals(weeks, const [])), isFalse);
  });

  test('1ПМ падает две рабочие недели подряд у большинства упражнений', () {
    final weeks = [
      w(0, e1rm: {'Жим': 100, 'Присед': 140, 'Тяга': 160}),
      w(1, e1rm: {'Жим': 98, 'Присед': 138, 'Тяга': 162}),
      w(2, deload: true, e1rm: {'Жим': 80}), // разгрузка не участвует
      w(3, e1rm: {'Жим': 96, 'Присед': 135, 'Тяга': 161}),
    ];
    final s = overtrainingSignals(weeks, const []);
    expect(s.map((x) => x.code), ['e1rm_drop']);
    expect(s.single.text, contains('2 из 3'));
    // Меньше половины — не признак.
    expect(
        codes([
          w(0, e1rm: {'Жим': 100, 'Присед': 140, 'Тяга': 160}),
          w(1, e1rm: {'Жим': 98, 'Присед': 141, 'Тяга': 162}),
          w(2, e1rm: {'Жим': 96, 'Присед': 142, 'Тяга': 161}),
        ]),
        isEmpty);
  });

  test('недоборы ≥ 30% две рабочие недели подряд', () {
    expect(codes([w(0), w(1, done: 14, partial: 4, failed: 2), w(2, done: 13, partial: 7)]), {'bad_sets'});
    expect(codes([w(0), w(1, done: 14, partial: 4, failed: 2), w(2, done: 16, partial: 4)]), isEmpty);
  });

  test('скачок тоннажа ≥ 1,3 к среднему за 4 недели', () {
    final weeks = [w(0), w(1), w(2), w(3), w(4, ton: 13500)];
    final s = overtrainingSignals(weeks, const []);
    expect(s.map((x) => x.code), ['load_spike']);
    expect(s.single.text, contains('1,4 раза'));
    expect(codes([w(0), w(1), w(2), w(3), w(4, ton: 12500)]), isEmpty);
    // Мало истории — не оценивается.
    expect(codes([w(0), w(1), w(2, ton: 30000)]), isEmpty);
  });

  test('объём выше коридора на 20%', () {
    const muscles = [
      MuscleLoad(name: 'Грудь', sets: 25, targetMax: 20),
      MuscleLoad(name: 'Спина', sets: 23.5, targetMax: 20),
    ];
    final s = overtrainingSignals([w(0)], muscles);
    expect(s.single.code, 'volume_over');
    expect(s.single.text, contains('Грудь — 25 подх.'));
    expect(s.single.text, isNot(contains('Спина')));
  });

  test('6 недель подряд без разгрузки; неделя отдыха обнуляет счёт', () {
    expect(codes([for (var i = 0; i < 6; i++) w(i)]), {'no_deload'});
    expect(codes([for (var i = 0; i < 5; i++) w(i)]), isEmpty);
    expect(codes([w(0), w(1), rest, w(3), w(4), w(5), w(6), w(7)]), isEmpty);
    expect(codes([w(0), w(1, deload: true), w(2), w(3), w(4), w(5), w(6)]), isEmpty);
  });

  test('предупреждение — от двух признаков', () {
    final weeks = [for (var i = 0; i < 6; i++) w(i), w(6, ton: 14000)];
    final s = overtrainingSignals(weeks, const []);
    expect(s.map((x) => x.code).toSet(), {'load_spike', 'no_deload'});
    expect(overtrainingWarning(s), isTrue);
    expect(overtrainingWarning(s.take(1).toList()), isFalse);
  });
}
