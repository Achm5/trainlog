import 'package:drift/drift.dart';

import 'database.dart';

/// Справочники: группы мышц, оборудование, упражнения.
class ReferenceRepo {
  ReferenceRepo(this.db);
  final AppDatabase db;

  Stream<List<MuscleGroup>> watchMuscleGroups() =>
      (db.select(db.muscleGroups)..orderBy([(m) => OrderingTerm.asc(m.id)])).watch();

  Future<List<MuscleGroup>> muscleGroups() =>
      (db.select(db.muscleGroups)..orderBy([(m) => OrderingTerm.asc(m.id)])).get();

  Future<void> updateCorridor(int id, int min, int max) => (db.update(db.muscleGroups)..where((m) => m.id.equals(id)))
      .write(MuscleGroupsCompanion(targetSetsMin: Value(min), targetSetsMax: Value(max)));

  Stream<List<EquipmentItem>> watchEquipment() =>
      (db.select(db.equipment)..orderBy([(e) => OrderingTerm.asc(e.id)])).watch();

  Future<List<EquipmentItem>> equipment() => (db.select(db.equipment)..orderBy([(e) => OrderingTerm.asc(e.id)])).get();

  /// Все упражнения с долями групп мышц (архивные — по флагу).
  Stream<List<ExerciseView>> watchExercises({bool includeArchived = false}) {
    final q = db.select(db.exercises)..orderBy([(e) => OrderingTerm.asc(e.name)]);
    if (!includeArchived) q.where((e) => e.isArchived.equals(false));
    return q.watch().asyncMap((list) async {
      final muscles = await db.select(db.exerciseMuscles).get();
      final byEx = <int, List<ExerciseMuscle>>{};
      for (final m in muscles) {
        byEx.putIfAbsent(m.exerciseId, () => []).add(m);
      }
      return [for (final e in list) ExerciseView(e, byEx[e.id] ?? const [])];
    });
  }

  Future<Exercise?> exercise(int id) => (db.select(db.exercises)..where((e) => e.id.equals(id))).getSingleOrNull();

  Future<List<ExerciseMuscle>> musclesOf(int exerciseId) =>
      (db.select(db.exerciseMuscles)..where((m) => m.exerciseId.equals(exerciseId))).get();

  /// База и все её вариации (включая само упражнение), без архивных.
  Future<List<Exercise>> variationFamily(int exerciseId) async {
    final e = await exercise(exerciseId);
    if (e == null) return const [];
    final baseId = e.baseExerciseId ?? e.id;
    return (db.select(db.exercises)
          ..where((x) => (x.id.equals(baseId) | x.baseExerciseId.equals(baseId)) & x.isArchived.equals(false))
          ..orderBy([(x) => OrderingTerm.asc(x.id)]))
        .get();
  }

  /// Создаёт или обновляет упражнение вместе с долями групп мышц.
  Future<int> saveExercise({
    int? id,
    required String name,
    required String kind,
    required int? baseExerciseId,
    required int? equipmentId,
    required Map<int, double> shares,
  }) {
    return db.transaction(() async {
      final int exId;
      if (id == null) {
        exId = await db.into(db.exercises).insert(ExercisesCompanion.insert(
              name: name,
              kind: kind,
              baseExerciseId: Value(baseExerciseId),
              equipmentId: Value(equipmentId),
              isCustom: const Value(true),
            ));
      } else {
        exId = id;
        await (db.update(db.exercises)..where((e) => e.id.equals(id))).write(ExercisesCompanion(
          name: Value(name),
          kind: Value(kind),
          baseExerciseId: Value(baseExerciseId),
          equipmentId: Value(equipmentId),
        ));
        await (db.delete(db.exerciseMuscles)..where((m) => m.exerciseId.equals(id))).go();
      }
      for (final s in shares.entries) {
        await db.into(db.exerciseMuscles).insert(
              ExerciseMusclesCompanion.insert(exerciseId: exId, muscleGroupId: s.key, share: s.value),
            );
      }
      return exId;
    });
  }

  Future<void> setArchived(int id, bool archived) =>
      (db.update(db.exercises)..where((e) => e.id.equals(id))).write(ExercisesCompanion(isArchived: Value(archived)));

  /// Удаляет упражнение, если на него нет ссылок; иначе архивирует. Возвращает true, если удалено.
  Future<bool> deleteOrArchive(int id) async {
    try {
      await (db.delete(db.exercises)..where((e) => e.id.equals(id))).go();
      return true;
    } catch (_) {
      await setArchived(id, true);
      return false;
    }
  }

  Future<void> updateSettings(SettingsCompanion data) =>
      (db.update(db.settings)..where((s) => s.id.equals(1))).write(data);
}

class ExerciseView {
  ExerciseView(this.exercise, this.muscles);
  final Exercise exercise;
  final List<ExerciseMuscle> muscles;

  int? get primaryMuscleId {
    if (muscles.isEmpty) return null;
    return muscles.reduce((a, b) => a.share >= b.share ? a : b).muscleGroupId;
  }
}
