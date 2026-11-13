import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'seed.dart';
import 'tables.dart';

part 'database.g.dart';

const dbFileName = 'trainlog.sqlite';

@DriftDatabase(
  tables: [
    Settings,
    MuscleGroups,
    Equipment,
    Exercises,
    ExerciseMuscles,
    Programs,
    ProgramWeeks,
    ProgramDays,
    ProgramDayExercises,
    ExerciseWeekPlans,
    WorkoutSessions,
    SessionExercises,
    SetLogs,
    WeeklyExerciseStats,
    WeeklyMuscleVolume,
    Rules,
    Recommendations,
    BodyWeightLogs,
    Products,
    RecipeItems,
    FoodLogs,
    NutritionTargets,
    WaterLogs,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// База в файле (рабочий режим приложения).
  factory AppDatabase.file(File file) => AppDatabase(
        NativeDatabase.createInBackground(file, setup: (db) => db.execute('PRAGMA foreign_keys = ON')),
      );

  /// База в памяти (тесты).
  factory AppDatabase.memory() => AppDatabase(
        NativeDatabase.memory(setup: (db) => db.execute('PRAGMA foreign_keys = ON')),
      );

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await createIndexesAndTriggers();
          await createV2Indexes();
          await seedDatabase(this);
        },
        onUpgrade: (m, from, to) async {
          // Версионные миграции: каждый шаг from → from + 1.
          if (from < 2) await createV2Indexes();
          if (from < 3) {
            final exists = await customSelect("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'water_logs'").get();
            if (exists.isEmpty) await m.createTable(waterLogs);
            await createIndexesAndTriggers();
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Индексы и ограничения, которые нельзя выразить в описании таблиц Drift,
  /// и триггеры, обновляющие updated_at.
  Future<void> createIndexesAndTriggers() async {
    await customStatement(
        "CREATE UNIQUE INDEX IF NOT EXISTS ux_programs_one_active ON programs(status) WHERE status = 'active'");
    await customStatement(
        "CREATE UNIQUE INDEX IF NOT EXISTS ux_products_off_barcode ON products(barcode) WHERE source = 'off'");
    await customStatement('CREATE INDEX IF NOT EXISTS ix_workout_sessions_date ON workout_sessions(date)');
    await customStatement('CREATE INDEX IF NOT EXISTS ix_food_logs_date ON food_logs(date)');
    await customStatement('CREATE INDEX IF NOT EXISTS ix_water_logs_date ON water_logs(date)');
    await customStatement('CREATE INDEX IF NOT EXISTS ix_recommendations_status ON recommendations(status)');
    for (final t in allTables) {
      final name = t.actualTableName;
      await customStatement('''
CREATE TRIGGER IF NOT EXISTS trg_${name}_updated_at AFTER UPDATE ON "$name"
FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at
BEGIN
  UPDATE "$name" SET updated_at = CAST(strftime('%s','now') AS INTEGER) * 1000 WHERE rowid = NEW.rowid;
END''');
    }
  }

  /// Схема v2: индексы для выборок журнала и плана по внешним ключам.
  static const v2Indexes = {
    'ix_session_exercises_session': 'session_exercises(session_id)',
    'ix_exercise_week_plans_week': 'exercise_week_plans(program_week_id)',
    'ix_weekly_exercise_stats_week': 'weekly_exercise_stats(week_start)',
  };

  Future<void> createV2Indexes() async {
    for (final e in v2Indexes.entries) {
      await customStatement('CREATE INDEX IF NOT EXISTS ${e.key} ON ${e.value}');
    }
  }

  Future<Setting> getSettings() => (select(settings)..where((s) => s.id.equals(1))).getSingle();

  Stream<Setting> watchSettings() => (select(settings)..where((s) => s.id.equals(1))).watchSingle();
}
