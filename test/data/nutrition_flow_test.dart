import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:trainlog/data/database.dart';
import 'package:trainlog/data/nutrition_repo.dart';
import 'package:trainlog/domain/nutrition.dart';

void main() {
  late AppDatabase db;
  late NutritionRepo repo;
  setUp(() {
    db = AppDatabase.memory();
    repo = NutritionRepo(db);
  });
  tearDown(() => db.close());

  Future<void> profile({String goal = 'maintain', double pct = 0}) =>
      (db.update(db.settings)).write(SettingsCompanion(
        sex: const Value('m'),
        birthDate: const Value('1996-11-12'),
        heightCm: const Value(180),
        activityK: const Value(1.55),
        goal: Value(goal),
        goalAdjustPct: Value(pct),
        proteinGPerKg: const Value(1.8),
      ));

  test('вес и тренд: EMA сохраняется в trend_kg, правка пересчитывает', () async {
    await repo.setWeight(DateTime.utc(2026, 11, 1), 80);
    await repo.setWeight(DateTime.utc(2026, 11, 3), 82);
    var logs = await repo.watchWeights().first;
    expect(logs.map((l) => l.trendKg).toList(), [80, closeTo(80.29, 1e-9)]); // 81 → 80,1; 82 → 80,29
    await repo.setWeight(DateTime.utc(2026, 11, 2), 80);
    logs = await repo.watchWeights().first;
    expect(logs.last.trendKg, closeTo(80.2, 1e-9));
    await repo.setWeight(DateTime.utc(2026, 11, 2), null);
    expect((await repo.watchWeights().first).length, 2);
  });

  test('формульная норма: без профиля не считается, с профилем сохраняется в nutrition_targets', () async {
    final day = DateTime.utc(2026, 11, 12);
    await repo.setWeight(day, 80);
    expect(await repo.recalcFormulaTarget(on: day), isFalse); // профиль не заполнен
    expect(await db.select(db.nutritionTargets).get(), isEmpty);
    await profile(goal: 'gain', pct: 10);
    expect(await repo.recalcFormulaTarget(on: day), isTrue);
    final t = (await repo.currentTarget(day))!;
    expect(t.validFrom, '2026-11-12');
    expect(t.bmr, 1780);
    expect(t.tdee, closeTo(2759, 1e-6));
    expect(t.tdeeSource, 'formula');
    expect(t.kcalTarget, closeTo(3034.9, 1e-6));
    expect(t.proteinG, 144);
    expect(t.fatG, 64);
    // Повторный расчёт в тот же день заменяет строку.
    await profile(goal: 'cut', pct: 15);
    await repo.recalcFormulaTarget(on: day);
    expect((await db.select(db.nutritionTargets).get()).length, 1);
    expect((await repo.currentTarget(day))!.kcalTarget, closeTo(2345.15, 1e-6));
    // Для более ранней даты нормы нет, для более поздней действует последняя.
    expect(await repo.currentTarget(DateTime.utc(2026, 11, 11)), isNull);
    expect((await repo.currentTarget(DateTime.utc(2026, 12, 1)))!.validFrom, '2026-11-12');
  });

  test('дневник: снимок КБЖУ не меняется при правке продукта; копирование приёма пищи', () async {
    final id = await repo.saveManualProduct(name: 'Творог', kcal: 120, protein: 16, fat: 5, carbs: 2);
    final day = DateTime.utc(2026, 11, 12);
    await repo.addFood(date: day, meal: 'breakfast', product: (await repo.product(id))!, grams: 150);
    await repo.saveManualProduct(id: id, name: 'Творог 9%', kcal: 160, protein: 16, fat: 9, carbs: 2);
    var entry = (await repo.watchDay('2026-11-12').first).single;
    expect(entry.log.kcal, 180);
    expect(entry.log.proteinG, 24);
    expect(entry.product!.name, 'Творог 9%');

    await repo.updateGrams(entry.log, 300);
    entry = (await repo.watchDay('2026-11-12').first).single;
    expect(entry.log.kcal, 360);

    expect(await repo.copyMeal(from: day, to: DateTime.utc(2026, 11, 13), meal: 'breakfast'), 1);
    expect(await repo.copyMeal(from: day, to: DateTime.utc(2026, 11, 13), meal: 'dinner'), 0);
    expect((await repo.watchDay('2026-11-13').first).single.log.kcal, 360);

    // Удаление продукта не трогает историю.
    expect(await repo.deleteProduct(id), isTrue);
    entry = (await repo.watchDay('2026-11-12').first).single;
    expect(entry.product, isNull);
    expect(entry.log.kcal, 360);
  });

  test('Open Food Facts: кэш по штрихкоду обновляется, а не дублируется; избранное и недавние', () async {
    const p = OffProduct(code: '4600000000001', name: 'Гречка', kcal100: 330, protein100: 12, fat100: 3, carbs100: 62);
    final id1 = await repo.cacheOffProduct(p);
    final id2 = await repo.cacheOffProduct(
        const OffProduct(code: '4600000000001', name: 'Гречка ядрица', kcal100: 335, protein100: 12, fat100: 3, carbs100: 62));
    expect(id2, id1);
    final saved = (await repo.byBarcode('4600000000001'))!;
    expect(saved.source, 'off');
    expect(saved.name, 'Гречка ядрица');
    expect(saved.syncedAt, isNotNull);

    final manual = await repo.saveManualProduct(name: 'Яблоко', kcal: 52, protein: 0, fat: 0, carbs: 14);
    await repo.setFavorite(manual, true);
    expect((await repo.watchProducts().first).first.name, 'Яблоко');
    expect((await repo.watchProducts(query: 'греч').first).single.id, id1);

    await repo.addFood(date: DateTime.utc(2026, 11, 12), meal: 'lunch', product: saved, grams: 80);
    await repo.addFood(date: DateTime.utc(2026, 11, 12), meal: 'snack', product: (await repo.product(manual))!, grams: 150);
    expect((await repo.recentProducts()).map((x) => x.name).toList(), ['Яблоко', 'Гречка ядрица']);
  });
}
