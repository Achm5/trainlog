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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await createIndexesAndTriggers();
          await seedDatabase(this);
        },
        onUpgrade: (m, from, to) async {
          // Версионные миграции: каждый шаг from → from + 1 добавляется сюда.
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

  Future<Setting> getSettings() => (select(settings)..where((s) => s.id.equals(1))).getSingle();

  Stream<Setting> watchSettings() => (select(settings)..where((s) => s.id.equals(1))).watchSingle();
}
