import 'package:flutter_test/flutter_test.dart';
import 'package:trainlog/domain/plates.dart';

void main() {
  test('100 кг на грифе 20 кг: по 40 кг на сторону = 25 + 15', () {
    final r = platesFor(targetKg: 100)!;
    expect(r.perSide, {25.0: 1, 15.0: 1});
    expect(r.achievedKg, 100);
    expect(r.exact, isTrue);
  });

  test('жадный набор с повторами: 142,5 кг', () {
    final r = platesFor(targetKg: 142.5)!;
    // (142,5 − 20) / 2 = 61,25 → 25 × 2 + 10 + 1,25
    expect(r.perSide, {25.0: 2, 10.0: 1, 1.25: 1});
    expect(r.achievedKg, 142.5);
  });

  test('недостающий мелкий диск: остаток честно показан', () {
    final r = platesFor(targetKg: 101, plates: const [25, 20, 10])!;
    // сторона 40,5 → 25 + 10 = 35, остаётся 5,5 на сторону
    expect(r.perSide, {25.0: 1, 10.0: 1});
    expect(r.remainderKg, closeTo(5.5, 1e-9));
    expect(r.exact, isFalse);
    expect(r.achievedKg, closeTo(90, 1e-9));
  });

  test('текстовая запись набора', () {
    expect(platesLabel(platesFor(targetKg: 142.5)!), '25 × 2 + 10 + 1,25');
    expect(platesLabel(platesFor(targetKg: 20)!), 'только гриф');
  });

  test('только гриф и цель меньше грифа', () {
    expect(platesFor(targetKg: 20)!.perSide, isEmpty);
    expect(platesFor(targetKg: 15), isNull);
  });

  test('другой гриф (15 кг)', () {
    final r = platesFor(targetKg: 60, barKg: 15)!;
    // (60 − 15) / 2 = 22,5 → 20 + 2,5
    expect(r.perSide, {20.0: 1, 2.5: 1});
    expect(r.achievedKg, 60);
  });
}
