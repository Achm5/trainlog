import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/dates.dart';
import '../domain/nutrition.dart';
import 'database.dart';

/// Питание: вес тела и тренд, продукты, дневник, целевая норма.
class NutritionRepo {
  NutritionRepo(this.db);
  final AppDatabase db;

  // ---------- Вес тела ----------

  Stream<List<BodyWeightLog>> watchWeights({String? fromYmd}) {
    final q = db.select(db.bodyWeightLogs)..orderBy([(w) => OrderingTerm.asc(w.date)]);
    if (fromYmd != null) q.where((w) => w.date.isBiggerOrEqualValue(fromYmd));
    return q.watch();
  }

  Stream<BodyWeightLog?> watchWeight(String dateYmd) =>
      (db.select(db.bodyWeightLogs)..where((w) => w.date.equals(dateYmd))).watchSingleOrNull();

  Future<BodyWeightLog?> latestWeight({String? onOrBefore}) {
    final q = db.select(db.bodyWeightLogs)
      ..orderBy([(w) => OrderingTerm.desc(w.date)])
      ..limit(1);
    if (onOrBefore != null) q.where((w) => w.date.isSmallerOrEqualValue(onOrBefore));
    return q.getSingleOrNull();
  }

  /// Записывает вес дня (null — удалить запись) и пересчитывает тренд.
  Future<void> setWeight(DateTime date, double? weightKg) async {
    final d = ymd(date);
    await db.transaction(() async {
      await (db.delete(db.bodyWeightLogs)..where((w) => w.date.equals(d))).go();
      if (weightKg != null) {
        await db.into(db.bodyWeightLogs).insert(BodyWeightLogsCompanion.insert(date: d, weightKg: weightKg));
      }
      await recalcTrend();
    });
    if (await currentTarget(today()) == null) await recalcFormulaTarget();
  }

  /// Пересчитывает trend_kg всех записей (EMA, α = 0,1, пропуски интерполируются).
  Future<void> recalcTrend() async {
    final logs = await (db.select(db.bodyWeightLogs)..orderBy([(w) => OrderingTerm.asc(w.date)])).get();
    final trend = {
      for (final p in emaTrend({for (final l in logs) parseYmd(l.date): l.weightKg}))
        if (p.measured) ymd(p.date): p.trendKg,
    };
    for (final l in logs) {
      final t = trend[l.date];
      if (t != l.trendKg) {
        await (db.update(db.bodyWeightLogs)..where((w) => w.id.equals(l.id)))
            .write(BodyWeightLogsCompanion(trendKg: Value(t)));
      }
    }
  }

  // ---------- Продукты ----------

  /// Продукты: избранные первыми. Поиск без учёта регистра выполняется в Dart,
  /// потому что LIKE в SQLite не сворачивает регистр кириллицы.
  Stream<List<Product>> watchProducts({String query = ''}) {
    final q = db.select(db.products)
      ..orderBy([(p) => OrderingTerm.desc(p.isFavorite), (p) => OrderingTerm.asc(p.name)]);
    final needle = query.trim().toLowerCase();
    return q.watch().map((all) => [
          for (final p in all)
            if (needle.isEmpty ||
                p.name.toLowerCase().contains(needle) ||
                (p.brand ?? '').toLowerCase().contains(needle) ||
                p.barcode == needle)
              p,
        ].take(200).toList());
  }

  /// Недавние продукты — по последним записям дневника.
  Future<List<Product>> recentProducts({int limit = 20}) async {
    final rows = await db.customSelect(
      'SELECT product_id AS pid, MAX(id) AS last FROM food_logs WHERE product_id IS NOT NULL '
      'GROUP BY product_id ORDER BY last DESC LIMIT ?',
      variables: [Variable.withInt(limit)],
      readsFrom: {db.foodLogs},
    ).get();
    final out = <Product>[];
    for (final r in rows) {
      final p = await product(r.read<int>('pid'));
      if (p != null) out.add(p);
    }
    return out;
  }

