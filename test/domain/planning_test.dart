import 'package:flutter_test/flutter_test.dart';
import 'package:trainlog/domain/dates.dart';
import 'package:trainlog/domain/planning.dart';

void main() {
  group('Округление', () {
    test('вниз до шага', () {
      expect(roundDownToStep(83.7, 2.5), 82.5);
      expect(roundDownToStep(85, 2.5), 85);
      expect(roundDownToStep(84.99, 1.25), 83.75);
      expect(roundDownToStep(57.4, 0.5), 57.0);
    });
    test('до ближайшего шага', () {
      expect(roundToStep(1.5, 2.5), 2.5);
      expect(roundToStep(1.2, 2.5), 0);
      expect(roundToStep(5, 2.5), 5);
    });
  });

  group('Режимы веса', () {
    test('процент от 1ПМ: 70 → 72,5 → 75 → 77,5%', () {
      double? w(double pct) =>
          plannedWeight(mode: LoadMode.percent, workWeekIndex: 0, step: 2.5, percent1rm: pct, e1rm: 120);
      expect(w(70), 82.5); // 84
      expect(w(72.5), 85); // 87
      expect(w(75), 90);
      expect(w(77.5), 92.5); // 93
    });
    test('линейный шаг', () {
      double? w(int i) =>
          plannedWeight(mode: LoadMode.linear, workWeekIndex: i, step: 2.5, startWeight: 60, weeklyStep: 2);
      expect(w(0), 60);
      expect(w(1), 60); // 62 → 60
      expect(w(2), 62.5); // 64 → 62,5
      expect(w(3), 65); // 66 → 65
    });
    test('вручную и без данных', () {
      expect(plannedWeight(mode: LoadMode.manual, workWeekIndex: 0, step: 2.5, manualWeight: 101), 100);
      expect(plannedWeight(mode: LoadMode.percent, workWeekIndex: 0, step: 2.5, percent1rm: 70), isNull);
    });
  });

  group('Разгрузка', () {
    WeekTargets d(int sets, double w, int rir, {double wk = 0.9}) => deloadFrom(
        sets: sets, weightKg: w, targetRir: rir, setsK: 0.5, weightK: wk, rirAdd: 2, step: 2.5);
    test('подходы × 0,5 с округлением вверх, не меньше 1', () {
      expect(d(4, 100, 2).sets, 2);
      expect(d(5, 100, 2).sets, 3);
      expect(d(3, 100, 2).sets, 2);
      expect(d(1, 100, 2).sets, 1);
    });
    test('вес × 0,9 с округлением до шага', () {
      expect(d(4, 100, 2).weightKg, 90);
      expect(d(4, 82.5, 2).weightKg, 72.5); // 74,25
      expect(d(4, 100, 2, wk: 0.85).weightKg, 85);
    });
    test('RIR + 2, не больше 5', () {
      expect(d(4, 100, 2).targetRir, 4);
      expect(d(4, 100, 4).targetRir, 5);
    });
  });

  test('Длительность дня: подходы × (подход + отдых) + разминка', () {
    final sec = dayDurationSec(
      const [DayLoadItem(sets: 4, restSec: 180), DayLoadItem(sets: 3, restSec: 90)],
      setDurationSec: 40,
      warmupMin: 10,
    );
    expect(sec, 4 * 220 + 3 * 130 + 600);
    expect(dayDurationSec(const [], setDurationSec: 40, warmupMin: 10), 0);
  });

  group('Недели', () {
    test('начало недели — понедельник', () {
      expect(ymd(weekStart(DateTime.utc(2026, 11, 12))), '2026-11-09');
      expect(ymd(weekStart(DateTime.utc(2026, 11, 9))), '2026-11-09');
      expect(ymd(weekStart(DateTime.utc(2026, 11, 15))), '2026-11-09');
    });
    test('ближайший понедельник', () {
      expect(ymd(nearestMonday(DateTime.utc(2026, 11, 12))), '2026-11-16');
      expect(ymd(nearestMonday(DateTime.utc(2026, 11, 9))), '2026-11-09');
    });
    test('несколько пропущенных недель закрываются по очереди', () {
      final w = weeksToClose(DateTime.utc(2026, 10, 12), DateTime.utc(2026, 11, 12));
      expect(w.map(ymd).toList(), ['2026-10-19', '2026-10-26', '2026-11-02']);
      expect(weeksToClose(DateTime.utc(2026, 11, 2), DateTime.utc(2026, 11, 12)), isEmpty);
      expect(weeksToClose(null, DateTime.utc(2026, 11, 12)).map(ymd).toList(), ['2026-11-02']);
    });
  });

  test('Формат веса', () {
    expect(formatKg(100), '100');
    expect(formatKg(57.5), '57,5');
    expect(formatKg(61.25), '61,25');
    expect(formatKg(null), '—');
  });
}
