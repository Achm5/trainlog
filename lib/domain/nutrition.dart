/// Расчёты питания (раздел 6 ТЗ). Чистые функции.
library;

import 'dates.dart';

/// Базовый обмен по Миффлину — Сан Жеору: 10m + 6,25h − 5a + s (s = +5 муж., −161 жен.).
double bmrMifflin({required String sex, required double weightKg, required double heightCm, required int ageYears}) =>
    10 * weightKg + 6.25 * heightCm - 5 * ageYears + (sex == 'f' ? -161 : 5);

int ageOn(DateTime birthDate, DateTime on) {
  var age = on.year - birthDate.year;
  if (on.month < birthDate.month || (on.month == birthDate.month && on.day < birthDate.day)) age--;
  return age;
}

final activityLevels = <double, String>{
  1.2: 'Сидячий образ жизни',
  1.375: '1–3 тренировки в неделю',
  1.55: '3–5 тренировок',
  1.725: '6–7 тренировок',
  1.9: 'Физическая работа + тренировки',
};

const goalLabels = {'gain': 'Набор', 'cut': 'Снижение жира', 'maintain': 'Удержание'};

/// Поправка на цель g: набор +pct%, сухая масса −pct%, удержание 0.
double goalAdjust(String goal, double pct) => switch (goal) {
      'gain' => pct.abs() / 100,
      'cut' => -pct.abs() / 100,
      _ => 0,
    };

/// Значения по умолчанию при смене цели: поправка, % и белок, г/кг.
({double adjustPct, double proteinPerKg}) goalDefaults(String goal) => switch (goal) {
      'gain' => (adjustPct: 10, proteinPerKg: 1.8),
      'cut' => (adjustPct: 15, proteinPerKg: 2.2),
      _ => (adjustPct: 0, proteinPerKg: 1.8),
    };

class MacroTargets {
  const MacroTargets({required this.kcal, required this.proteinG, required this.fatG, required this.carbsG});
  final double kcal;
  final double proteinG;
  final double fatG;
  final double carbsG;
}

/// Целевая норма: Target = TDEE × (1 + g), не ниже BMR. Белок и жир — г/кг, углеводы — остаток калорий.
MacroTargets macroTargets({
  required double bmr,
  required double tdee,
  required double adjust,
  required double weightKg,
  required double proteinPerKg,
  required double fatPerKgMin,
}) {
  var kcal = tdee * (1 + adjust);
  if (kcal < bmr) kcal = bmr;
  final protein = proteinPerKg * weightKg;
  final fat = fatPerKgMin * weightKg;
  final carbs = (kcal - protein * 4 - fat * 9) / 4;
  return MacroTargets(kcal: kcal, proteinG: protein, fatG: fat, carbsG: carbs < 0 ? 0 : carbs);
}

class TrendPoint {
  const TrendPoint(this.date, this.weightKg, this.trendKg, {required this.measured});
  final DateTime date;
  final double weightKg;
  final double trendKg;
  final bool measured;
}

/// Тренд веса: trend_t = trend_{t−1} + α × (вес_t − trend_{t−1}).
/// Пропущенные дни между взвешиваниями линейно интерполируются.
List<TrendPoint> emaTrend(Map<DateTime, double> weights, {double alpha = 0.1}) {
  if (weights.isEmpty) return const [];
  final days = weights.keys.map(dateOnly).toList()..sort();
  final byDay = {for (final e in weights.entries) dateOnly(e.key): e.value};
  final out = <TrendPoint>[];
  var trend = byDay[days.first]!;
  for (var i = 0; i < days.length; i++) {
    final d = days[i];
    final w = byDay[d]!;
    if (i > 0) {
      final prev = days[i - 1];
      final gap = daysBetween(prev, d);
      final wPrev = byDay[prev]!;
      for (var k = 1; k < gap; k++) {
        final wi = wPrev + (w - wPrev) * k / gap;
        trend += alpha * (wi - trend);
        out.add(TrendPoint(addDays(prev, k), wi, trend, measured: false));
      }
      trend += alpha * (w - trend);
    }
    out.add(TrendPoint(d, w, trend, measured: true));
  }
  return out;
}

class AdaptiveTdee {
  const AdaptiveTdee({required this.valid, required this.tdee, this.observed, required this.foodDays, required this.weighIns});
  final bool valid;
  final double tdee;
  final double? observed;
  final int foodDays;
  final int weighIns;
}