  Future<Product?> product(int id) => (db.select(db.products)..where((p) => p.id.equals(id))).getSingleOrNull();

  Stream<Product?> watchProduct(int id) => (db.select(db.products)..where((p) => p.id.equals(id))).watchSingleOrNull();

  Future<Product?> byBarcode(String barcode) =>
      (db.select(db.products)..where((p) => p.barcode.equals(barcode))..limit(1)).getSingleOrNull();

  Future<int> saveManualProduct({
    int? id,
    required String name,
    String? brand,
    String? barcode,
    required double kcal,
    required double protein,
    required double fat,
    required double carbs,
  }) async {
    final data = ProductsCompanion(
      name: Value(name),
      brand: Value(brand == null || brand.isEmpty ? null : brand),
      barcode: Value(barcode == null || barcode.isEmpty ? null : barcode),
      kcal100g: Value(kcal),
      protein100g: Value(protein),
      fat100g: Value(fat),
      carbs100g: Value(carbs),
    );
    if (id != null) {
      await (db.update(db.products)..where((p) => p.id.equals(id))).write(data);
      return id;
    }
    return db.into(db.products).insert(data.copyWith(source: const Value('manual')));
  }

  /// Кэширует продукт Open Food Facts (или обновляет уже сохранённый по штрихкоду).
  Future<int> cacheOffProduct(OffProduct p) async {
    final existing = await (db.select(db.products)..where((x) => x.source.equals('off') & x.barcode.equals(p.code)))
        .getSingleOrNull();
    final data = ProductsCompanion(
      source: const Value('off'),
      barcode: Value(p.code),
      offCode: Value(p.code),
      name: Value(p.name),
      brand: Value(p.brand),
      kcal100g: Value(p.kcal100),
      protein100g: Value(p.protein100),
      fat100g: Value(p.fat100),
      carbs100g: Value(p.carbs100),
      syncedAt: Value(DateTime.now().millisecondsSinceEpoch),
    );
    if (existing != null) {
      await (db.update(db.products)..where((x) => x.id.equals(existing.id))).write(data);
      return existing.id;
    }
    return db.into(db.products).insert(data);
  }

  Future<void> setFavorite(int id, bool favorite) =>
      (db.update(db.products)..where((p) => p.id.equals(id))).write(ProductsCompanion(isFavorite: Value(favorite)));

