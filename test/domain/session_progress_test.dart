import 'package:flutter_test/flutter_test.dart';
import 'package:trainlog/domain/strength.dart';

SetBrief s(double? w, int? reps, {bool warmup = false, bool skipped = false}) =>
    (isWarmup: warmup, weightKg: w, reps: reps, skipped: skipped);

void main() {
  test('ход тренировки: разминка не считается, пропуск закрывает подход', () {
    final p = sessionProgress([
      s(40, 10, warmup: true),
      s(100, 8),
      s(100, 7),
      s(null, null, skipped: true),
      s(null, null),
    ]);
    expect(p.closed, 3);
    expect(p.total, 4);
    expect(p.tonnageKg, 1500);
    expect(p.share, 0.75);
    expect(p.complete, isFalse);
    expect(sessionProgress(const []).share, 0);
    expect(sessionProgress([s(50, 5)]).complete, isTrue);
  });

  test('краткая запись подходов группирует повторы по весу', () {
    expect(setsSummary([s(40, 10, warmup: true), s(100, 8), s(100, 8), s(100, 7), s(102.5, 6)]), '100 × 8, 8, 7 · 102,5 × 6');
    expect(setsSummary([s(0, 12), s(0, 10)]), '12, 10');
    expect(setsSummary([s(null, null, skipped: true)]), '');
  });

  test('следующий подход: первый невыполненный рабочий по порядку упражнений', () {
    PendingSet p(bool closed, {double? w, int? r, bool warmup = false}) =>
        (isWarmup: warmup, closed: closed, weightKg: w, reps: r);
    final list = [
      (name: 'Жим лёжа', sets: [p(false, warmup: true), p(true, w: 100, r: 8), p(true, w: 100, r: 8)]),
      (name: 'Присед', sets: [p(true, w: 120, r: 5), p(false, w: 120, r: 5), p(false, w: 120, r: 5)]),
    ];
    final n = nextSet(list)!;
    expect(n.exercise, 'Присед');
    expect(n.setNo, 2);
    expect(n.setsTotal, 3);
    expect(n.weightKg, 120);
    expect(n.reps, 5);
    expect(nextSet([(name: 'Жим', sets: [p(true)])]), isNull);
    expect(nextSet(const []), isNull);
  });
}
