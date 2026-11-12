import 'package:flutter_test/flutter_test.dart';
import 'package:trainlog/domain/analytics.dart';
import 'package:trainlog/domain/strength.dart';

SetFact f(int ex, double w, int reps, {SetStatus? st = SetStatus.done, bool warm = false, Map<int, double>? m, bool deload = false}) =>
    SetFact(
      exerciseId: ex,
      isWarmup: warm,
      weightKg: w,
      reps: reps,
      e1rmKg: warm ? null : epley1rm(weight: w, reps: reps, useRir: false),
      status: st,
      isDeloadWeek: deload,
      muscleShares: m ?? const {1: 1.0, 2: 0.5},
    );

void main() {
  test('подход жима = 1 подход на грудь + 0,5 на трицепс; тоннаж с долями', () {
    final a = aggregateWeek([f(10, 100, 5), f(10, 100, 5), f(10, 100, 4, st: SetStatus.minorMiss)]);
    expect(a.byMuscle[1]!.sets, 3);
    expect(a.byMuscle[2]!.sets, 1.5);
    expect(a.byMuscle[1]!.tonnage, 1400);
    expect(a.byMuscle[2]!.tonnage, 700);
    final ex = a.byExercise[10]!;
    expect(ex.workSets, 3);
    expect(ex.tonnage, 1400);
    expect(ex.setsDone, 3);
    expect(ex.bestE1rm, closeTo(116.67, 0.005));
  });

  test('разминка не идёт в аналитику, пропуски не считаются рабочими', () {
    final a = aggregateWeek([
      f(10, 60, 10, warm: true),
      f(10, 100, 5),
      SetFact(exerciseId: 10, isWarmup: false, weightKg: null, reps: null, e1rmKg: null,
          status: SetStatus.skipped, isDeloadWeek: false, muscleShares: const {1: 1.0}),
      f(10, 100, 2, st: SetStatus.partial),
      f(10, 100, 0, st: SetStatus.failed),
    ]);
    final ex = a.byExercise[10]!;
    expect(ex.workSets, 2);
    expect(ex.setsDone, 1);
    expect(ex.setsPartial, 1);
    expect(ex.setsFailed, 1);
    expect(a.byMuscle[1]!.sets, 2);
  });

  test('1ПМ считается отдельно по каждой вариации', () {
    final a = aggregateWeek([f(10, 100, 5), f(11, 80, 5, deload: true)]);
    expect(a.byExercise[10]!.bestE1rm, greaterThan(a.byExercise[11]!.bestE1rm!));
    expect(a.byExercise[11]!.isDeload, isTrue);
    expect(a.byExercise[10]!.isDeload, isFalse);
  });
}