  /// Удаляет продукт; история дневника сохраняется (в записях лежит снимок КБЖУ).
  Future<bool> deleteProduct(int id) async {
    try {
      await (db.delete(db.products)..where((p) => p.id.equals(id))).go();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------- Дневник ----------

  Stream<List<FoodEntry>> watchDay(String dateYmd) {
    final q = db.select(db.foodLogs).join([
      leftOuterJoin(db.products, db.products.id.equalsExp(db.foodLogs.productId)),
    ])
      ..where(db.foodLogs.date.equals(dateYmd))
      ..orderBy([OrderingTerm.asc(db.foodLogs.id)]);
    return q.watch().map((rows) => [for (final r in rows) FoodEntry(r.readTable(db.foodLogs), r.readTableOrNull(db.products))]);
  }

  /// Добавляет запись; КБЖУ сохраняются снимком на момент ввода.
  Future<int> addFood({required DateTime date, required String meal, required Product product, required double grams}) {
    final p = portion(
        grams: grams, kcal100: product.kcal100g, protein100: product.protein100g, fat100: product.fat100g, carbs100: product.carbs100g);
    return db.into(db.foodLogs).insert(FoodLogsCompanion.insert(
          date: ymd(date),
          meal: meal,
          productId: Value(product.id),
          grams: grams,
          kcal: p.kcal,
          proteinG: p.protein,
          fatG: p.fat,
          carbsG: p.carbs,
        ));
  }

  /// Меняет граммы записи, пропорционально пересчитывая её снимок.
  Future<void> updateGrams(FoodLog log, double grams) async {
    if (log.grams <= 0) return;
    final k = grams / log.grams;
    await (db.update(db.foodLogs)..where((f) => f.id.equals(log.id))).write(FoodLogsCompanion(
      grams: Value(grams),
      kcal: Value(log.kcal * k),
      proteinG: Value(log.proteinG * k),
      fatG: Value(log.fatG * k),
      carbsG: Value(log.carbsG * k),
    ));
  }

  Future<void> deleteFood(int id) => (db.delete(db.foodLogs)..where((f) => f.id.equals(id))).go();

  /// Копирует приём пищи с другого дня (снимки КБЖУ переносятся как есть). Возвращает число записей.
  Future<int> copyMeal({required DateTime from, required DateTime to, required String meal}) async {
    final src = await (db.select(db.foodLogs)..where((f) => f.date.equals(ymd(from)) & f.meal.equals(meal))).get();
    for (final f in src) {
      await db.into(db.foodLogs).insert(FoodLogsCompanion.insert(
            date: ymd(to),
            meal: meal,
            productId: Value(f.productId),
            grams: f.grams,
            kcal: f.kcal,
            proteinG: f.proteinG,
            fatG: f.fatG,
            carbsG: f.carbsG,
          ));
    }
    return src.length;
  }

  // ---------- Норма ----------

  Stream<NutritionTarget?> watchTarget(String dateYmd) => (db.select(db.nutritionTargets)
        ..where((t) => t.validFrom.isSmallerOrEqualValue(dateYmd))
        ..orderBy([(t) => OrderingTerm.desc(t.validFrom)])
        ..limit(1))
      .watchSingleOrNull();

  Future<NutritionTarget?> currentTarget(DateTime date) => (db.select(db.nutritionTargets)
        ..where((t) => t.validFrom.isSmallerOrEqualValue(ymd(date)))
        ..orderBy([(t) => OrderingTerm.desc(t.validFrom)])
        ..limit(1))
      .getSingleOrNull();

  /// Сохраняет норму с датой начала действия (заменяет норму той же даты).
  Future<void> saveTarget({
    required DateTime validFrom,
    required double bmr,
    required double tdee,
    required String source,
    required MacroTargets macros,
    required Map<String, dynamic> details,
  }) async {
    final d = ymd(validFrom);
    await db.transaction(() async {
      await (db.delete(db.nutritionTargets)..where((t) => t.validFrom.equals(d))).go();
      await db.into(db.nutritionTargets).insert(NutritionTargetsCompanion.insert(
            validFrom: d,
            bmr: bmr,
            tdee: tdee,
            tdeeSource: source,
            kcalTarget: macros.kcal,
            proteinG: macros.proteinG,
            fatG: macros.fatG,
            carbsG: macros.carbsG,
            calcDetails: Value(jsonEncode(details)),
          ));
    });
  }

  /// Пересчитывает норму от профиля. Если уже есть адаптивный TDEE и [keepAdaptive], он сохраняется,
  /// а пересчитываются только поправка на цель и БЖУ. Возвращает false, если не хватает данных профиля.
  Future<bool> recalcFormulaTarget({DateTime? on, bool keepAdaptive = true}) async {
    final day = on ?? today();
    final s = await db.getSettings();
    final w = await latestWeight(onOrBefore: ymd(day));
    if (w == null || s.heightCm == null || s.birthDate == null) return false;
    final weight = w.trendKg ?? w.weightKg;
    final age = ageOn(parseYmd(s.birthDate!), day);
    final bmr = bmrMifflin(sex: s.sex, weightKg: weight, heightCm: s.heightCm!, ageYears: age);
    final prev = await currentTarget(day);
    final adaptiveTdee = keepAdaptive && prev != null && prev.tdeeSource == 'adaptive' ? prev.tdee : null;
    final adaptive = adaptiveTdee != null;
    final tdee = adaptiveTdee ?? bmr * s.activityK;
    final adjust = goalAdjust(s.goal, s.goalAdjustPct);
    final macros = macroTargets(
        bmr: bmr, tdee: tdee, adjust: adjust, weightKg: weight, proteinPerKg: s.proteinGPerKg, fatPerKgMin: s.fatGPerKgMin);
    await saveTarget(
      validFrom: day,
      bmr: bmr,
      tdee: tdee,
      source: adaptive ? 'adaptive' : 'formula',
      macros: macros,
      details: {
        'weight_kg': weight,
        'height_cm': s.heightCm,
        'age': age,
        'sex': s.sex,
        'activity_k': s.activityK,
        'goal': s.goal,
        'adjust': adjust,
        'protein_g_per_kg': s.proteinGPerKg,
        'fat_g_per_kg_min': s.fatGPerKgMin,
        'floor_bmr': macros.kcal == bmr,
      },
    );
    return true;
  }

  // ---------- Вода ----------

  /// Выпито за день, мл.
  Stream<int> watchWater(String dateYmd) => (db.select(db.waterLogs)..where((w) => w.date.equals(dateYmd)))
      .watch()
      .map((rows) => rows.fold<int>(0, (s, r) => s + r.ml));

  Future<void> addWater(DateTime date, int ml) =>
      db.into(db.waterLogs).insert(WaterLogsCompanion.insert(date: ymd(date), ml: ml));

  /// Отменяет последнюю запись воды за день. Возвращает false, если записей нет.
  Future<bool> undoWater(DateTime date) async {
    final last = await (db.select(db.waterLogs)
          ..where((w) => w.date.equals(ymd(date)))
          ..orderBy([(w) => OrderingTerm.desc(w.id)])
          ..limit(1))
        .getSingleOrNull();
    if (last == null) return false;
    await (db.delete(db.waterLogs)..where((w) => w.id.equals(last.id))).go();
    return true;
  }

  /// Норма воды на день: по расходу из действующей нормы питания, иначе по весу и профилю. null — нет веса.
  Future<int?> waterTarget(DateTime date) async {
    final w = await latestWeight(onOrBefore: ymd(date));
    if (w == null) return null;
    final s = await db.getSettings();
    final t = await currentTarget(date);
    return waterTargetMl(
      tdee: t?.tdee,
      weightKg: w.trendKg ?? w.weightKg,
      sex: s.sex,
      ageYears: s.birthDate == null ? null : ageOn(parseYmd(s.birthDate!), date),
    );
  }

  // ---------- Рецепты ----------

  Future<List<RecipeItemView>> recipeItems(int recipeId) async {
    final q = db.select(db.recipeItems).join([
      innerJoin(db.products, db.products.id.equalsExp(db.recipeItems.productId)),
    ])
      ..where(db.recipeItems.recipeProductId.equals(recipeId));
    return [for (final r in await q.get()) RecipeItemView(r.readTable(db.products), r.readTable(db.recipeItems).grams)];
  }

  /// Сохраняет рецепт как продукт с source = recipe; КБЖУ на 100 г считаются из ингредиентов.
  Future<int> saveRecipe({int? id, required String name, required Map<int, double> gramsByProductId}) {
    return db.transaction(() async {
      final items = <RecipeIngredient>[];
      for (final e in gramsByProductId.entries) {
        final p = await product(e.key);
        if (p == null) continue;
        items.add(RecipeIngredient(
            grams: e.value, kcal100: p.kcal100g, protein100: p.protein100g, fat100: p.fat100g, carbs100: p.carbs100g));
      }
      final r = recipePer100(items);
      final data = ProductsCompanion(
        source: const Value('recipe'),
        name: Value(name),
        kcal100g: Value(r.kcal),
        protein100g: Value(r.protein),
        fat100g: Value(r.fat),
        carbs100g: Value(r.carbs),
      );
      final int recipeId;
      if (id == null) {
        recipeId = await db.into(db.products).insert(data);
      } else {
        recipeId = id;
        await (db.update(db.products)..where((p) => p.id.equals(id))).write(data);
        await (db.delete(db.recipeItems)..where((i) => i.recipeProductId.equals(id))).go();
      }
      for (final e in gramsByProductId.entries) {
        if (e.key == recipeId) continue;
        await db.into(db.recipeItems).insert(
            RecipeItemsCompanion.insert(recipeProductId: recipeId, productId: e.key, grams: e.value));
      }
      return recipeId;
    });
  }

  // ---------- Адаптивный расход ----------

  /// Еженедельный пересчёт TDEE по тренду веса и рациону (раздел 6.2). Вызывается при закрытии недели.
  /// Окно — [windowDays] дней до конца закрытой недели. При невалидном окне прежняя норма остаётся.
  Future<AdaptiveTdee?> applyAdaptiveTdee(DateTime weekStartDay, {int windowDays = 21}) async {
    final end = addDays(weekStartDay, 6);
    final start = addDays(end, -(windowDays - 1));
    final prev = await currentTarget(end);
    if (prev == null) return null;
    final s = await db.getSettings();

    final foods = await (db.select(db.foodLogs)..where((f) => f.date.isBetweenValues(ymd(start), ymd(end)))).get();
    final kcalByDay = <String, double>{};
    for (final f in foods) {
      kcalByDay[f.date] = (kcalByDay[f.date] ?? 0) + f.kcal;
    }
    final logs = await (db.select(db.bodyWeightLogs)
          ..where((w) => w.date.isSmallerOrEqualValue(ymd(end)))
          ..orderBy([(w) => OrderingTerm.asc(w.date)]))
        .get();
    final series = emaTrend({for (final l in logs) parseYmd(l.date): l.weightKg})
        .where((p) => !p.date.isBefore(start) && !p.date.isAfter(end))
        .toList();
    final weighIns = series.where((p) => p.measured).length;
    if (series.length < 2) {
      return AdaptiveTdee(valid: false, tdee: prev.tdee, foodDays: kcalByDay.length, weighIns: weighIns);
    }
    final r = adaptiveTdee(
      oldTdee: prev.tdee,
      dailyKcal: kcalByDay.values.toList(),
      weighIns: weighIns,
      trendStartKg: series.first.trendKg,
      trendEndKg: series.last.trendKg,
      windowDays: daysBetween(series.first.date, series.last.date),
      kcalPerKg: s.kcalPerKg,
    );
    if (!r.valid) return r;

    final weight = series.last.trendKg;
    final validFrom = addDays(weekStartDay, 7);
    final bmr = s.heightCm != null && s.birthDate != null
        ? bmrMifflin(sex: s.sex, weightKg: weight, heightCm: s.heightCm!, ageYears: ageOn(parseYmd(s.birthDate!), validFrom))
        : prev.bmr;
    final adjust = goalAdjust(s.goal, s.goalAdjustPct);
    await saveTarget(
      validFrom: validFrom,
      bmr: bmr,
      tdee: r.tdee,
      source: 'adaptive',
      macros: macroTargets(
          bmr: bmr, tdee: r.tdee, adjust: adjust, weightKg: weight, proteinPerKg: s.proteinGPerKg, fatPerKgMin: s.fatGPerKgMin),
      details: {
        'window_start': ymd(series.first.date),
        'window_end': ymd(series.last.date),
        'food_days': r.foodDays,
        'weigh_ins': r.weighIns,
        'trend_start_kg': series.first.trendKg,
        'trend_end_kg': series.last.trendKg,
        'tdee_old': prev.tdee,
        'tdee_observed': r.observed,
        'kcal_per_kg': s.kcalPerKg,
        'adjust': adjust,
      },
    );
    return r;
  }
}

class RecipeItemView {
  RecipeItemView(this.product, this.grams);
  final Product product;
  final double grams;
}

class FoodEntry {
  FoodEntry(this.log, this.product);
  final FoodLog log;
  final Product? product;
}