/// Адаптивный расход (раздел 6.2): TDEE_obs = средние ккал − (Δтренда × ккал/кг) / N дней;
/// TDEE_new = 0,7 × TDEE_old + 0,3 × TDEE_obs, изменение за неделю не больше ±150 ккал.
/// Окно валидно при ≥ 10 днях с рационом и ≥ 8 взвешиваниях, иначе остаётся прежний TDEE.
AdaptiveTdee adaptiveTdee({
  required double oldTdee,
  required List<double> dailyKcal,
  required int weighIns,
  required double trendStartKg,
  required double trendEndKg,
  required int windowDays,
  double kcalPerKg = 7700,
  int minFoodDays = 10,
  int minWeighIns = 8,
  double keepOld = 0.7,
  double maxDelta = 150,
}) {
  if (dailyKcal.length < minFoodDays || weighIns < minWeighIns || windowDays <= 0) {
    return AdaptiveTdee(valid: false, tdee: oldTdee, foodDays: dailyKcal.length, weighIns: weighIns);
  }
  final meanIn = dailyKcal.reduce((a, b) => a + b) / dailyKcal.length;
  final observed = meanIn - (trendEndKg - trendStartKg) * kcalPerKg / windowDays;
  var next = keepOld * oldTdee + (1 - keepOld) * observed;
  if (next > oldTdee + maxDelta) next = oldTdee + maxDelta;
  if (next < oldTdee - maxDelta) next = oldTdee - maxDelta;
  return AdaptiveTdee(valid: true, tdee: next, observed: observed, foodDays: dailyKcal.length, weighIns: weighIns);
}

/// Дневная норма воды, мл. Если известен суточный расход — 1 мл на 1 ккал расхода
/// (он уже учитывает вес, рост, пол, возраст и активность). Иначе — по весу:
/// 35 мл/кг для мужчин, 31 мл/кг для женщин, после 55 лет — 30 мл/кг. Округление до 50 мл.
int waterTargetMl({double? tdee, required double weightKg, required String sex, int? ageYears}) {
  final perKg = (ageYears ?? 0) >= 55 ? 30.0 : (sex == 'f' ? 31.0 : 35.0);
  final ml = tdee != null && tdee > 0 ? tdee : weightKg * perKg;
  return (ml / 50).round() * 50;
}

const mealOrder = ['breakfast', 'lunch', 'dinner', 'snack'];
const mealLabels = {'breakfast': 'Завтрак', 'lunch': 'Обед', 'dinner': 'Ужин', 'snack': 'Перекус'};

/// КБЖУ порции по значениям на 100 г.
({double kcal, double protein, double fat, double carbs}) portion({
  required double grams,
  required double kcal100,
  required double protein100,
  required double fat100,
  required double carbs100,
}) =>
    (kcal: kcal100 * grams / 100, protein: protein100 * grams / 100, fat: fat100 * grams / 100, carbs: carbs100 * grams / 100);

/// Продукт из карточки Open Food Facts. null — карточка без названия или без калорий (не импортируется).
class OffProduct {
  const OffProduct({
    required this.code,
    required this.name,
    this.brand,
    required this.kcal100,
    required this.protein100,
    required this.fat100,
    required this.carbs100,
  });
  final String code;
  final String name;
  final String? brand;
  final double kcal100;
  final double protein100;
  final double fat100;
  final double carbs100;
}

double? _num(dynamic v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v.replaceAll(',', '.')) : null);

OffProduct? parseOffProduct(Map<String, dynamic> p) {
  final code = (p['code'] ?? p['_id'] ?? '').toString();
  final nameRu = (p['product_name_ru'] ?? '').toString().trim();
  final name = nameRu.isNotEmpty ? nameRu : (p['product_name'] ?? '').toString().trim();
  final n = p['nutriments'];
  if (code.isEmpty || name.isEmpty || n is! Map) return null;
  final kcal = _num(n['energy-kcal_100g']);
  if (kcal == null) return null;
  final brand = (p['brands'] ?? '').toString().trim();
  return OffProduct(
    code: code,
    name: name,
    brand: brand.isEmpty ? null : brand,
    kcal100: kcal,
    protein100: _num(n['proteins_100g']) ?? 0,
    fat100: _num(n['fat_100g']) ?? 0,
    carbs100: _num(n['carbohydrates_100g']) ?? 0,
  );
}

class RecipeIngredient {
  const RecipeIngredient({
    required this.grams,
    required this.kcal100,
    required this.protein100,
    required this.fat100,
    required this.carbs100,
  });
  final double grams;
  final double kcal100;
  final double protein100;
  final double fat100;
  final double carbs100;
}

/// КБЖУ рецепта на 100 г: сумма по ингредиентам, делённая на общий вес.
({double kcal, double protein, double fat, double carbs, double totalGrams}) recipePer100(Iterable<RecipeIngredient> items) {
  var grams = 0.0, kcal = 0.0, protein = 0.0, fat = 0.0, carbs = 0.0;
  for (final i in items) {
    grams += i.grams;
    kcal += i.kcal100 * i.grams / 100;
    protein += i.protein100 * i.grams / 100;
    fat += i.fat100 * i.grams / 100;
    carbs += i.carbs100 * i.grams / 100;
  }
  if (grams <= 0) return (kcal: 0, protein: 0, fat: 0, carbs: 0, totalGrams: 0);
  final k = 100 / grams;
  return (kcal: kcal * k, protein: protein * k, fat: fat * k, carbs: carbs * k, totalGrams: grams);
}
