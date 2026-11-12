// ignore_for_file: recursive_getters
import 'package:drift/drift.dart';

/// Схема БД — раздел 7 ТЗ (22 таблицы).
/// Даты — TEXT YYYY-MM-DD, метки времени — INTEGER (Unix, мс), JSON — TEXT.

int nowMs() => DateTime.now().millisecondsSinceEpoch;

mixin Timestamps on Table {
  IntColumn get createdAt => integer().clientDefault(nowMs)();
  IntColumn get updatedAt => integer().clientDefault(nowMs)();
}

// ---------- 7.1 Настройки ----------

class Settings extends Table with Timestamps {
  IntColumn get id => integer().check(id.equals(1))();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get sex => text().withDefault(const Constant('m')).check(sex.isIn(const ['m', 'f']))();
  TextColumn get birthDate => text().nullable()();
  RealColumn get heightCm => real().nullable()();
  TextColumn get timezone => text().withDefault(const Constant(''))();
  TextColumn get pinHash => text().nullable()();
  RealColumn get weightRoundingKg => real().withDefault(const Constant(2.5))();
  BoolColumn get e1rmUseRir => boolean().withDefault(const Constant(true))();
  IntColumn get setDurationSec => integer().withDefault(const Constant(40))();
  IntColumn get warmupMin => integer().withDefault(const Constant(10))();
  RealColumn get kcalPerKg => real().withDefault(const Constant(7700))();
  RealColumn get activityK => real().withDefault(const Constant(1.375))();
  TextColumn get goal =>
      text().withDefault(const Constant('maintain')).check(goal.isIn(const ['gain', 'cut', 'maintain']))();
  RealColumn get goalAdjustPct => real().withDefault(const Constant(0))();
  RealColumn get proteinGPerKg => real().withDefault(const Constant(1.8))();
  RealColumn get fatGPerKgMin => real().withDefault(const Constant(0.8))();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------- 7.2 Справочники ----------

class MuscleGroups extends Table with Timestamps {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  IntColumn get targetSetsMin => integer().withDefault(const Constant(10))();
  IntColumn get targetSetsMax => integer().withDefault(const Constant(20))();
}

@DataClassName('EquipmentItem')
class Equipment extends Table with Timestamps {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

class Exercises extends Table with Timestamps {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get baseExerciseId => integer().nullable().references(Exercises, #id, onDelete: KeyAction.setNull)();
  TextColumn get kind => text().check(kind.isIn(const ['compound', 'isolation']))();
  IntColumn get equipmentId => integer().nullable().references(Equipment, #id, onDelete: KeyAction.setNull)();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
}

class ExerciseMuscles extends Table with Timestamps {
  IntColumn get exerciseId => integer().references(Exercises, #id, onDelete: KeyAction.cascade)();
  IntColumn get muscleGroupId => integer().references(MuscleGroups, #id, onDelete: KeyAction.restrict)();
  RealColumn get share => real().check(share.isBetweenValues(0.25, 1.0))();

  @override
  Set<Column> get primaryKey => {exerciseId, muscleGroupId};
}

// ---------- 7.3 Планирование ----------

class Programs extends Table with Timestamps {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get startDate => text()();
  IntColumn get weeksCount => integer().check(weeksCount.isBetweenValues(3, 12))();
  IntColumn get timeLimitMin => integer().withDefault(const Constant(75))();
  RealColumn get deloadSetsK => real().withDefault(const Constant(0.5))();
  RealColumn get deloadWeightK => real().withDefault(const Constant(0.9))();
  IntColumn get deloadRirAdd => integer().withDefault(const Constant(2))();
  TextColumn get status =>
      text().withDefault(const Constant('draft')).check(status.isIn(const ['draft', 'active', 'archived']))();
}

class ProgramWeeks extends Table with Timestamps {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get programId => integer().references(Programs, #id, onDelete: KeyAction.cascade)();
  IntColumn get weekNo => integer()();
  TextColumn get startDate => text()();
  BoolColumn get isDeload => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {programId, weekNo},
      ];
}

class ProgramDays extends Table with Timestamps {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get programId => integer().references(Programs, #id, onDelete: KeyAction.cascade)();
  IntColumn get weekday => integer().check(weekday.isBetweenValues(1, 7))();
  TextColumn get name => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {programId, weekday},
      ];
}

class ProgramDayExercises extends Table with Timestamps {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get programDayId => integer().references(ProgramDays, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id, onDelete: KeyAction.restrict)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get restSec => integer().withDefault(const Constant(120))();
  TextColumn get loadMode =>
      text().withDefault(const Constant('manual')).check(loadMode.isIn(const ['manual', 'percent', 'linear']))();
  RealColumn get startWeightKg => real().nullable()();
  RealColumn get weeklyStepKg => real().nullable()();
}

class ExerciseWeekPlans extends Table with Timestamps {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get programDayExerciseId =>
      integer().references(ProgramDayExercises, #id, onDelete: KeyAction.cascade)();
  IntColumn get programWeekId => integer().references(ProgramWeeks, #id, onDelete: KeyAction.cascade)();
  IntColumn get sets => integer()();
  IntColumn get repsMin => integer()();
  IntColumn get repsMax => integer()();
  RealColumn get weightKg => real().nullable()();
  RealColumn get percent1rm => real().named('percent_1rm').nullable()();
  IntColumn get targetRir => integer().withDefault(const Constant(2))();
  BoolColumn get isManual => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {programDayExerciseId, programWeekId},
      ];
}

// ---------- 7.4 Журнал ----------

class WorkoutSessions extends Table with Timestamps {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get programDayId => integer().nullable().references(ProgramDays, #id, onDelete: KeyAction.setNull)();
  IntColumn get programWeekId => integer().nullable().references(ProgramWeeks, #id, onDelete: KeyAction.setNull)();
  TextColumn get date => text()();
  IntColumn get startedAt => integer()();
  IntColumn get finishedAt => integer().nullable()();
  TextColumn get status => text()
      .withDefault(const Constant('in_progress'))
      .check(status.isIn(const ['in_progress', 'completed']))();
  TextColumn get note => text().nullable()();
}

class SessionExercises extends Table with Timestamps {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(WorkoutSessions, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id, onDelete: KeyAction.restrict)();
  IntColumn get exerciseWeekPlanId =>
      integer().nullable().references(ExerciseWeekPlans, #id, onDelete: KeyAction.setNull)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get status => text().nullable()();
}

class SetLogs extends Table with Timestamps {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionExerciseId => integer().references(SessionExercises, #id, onDelete: KeyAction.cascade)();
  IntColumn get setNo => integer()();
  BoolColumn get isWarmup => boolean().withDefault(const Constant(false))();
  RealColumn get plannedWeightKg => real().nullable()();
  IntColumn get plannedReps => integer().nullable()();
  RealColumn get weightKg => real().nullable()();
  IntColumn get reps => integer().nullable()();
  IntColumn get rir => integer().nullable().check(rir.isBetweenValues(0, 5))();
  TextColumn get status => text()
      .nullable()
      .check(status.isIn(const ['done', 'minor_miss', 'partial', 'failed', 'skipped']))();
  BoolColumn get weightReduced => boolean().withDefault(const Constant(false))();
  RealColumn get e1rmKg => real().nullable()();
  TextColumn get note => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {sessionExerciseId, setNo},
      ];
}

// ---------- 7.5 Аналитика и правила ----------

class WeeklyExerciseStats extends Table with Timestamps {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId => integer().references(Exercises, #id, onDelete: KeyAction.restrict)();
  TextColumn get weekStart => text()();
  RealColumn get bestE1rmKg => real().nullable()();
  RealColumn get e1rmDeltaPct => real().nullable()();
  RealColumn get tonnageKg => real().withDefault(const Constant(0))();
  IntColumn get workSets => integer().withDefault(const Constant(0))();
  IntColumn get setsDone => integer().withDefault(const Constant(0))();
  IntColumn get setsPartial => integer().withDefault(const Constant(0))();
  IntColumn get setsFailed => integer().withDefault(const Constant(0))();
  BoolColumn get isDeload => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {exerciseId, weekStart},
      ];
}

@DataClassName('WeeklyMuscleVolumeRow')
class WeeklyMuscleVolume extends Table with Timestamps {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get muscleGroupId => integer().references(MuscleGroups, #id, onDelete: KeyAction.cascade)();
  TextColumn get weekStart => text()();
  RealColumn get sets => real().withDefault(const Constant(0))();
  RealColumn get tonnageKg => real().withDefault(const Constant(0))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {muscleGroupId, weekStart},
      ];
}

class Rules extends Table with Timestamps {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get code => text().unique()();
  TextColumn get name => text()();
  TextColumn get trigger => text().check(trigger.isIn(const ['session_completed', 'week_closed']))();
  TextColumn get scope => text().check(scope.isIn(const ['exercise', 'program']))();
  TextColumn get condition => text()();
  TextColumn get action => text()();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  IntColumn get cooldownDays => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

class Recommendations extends Table with Timestamps {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ruleId => integer().references(Rules, #id, onDelete: KeyAction.cascade)();
  IntColumn get programId => integer().references(Programs, #id, onDelete: KeyAction.cascade)();
  IntColumn get programDayExerciseId =>
      integer().nullable().references(ProgramDayExercises, #id, onDelete: KeyAction.cascade)();
  TextColumn get facts => text().withDefault(const Constant('{}'))();
  TextColumn get proposedChanges => text().withDefault(const Constant('{}'))();
  TextColumn get previousValues => text().nullable()();
  TextColumn get status => text()
      .withDefault(const Constant('new'))
      .check(status.isIn(const ['new', 'accepted', 'rejected', 'expired']))();
  IntColumn get resolvedAt => integer().nullable()();
}

// ---------- 7.6 Питание ----------

class BodyWeightLogs extends Table with Timestamps {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text().unique()();
  RealColumn get weightKg => real()();
  RealColumn get trendKg => real().nullable()();
}

class Products extends Table with Timestamps {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get source => text().check(source.isIn(const ['off', 'manual', 'recipe']))();
  TextColumn get barcode => text().nullable()();
  TextColumn get offCode => text().nullable()();
  TextColumn get name => text()();
  TextColumn get brand => text().nullable()();
  RealColumn get kcal100g => real().named('kcal_100g')();
  RealColumn get protein100g => real().named('protein_100g').withDefault(const Constant(0))();
  RealColumn get fat100g => real().named('fat_100g').withDefault(const Constant(0))();
  RealColumn get carbs100g => real().named('carbs_100g').withDefault(const Constant(0))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  IntColumn get syncedAt => integer().nullable()();
}

class RecipeItems extends Table with Timestamps {
  IntColumn get recipeProductId => integer().references(Products, #id, onDelete: KeyAction.cascade)();
  @ReferenceName('recipeUsages')
  IntColumn get productId => integer().references(Products, #id, onDelete: KeyAction.restrict)();
  RealColumn get grams => real()();

  @override
  Set<Column> get primaryKey => {recipeProductId, productId};
}

class FoodLogs extends Table with Timestamps {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text()();
  TextColumn get meal => text().check(meal.isIn(const ['breakfast', 'lunch', 'dinner', 'snack']))();
  IntColumn get productId => integer().nullable().references(Products, #id, onDelete: KeyAction.setNull)();
  RealColumn get grams => real()();
  RealColumn get kcal => real()();
  RealColumn get proteinG => real()();
  RealColumn get fatG => real()();
  RealColumn get carbsG => real()();
}

class NutritionTargets extends Table with Timestamps {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get validFrom => text().unique()();
  RealColumn get bmr => real()();
  RealColumn get tdee => real()();
  TextColumn get tdeeSource => text().check(tdeeSource.isIn(const ['formula', 'adaptive']))();
  RealColumn get kcalTarget => real()();
  RealColumn get proteinG => real()();
  RealColumn get fatG => real()();
  RealColumn get carbsG => real()();
  TextColumn get calcDetails => text().withDefault(const Constant('{}'))();
}
