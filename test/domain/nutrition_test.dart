import 'package:flutter_test/flutter_test.dart';
import 'package:trainlog/domain/nutrition.dart';

void main() {
  group('BMR (Миффлин — Сан Жеор)', () {
    test('мужчина: 10·80 + 6,25·180 − 5·30 + 5 = 1780', () {
      expect(bmrMifflin(sex: 'm', weightKg: 80, heightCm: 180, ageYears: 30), 1780);
    });
    test('женщина: 10·60 + 6,25·165 − 5·28 − 161 = 1330,25', () {
      expect(bmrMifflin(sex: 'f', weightKg: 60, heightCm: 165, ageYears: 28), 1330.25);
    });
    test('возраст по дате рождения', () {
      expect(ageOn(DateTime.utc(1996, 11, 13), DateTime.utc(2026, 11, 12)), 29);
      expect(ageOn(DateTime.utc(1996, 11, 12), DateTime.utc(2026, 11, 12)), 30);
    });
  });

  group('Целевая норма', () {
    const bmr = 1780.0;
    const tdee = 1780 * 1.55; // 2759
    MacroTargets t(String goal, double pct, {double protein = 1.8, double tdeeV = tdee}) => macroTargets(
        bmr: bmr, tdee: tdeeV, adjust: goalAdjust(goal, pct), weightKg: 80, proteinPerKg: protein, fatPerKgMin: 0.8);
    test('набор +10%', () {
      final r = t('gain', 10);
      expect(r.kcal, closeTo(3034.9, 1e-6));
      expect(r.proteinG, 144);
      expect(r.fatG, 64);
      expect(r.carbsG, closeTo((3034.9 - 144 * 4 - 64 * 9) / 4, 1e-6));
    });
    test('снижение −15%', () {
      expect(t('cut', 15, protein: 2.2).kcal, closeTo(2345.15, 1e-6));
      expect(t('cut', 15, protein: 2.2).proteinG, 176);
    });
    test('удержание: поправка 0', () {
      expect(t('maintain', 10).kcal, closeTo(2759, 1e-6));
    });
    test('калории не опускаются ниже BMR', () {
      expect(t('cut', 20, tdeeV: 1780 * 1.2).kcal, bmr); // 2136 × 0,8 = 1708,8 < 1780
    });
    test('углеводы не уходят в минус', () {
      final r = macroTargets(bmr: 1000, tdee: 1000, adjust: 0, weightKg: 100, proteinPerKg: 2.2, fatPerKgMin: 1);
      expect(r.carbsG, 0);
    });
  });

  group('Тренд веса', () {
    test('EMA с α = 0,1', () {
      final t = emaTrend({DateTime.utc(2026, 11, 1): 80, DateTime.utc(2026, 11, 2): 81, DateTime.utc(2026, 11, 3): 79});
      expect(t.map((p) => p.trendKg).toList(), [80, closeTo(80.1, 1e-9), closeTo(79.99, 1e-9)]);
    });
    test('пропущенные дни интерполируются', () {
      final t = emaTrend({DateTime.utc(2026, 11, 1): 80, DateTime.utc(2026, 11, 4): 83});
      expect(t.length, 4);
      expect(t.map((p) => p.weightKg).toList(), [80, 81, 82, 83]);
      expect(t.map((p) => p.measured).toList(), [true, false, false, true]);
      expect(t.last.trendKg, closeTo(80 + 0.1 + 0.19 + 0.271, 1e-9));
    });
    test('пустой ввод', () => expect(emaTrend({}), isEmpty));
  });

  group('Адаптивный TDEE', () {
    AdaptiveTdee run({int food = 14, int weighIns = 10, double kcal = 2500, double d = 0, double old = 2700}) => adaptiveTdee(
        oldTdee: old, dailyKcal: List.filled(food, kcal), weighIns: weighIns, trendStartKg: 80, trendEndKg: 80 + d, windowDays: 14);
    test('формула и сглаживание 0,7 / 0,3', () {
      // Вес −0,28 кг за 14 дней → расход 2500 + 0,28 × 7700 / 14 = 2654; 0,7 × 2700 + 0,3 × 2654 = 2686,2
      final r = run(d: -0.28);
      expect(r.valid, isTrue);
      expect(r.observed, closeTo(2654, 1e-6));
      expect(r.tdee, closeTo(2686.2, 1e-6));
    });
    test('невалидное окно оставляет прежнее значение', () {
      expect(run(food: 9).valid, isFalse);
      expect(run(food: 9).tdee, 2700);
      expect(run(weighIns: 7).tdee, 2700);
      expect(run(food: 10, weighIns: 8).valid, isTrue);
    });
    test('ограничение ±150 ккал за неделю', () {
      expect(run(kcal: 4000, d: 1).tdee, 2850); // наблюдаемый 3450 → 2925 → ограничено
      expect(run(kcal: 1500, d: 0).tdee, 2550); // 0,7 × 2700 + 0,3 × 1500 = 2340 → ограничено
    });
  });

  group('Open Food Facts', () {
    test('поля карточки', () {
      final p = parseOffProduct({
        'code': '4600000000001',
        'product_name': 'Cottage cheese',
        'product_name_ru': 'Творог 5%',
        'brands': 'Домик',
        'nutriments': {'energy-kcal_100g': 121, 'proteins_100g': '17.2', 'fat_100g': 5, 'carbohydrates_100g': 1.8},
      })!;
      expect(p.name, 'Творог 5%');
      expect(p.brand, 'Домик');
      expect([p.kcal100, p.protein100, p.fat100, p.carbs100], [121, 17.2, 5, 1.8]);
    });
    test('карточка без калорий или названия не импортируется', () {
      expect(parseOffProduct({'code': '1', 'product_name': 'X', 'nutriments': {'proteins_100g': 10}}), isNull);
      expect(parseOffProduct({'code': '1', 'product_name': '', 'nutriments': {'energy-kcal_100g': 10}}), isNull);
      expect(parseOffProduct({'code': '1', 'product_name': 'X'}), isNull);
    });
  });

  test('порция: КБЖУ по граммам', () {
    final p = portion(grams: 150, kcal100: 120, protein100: 16, fat100: 5, carbs100: 2);
    expect([p.kcal, p.protein, p.fat, p.carbs], [180, 24, 7.5, 3]);
  });
}
