import 'package:flutter_test/flutter_test.dart';
import 'package:trainlog/domain/strength.dart';

void main() {
  group('Эпли', () {
    test('100 кг × 5 = 116,67', () {
      expect(epley1rm(weight: 100, reps: 5, useRir: false), closeTo(116.67, 0.005));
    });
    test('r = 1 → вес', () {
      expect(epley1rm(weight: 140, reps: 1, useRir: false), 140);
      expect(epley1rm(weight: 140, reps: 1, rir: 0), 140);
    });
    test('r > 12 не учитывается', () {
      expect(epley1rm(weight: 60, reps: 12, useRir: false), closeTo(84, 1e-9));
      expect(epley1rm(weight: 60, reps: 13, useRir: false), isNull);
    });
    test('вариант с RIR: в формулу идёт r + RIR', () {
      expect(epley1rm(weight: 100, reps: 5, rir: 2), closeTo(100 * (1 + 7 / 30), 1e-9));
      expect(epley1rm(weight: 100, reps: 5, rir: 2, useRir: false), closeTo(116.67, 0.005));
      expect(epley1rm(weight: 100, reps: 5), closeTo(116.67, 0.005));
      expect(epley1rm(weight: 100, reps: 11, rir: 2), isNull);
    });
    test('нулевой вес или повторы не считаются', () {
      expect(epley1rm(weight: 0, reps: 5), isNull);
      expect(epley1rm(weight: 100, reps: 0), isNull);
    });
  });

  group('Статус подхода', () {
    test('границы недобора 0, 1, 2, 3, 5, 6', () {
      expect(statusForShortfall(0), SetStatus.done);
      expect(statusForShortfall(1), SetStatus.minorMiss);
      expect(statusForShortfall(2), SetStatus.minorMiss);
      expect(statusForShortfall(3), SetStatus.partial);
      expect(statusForShortfall(5), SetStatus.partial);
      expect(statusForShortfall(6), SetStatus.failed);
    });
    test('перевыполнение — done', () {
      expect(setStatus(plannedRepsMin: 8, actualReps: 10), SetStatus.done);
    });
    test('недобор считается от нижней границы диапазона', () {
      expect(setStatus(plannedRepsMin: 8, actualReps: 8), SetStatus.done);
      expect(setStatus(plannedRepsMin: 8, actualReps: 6), SetStatus.minorMiss);
      expect(setStatus(plannedRepsMin: 8, actualReps: 3), SetStatus.partial);
      expect(setStatus(plannedRepsMin: 8, actualReps: 2), SetStatus.failed);
    });
    test('пропуск и свободная тренировка', () {
      expect(setStatus(plannedRepsMin: 8, actualReps: null, skipped: true), SetStatus.skipped);
      expect(setStatus(plannedRepsMin: null, actualReps: 8), isNull);
    });
    test('флаг «вес снижен»', () {
      expect(isWeightReduced(100, 97.5), isTrue);
      expect(isWeightReduced(100, 100), isFalse);
      expect(isWeightReduced(100, 102.5), isFalse);
      expect(isWeightReduced(null, 100), isFalse);
    });
    test('статус упражнения — худший по подходам', () {
      expect(worstStatus([SetStatus.done, SetStatus.partial, SetStatus.minorMiss]), SetStatus.partial);
      expect(worstStatus([SetStatus.done, SetStatus.failed, SetStatus.skipped]), SetStatus.failed);
      expect(worstStatus([SetStatus.done, SetStatus.skipped]), SetStatus.done);
      expect(worstStatus([SetStatus.skipped, SetStatus.skipped]), SetStatus.skipped);
      expect(worstStatus([]), isNull);
    });
  });
}
