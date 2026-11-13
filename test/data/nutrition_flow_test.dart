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

  group('адаптивный TDEE при закрытии недели', () {
    final monday = DateTime.utc(2026, 11, 2); // закрываемая неделя 02.11–08.11, окно 19.10–08.11
    Future<void> seed({required int foodDays, required int weighIns, double kcal = 2500, double dailyDelta = 0}) async {
      await profile();
      final start = DateTime.utc(2026, 10, 19);
      for (var i = 0; i < 21; i++) {
        final d = start.add(Duration(days: i));
        if (i < weighIns) await repo.setWeight(d, 80 + dailyDelta * i);
      }
      await db.delete(db.nutritionTargets).go();
      await repo.recalcFormulaTarget(on: start); // BMR 1780 × 1,55 = 2759 (вес 80, тренд первого дня)
      final id = await repo.saveManualProduct(name: 'Еда', kcal: 100, protein: 5, fat: 3, carbs: 12);
      final p = (await repo.product(id))!;
      for (var i = 0; i < foodDays; i++) {
        await repo.addFood(date: start.add(Duration(days: i)), meal: 'lunch', product: p, grams: kcal);
      }
    }

    test('невалидное окно оставляет прежнее значение', () async {
      await seed(foodDays: 9, weighIns: 21);
      final r = (await repo.applyAdaptiveTdee(monday))!;
      expect(r.valid, isFalse);
      expect((await db.select(db.nutritionTargets).get()).length, 1);
      await db.delete(db.foodLogs).go();
      await db.delete(db.bodyWeightLogs).go();
      await seed(foodDays: 21, weighIns: 7);
      expect((await repo.applyAdaptiveTdee(monday))!.valid, isFalse);
    });

    test('валидное окно: новая норма с понедельника, изменение не больше 150 ккал', () async {
      await seed(foodDays: 21, weighIns: 21, kcal: 2000); // ест 2000 при стабильном весе → расход ниже формульного
      final old = (await repo.currentTarget(monday))!;
      final r = (await repo.applyAdaptiveTdee(monday))!;
      expect(r.valid, isTrue);
      expect(r.observed, closeTo(2000, 1e-6));
      expect(r.tdee, closeTo(old.tdee - 150, 1e-6)); // 0,7 × 2759 + 0,3 × 2000 = 2531,3 → ограничено −150
      final t = (await repo.currentTarget(DateTime.utc(2026, 11, 9)))!;
      expect(t.validFrom, '2026-11-09');
      expect(t.tdeeSource, 'adaptive');
      expect(t.tdee, closeTo(old.tdee - 150, 1e-6));
      expect(t.kcalTarget, closeTo(old.tdee - 150, 1e-6)); // удержание, выше BMR
      // Старая норма продолжает действовать на прошлые дни.
      expect((await repo.currentTarget(DateTime.utc(2026, 11, 8)))!.tdeeSource, 'formula');
      // Правка профиля сохраняет адаптивный расход.
      await repo.recalcFormulaTarget(on: DateTime.utc(2026, 11, 10));
      expect((await repo.currentTarget(DateTime.utc(2026, 11, 10)))!.tdeeSource, 'adaptive');
    });

    test('без нормы пересчёт не выполняется', () async {
      expect(await repo.applyAdaptiveTdee(monday), isNull);
    });
  });

  test('рецепт: КБЖУ на 100 г из ингредиентов, правка состава пересчитывает', () async {
    final rice = await repo.saveManualProduct(name: 'Рис', kcal: 350, protein: 7, fat: 1, carbs: 78);
    final chicken = await repo.saveManualProduct(name: 'Курица', kcal: 110, protein: 23, fat: 2, carbs: 0);
    final id = await repo.saveRecipe(name: 'Плов', gramsByProductId: {rice: 100, chicken: 300});
    var recipe = (await repo.product(id))!;
    expect(recipe.source, 'recipe');
    expect(recipe.kcal100g, closeTo((350 + 330) / 4, 1e-9));
    expect(recipe.protein100g, closeTo((7 + 69) / 4, 1e-9));
    expect((await repo.recipeItems(id)).length, 2);

    await repo.saveRecipe(id: id, name: 'Плов', gramsByProductId: {rice: 200});
    recipe = (await repo.product(id))!;
    expect(recipe.kcal100g, closeTo(350, 1e-9));
    expect((await repo.recipeItems(id)).single.product.name, 'Рис');
    // Ингредиент рецепта удалить нельзя.
    expect(await repo.deleteProduct(rice), isFalse);
    expect(await repo.deleteProduct(chicken), isTrue);
  });

  test('вода: сумма за день, отмена последней записи, норма по расходу и по весу', () async {
    final day = DateTime.utc(2026, 11, 12);
    expect(await repo.waterTarget(day), isNull); // нет веса
    await repo.addWater(day, 250);
    await repo.addWater(day, 500);
    await repo.addWater(DateTime.utc(2026, 11, 13), 200);
    expect(await repo.watchWater('2026-11-12').first, 750);
    expect(await repo.undoWater(day), isTrue);
    expect(await repo.watchWater('2026-11-12').first, 250);
    expect(await repo.undoWater(DateTime.utc(2026, 11, 1)), isFalse);

    await repo.setWeight(day, 80);
    await db.delete(db.nutritionTargets).go();
    expect(await repo.waterTarget(day), 2800); // 80 кг × 35 мл
    await profile();
    await repo.recalcFormulaTarget(on: day);
    expect(await repo.waterTarget(day), 2750); // расход 2759 ккал → 2750 мл
    expect(waterTargetMl(weightKg: 60, sex: 'f'), 1850); // 60 × 31 = 1860 → 1850
    expect(waterTargetMl(weightKg: 80, sex: 'm', ageYears: 60), 2400);
  });
}
