import 'package:drift/drift.dart';

import '../domain/dates.dart';
import '../domain/planning.dart';
import 'database.dart';

/// Операции планировщика: программа, недели, дни, упражнения, план по неделям.
class PlannerRepo {
  PlannerRepo(this.db);
  final AppDatabase db;

  // ---------- Программа ----------

  Stream<List<Program>> watchPrograms() =>
      (db.select(db.programs)..orderBy([(p) => OrderingTerm.desc(p.id)])).watch();

  Stream<Program?> watchProgram(int id) =>
      (db.select(db.programs)..where((p) => p.id.equals(id))).watchSingleOrNull();

  Stream<Program?> watchActiveProgram() =>
      (db.select(db.programs)..where((p) => p.status.equals('active'))).watchSingleOrNull();

  Future<Program?> activeProgram() =>
      (db.select(db.programs)..where((p) => p.status.equals('active'))).getSingleOrNull();

  /// Создаёт программу с неделями и днями. [deloadWeekNo] == null — без разгрузки.
  Future<int> createProgram({
    required String name,
    required DateTime startDate,
    required int weeksCount,
    required int timeLimitMin,
    required List<int> weekdays,
    required int? deloadWeekNo,
    double deloadSetsK = 0.5,
    double deloadWeightK = 0.9,
    int deloadRirAdd = 2,
  }) {
    return db.transaction(() async {
      final id = await db.into(db.programs).insert(ProgramsCompanion.insert(
            name: name,
            startDate: ymd(startDate),
            weeksCount: weeksCount,
            timeLimitMin: Value(timeLimitMin),
            deloadSetsK: Value(deloadSetsK),
            deloadWeightK: Value(deloadWeightK),
            deloadRirAdd: Value(deloadRirAdd),
          ));
      for (var n = 1; n <= weeksCount; n++) {
        await db.into(db.programWeeks).insert(ProgramWeeksCompanion.insert(
              programId: id,
              weekNo: n,
              startDate: ymd(addDays(weekStart(startDate), 7 * (n - 1))),
              isDeload: Value(n == deloadWeekNo),
            ));
      }
      final days = [...weekdays]..sort();
      for (var i = 0; i < days.length; i++) {
        await db.into(db.programDays).insert(ProgramDaysCompanion.insert(
              programId: id,
              weekday: days[i],
              name: Value(weekdayFull[days[i] - 1]),
              sortOrder: Value(i),
            ));
      }
      return id;
    });
  }

  /// Импорт программы из CSV (разделитель «;», первая строка — заголовки):
  /// program;weekday;exercise;week;sets;reps_min;reps_max;weight_kg;rir;rest_sec;deload;kind;muscles
  /// weekday — 1…7; deload — 1 для разгрузочной недели; kind и muscles («Группа=доля|Группа=доля»)
  /// нужны только для упражнений, которых нет в справочнике. Веса импортируются как заданные вручную.
  /// Создаёт черновик и возвращает его id.
  Future<int> importProgramCsv(String csv, {required DateTime startDate}) {
    final lines = csv.replaceAll('\uFEFF', '').split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.length < 2) throw const FormatException('Файл пуст');
    final head = [for (final h in lines.first.split(';')) h.trim().toLowerCase()];
    int col(String name) {
      final i = head.indexOf(name);
      if (i < 0) throw FormatException('Нет колонки «$name»');
      return i;
    }

    final cProgram = col('program'), cDay = col('weekday'), cEx = col('exercise'), cWeek = col('week');
    final cSets = col('sets'), cMin = col('reps_min'), cMax = col('reps_max'), cWeight = col('weight_kg');
    final cRir = head.indexOf('rir'), cRest = head.indexOf('rest_sec'), cDeload = head.indexOf('deload');
    final cKind = head.indexOf('kind'), cMuscles = head.indexOf('muscles');
    final rows = [for (final l in lines.skip(1)) [for (final c in l.split(';')) c.trim()]];
    String? at(List<String> r, int i) => i < 0 || i >= r.length || r[i].isEmpty ? null : r[i];
    int intAt(List<String> r, int i, String what) =>
        int.tryParse(at(r, i) ?? '') ?? (throw FormatException('Не число в колонке «$what»: ${r.join(';')}'));

    return db.transaction(() async {
      final weeksCount = rows.map((r) => intAt(r, cWeek, 'week')).reduce((a, b) => a > b ? a : b);
      if (weeksCount < 3 || weeksCount > 12) throw const FormatException('В программе должно быть от 3 до 12 недель');
      final deloadWeeks = {for (final r in rows) if (at(r, cDeload) == '1') intAt(r, cWeek, 'week')};
      final weekdays = {for (final r in rows) intAt(r, cDay, 'weekday')}.toList()..sort();
      final programId = await createProgram(
        name: at(rows.first, cProgram) ?? 'Импорт',
        startDate: startDate,
        weeksCount: weeksCount,
        timeLimitMin: 75,
        weekdays: weekdays,
        deloadWeekNo: deloadWeeks.isEmpty ? null : deloadWeeks.first,
      );
      final weekIdByNo = {for (final w in await weeksOf(programId)) w.weekNo: w.id};
      final dayIdByWeekday = {for (final d in await daysOf(programId)) d.weekday: d.id};
      final exercises = {for (final e in await db.select(db.exercises).get()) e.name.toLowerCase(): e.id};
      final muscles = {for (final m in await db.select(db.muscleGroups).get()) m.name.toLowerCase(): m.id};
      final pdeByKey = <String, int>{};

      for (final r in rows) {
        final name = at(r, cEx) ?? (throw FormatException('Пустое упражнение: ${r.join(';')}'));
        var exId = exercises[name.toLowerCase()];
        if (exId == null) {
          exId = await db.into(db.exercises).insert(ExercisesCompanion.insert(
                name: name,
                kind: at(r, cKind) == 'compound' ? 'compound' : 'isolation',
                isCustom: const Value(true),
              ));
          exercises[name.toLowerCase()] = exId;
          for (final part in (at(r, cMuscles) ?? '').split('|')) {
            final kv = part.split('=');
            final mId = muscles[kv.first.trim().toLowerCase()];
            final share = kv.length > 1 ? double.tryParse(kv[1].replaceAll(',', '.')) : null;
            if (mId != null && share != null && share >= 0.25 && share <= 1) {
              await db.into(db.exerciseMuscles).insert(
                  ExerciseMusclesCompanion.insert(exerciseId: exId, muscleGroupId: mId, share: share),
                  mode: InsertMode.insertOrIgnore);
            }
          }
        }
        final day = intAt(r, cDay, 'weekday');
        final key = '$day|$exId';
        var pdeId = pdeByKey[key];
        if (pdeId == null) {
          pdeId = await db.into(db.programDayExercises).insert(ProgramDayExercisesCompanion.insert(
                programDayId: dayIdByWeekday[day]!,
                exerciseId: exId,
                sortOrder: Value(pdeByKey.keys.where((k) => k.startsWith('$day|')).length),
                restSec: Value(int.tryParse(at(r, cRest) ?? '') ?? 120),
              ));
          pdeByKey[key] = pdeId;
        }
        final repsMin = intAt(r, cMin, 'reps_min');
        final repsMax = int.tryParse(at(r, cMax) ?? '') ?? repsMin;
        await db.into(db.exerciseWeekPlans).insert(
              ExerciseWeekPlansCompanion.insert(
                programDayExerciseId: pdeId,
                programWeekId: weekIdByNo[intAt(r, cWeek, 'week')]!,
                sets: intAt(r, cSets, 'sets'),
                repsMin: repsMin,
                repsMax: repsMax < repsMin ? repsMin : repsMax,
                weightKg: Value(double.tryParse((at(r, cWeight) ?? '').replaceAll(',', '.'))),
                targetRir: Value((int.tryParse(at(r, cRir) ?? '') ?? 2).clamp(0, 5)),
                isManual: const Value(true),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
      // Недели, которых нет в файле для упражнения, заполняются копией его первой строки.
      for (final pdeId in pdeByKey.values) {
        final have = await (db.select(db.exerciseWeekPlans)..where((p) => p.programDayExerciseId.equals(pdeId))).get();
        for (final w in weekIdByNo.entries) {
          if (have.any((p) => p.programWeekId == w.value)) continue;
          final t = have.first;
          await db.into(db.exerciseWeekPlans).insert(ExerciseWeekPlansCompanion.insert(
                programDayExerciseId: pdeId,
                programWeekId: w.value,
                sets: t.sets,
                repsMin: t.repsMin,
                repsMax: t.repsMax,
                weightKg: Value(t.weightKg),
                targetRir: Value(t.targetRir),
                isManual: const Value(true),
              ));
        }
      }
      return programId;
    });
  }

  /// Копия программы (черновик): недели, дни, упражнения и план по неделям.
  /// [weightDeltaKg] прибавляется ко всем весам копии (стартовым и недельным).
  Future<int> copyProgram(int sourceId, {required DateTime startDate, double weightDeltaKg = 0}) {
    return db.transaction(() async {
      final src = await (db.select(db.programs)..where((p) => p.id.equals(sourceId))).getSingle();
      final srcWeeks = await weeksOf(sourceId);
      final deload = srcWeeks.where((w) => w.isDeload).map((w) => w.weekNo).firstOrNull;
      final srcDays = await daysOf(sourceId);
      final newId = await createProgram(
        name: '${src.name} (копия)',
        startDate: startDate,
        weeksCount: src.weeksCount,
        timeLimitMin: src.timeLimitMin,
        weekdays: [for (final d in srcDays) d.weekday],
        deloadWeekNo: deload,
        deloadSetsK: src.deloadSetsK,
        deloadWeightK: src.deloadWeightK,
        deloadRirAdd: src.deloadRirAdd,
      );
      final weekIdByNo = {for (final w in await weeksOf(newId)) w.weekNo: w.id};
      final dayIdByWeekday = {for (final d in await daysOf(newId)) d.weekday: d.id};
      double? shift(double? w) => w == null ? null : (w + weightDeltaKg < 0 ? 0 : w + weightDeltaKg);
      for (final d in srcDays) {
        await renameDay(dayIdByWeekday[d.weekday]!, d.name);
        for (final e in await dayExercises(d.id)) {
          final pdeId = await db.into(db.programDayExercises).insert(ProgramDayExercisesCompanion.insert(
                programDayId: dayIdByWeekday[d.weekday]!,
                exerciseId: e.exerciseId,
                sortOrder: Value(e.sortOrder),
                restSec: Value(e.restSec),
                loadMode: Value(e.loadMode),
                startWeightKg: Value(shift(e.startWeightKg)),
                weeklyStepKg: Value(e.weeklyStepKg),
              ));
          for (final v in await plansOf(e.id)) {
            final p = v.plan;
            await db.into(db.exerciseWeekPlans).insert(ExerciseWeekPlansCompanion.insert(
                  programDayExerciseId: pdeId,
                  programWeekId: weekIdByNo[v.week.weekNo]!,
                  sets: p.sets,
                  repsMin: p.repsMin,
                  repsMax: p.repsMax,
                  weightKg: Value(shift(p.weightKg)),
                  percent1rm: Value(p.percent1rm),
                  targetRir: Value(p.targetRir),
                  isManual: Value(p.isManual),
                ));
          }
          await recalcPlans(pdeId);
        }
      }
      return newId;
    });
  }

  Future<void> updateProgram(int id, ProgramsCompanion data) =>
      (db.update(db.programs)..where((p) => p.id.equals(id))).write(data);

  /// Меняет неделю разгрузки и пересчитывает план.
  /// Неделя, переставшая быть разгрузочной, получает подходы, повторы и RIR соседней рабочей недели.
  Future<void> setDeloadWeek(int programId, int? weekNo) async {
    await db.transaction(() async {
      final weeks = await weeksOf(programId);
      final restored = [for (final w in weeks) if (w.isDeload && w.weekNo != weekNo) w.id];
      for (final w in weeks) {
        await (db.update(db.programWeeks)..where((x) => x.id.equals(w.id)))
            .write(ProgramWeeksCompanion(isDeload: Value(w.weekNo == weekNo)));
      }
      if (restored.isNotEmpty) {
        for (final d in await daysOf(programId)) {
          for (final e in await dayExercises(d.id)) {
            final plans = await plansOf(e.id);
            final template = plans.where((p) => !p.week.isDeload && !restored.contains(p.week.id)).firstOrNull?.plan;
            if (template == null) continue;
            for (final p in plans.where((p) => restored.contains(p.week.id) && !p.plan.isManual)) {
              await (db.update(db.exerciseWeekPlans)..where((x) => x.id.equals(p.plan.id))).write(
                ExerciseWeekPlansCompanion(
                  sets: Value(template.sets),
                  repsMin: Value(template.repsMin),
                  repsMax: Value(template.repsMax),
                  targetRir: Value(template.targetRir),
                ),
              );
            }
          }
        }
      }
      await recalcProgram(programId);
    });
  }

  /// Делает программу активной; прежняя активная уходит в архив.
  Future<void> activate(int id) => db.transaction(() async {
        await (db.update(db.programs)..where((p) => p.status.equals('active')))
            .write(const ProgramsCompanion(status: Value('archived')));
        await updateProgram(id, const ProgramsCompanion(status: Value('active')));
      });

  Future<void> archive(int id) => updateProgram(id, const ProgramsCompanion(status: Value('archived')));

  Future<void> deleteProgram(int id) => (db.delete(db.programs)..where((p) => p.id.equals(id))).go();

  // ---------- Недели и дни ----------

  Future<List<ProgramWeek>> weeksOf(int programId) => (db.select(db.programWeeks)
        ..where((w) => w.programId.equals(programId))
        ..orderBy([(w) => OrderingTerm.asc(w.weekNo)]))
      .get();

  Stream<List<ProgramWeek>> watchWeeks(int programId) => (db.select(db.programWeeks)
        ..where((w) => w.programId.equals(programId))
        ..orderBy([(w) => OrderingTerm.asc(w.weekNo)]))
      .watch();

  Stream<List<ProgramDay>> watchDays(int programId) => (db.select(db.programDays)
        ..where((d) => d.programId.equals(programId))
        ..orderBy([(d) => OrderingTerm.asc(d.weekday)]))
      .watch();

  Future<List<ProgramDay>> daysOf(int programId) => (db.select(db.programDays)
        ..where((d) => d.programId.equals(programId))
        ..orderBy([(d) => OrderingTerm.asc(d.weekday)]))
      .get();

  Future<void> renameDay(int dayId, String name) =>
      (db.update(db.programDays)..where((d) => d.id.equals(dayId))).write(ProgramDaysCompanion(name: Value(name)));

  /// Неделя программы, в которую попадает дата.
  Future<ProgramWeek?> weekForDate(int programId, DateTime date) async {
    final ws = ymd(weekStart(date));
    return (db.select(db.programWeeks)..where((w) => w.programId.equals(programId) & w.startDate.equals(ws)))
        .getSingleOrNull();
  }

  // ---------- Упражнения дня ----------

  Stream<List<DayExerciseView>> watchDayExercises(int dayId) {
    final q = db.select(db.programDayExercises).join([
      innerJoin(db.exercises, db.exercises.id.equalsExp(db.programDayExercises.exerciseId)),
    ])
      ..where(db.programDayExercises.programDayId.equals(dayId))
      ..orderBy([OrderingTerm.asc(db.programDayExercises.sortOrder)]);
    return q.watch().asyncMap((rows) async {
      final out = <DayExerciseView>[];
      for (final r in rows) {
        final pde = r.readTable(db.programDayExercises);
        out.add(DayExerciseView(pde, r.readTable(db.exercises), await plansOf(pde.id)));
      }
      return out;
    });
  }

  Future<List<ProgramDayExercise>> dayExercises(int dayId) => (db.select(db.programDayExercises)
        ..where((e) => e.programDayId.equals(dayId))
        ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]))
      .get();

  Future<ProgramDayExercise> pde(int id) =>
      (db.select(db.programDayExercises)..where((e) => e.id.equals(id))).getSingle();

  Stream<ProgramDayExercise?> watchPde(int id) =>
      (db.select(db.programDayExercises)..where((e) => e.id.equals(id))).watchSingleOrNull();

  Future<int> _programIdOfDay(int dayId) async =>
      (await (db.select(db.programDays)..where((d) => d.id.equals(dayId))).getSingle()).programId;

  /// Добавляет упражнение в день и создаёт строки плана на все недели.
  Future<int> addExercise({
    required int dayId,
    required int exerciseId,
    int sets = 3,
    int repsMin = 8,
    int repsMax = 12,
    int targetRir = 2,
    int restSec = 120,
  }) {
    return db.transaction(() async {
      final existing = await dayExercises(dayId);
      final id = await db.into(db.programDayExercises).insert(ProgramDayExercisesCompanion.insert(
            programDayId: dayId,
            exerciseId: exerciseId,
            sortOrder: Value(existing.length),
            restSec: Value(restSec),
          ));
      final weeks = await weeksOf(await _programIdOfDay(dayId));
      for (final w in weeks) {
        await db.into(db.exerciseWeekPlans).insert(ExerciseWeekPlansCompanion.insert(
              programDayExerciseId: id,
              programWeekId: w.id,
              sets: sets,
              repsMin: repsMin,
              repsMax: repsMax,
              targetRir: Value(targetRir),
            ));
      }
      await recalcPlans(id);
      return id;
    });
  }

  Future<void> removeExercise(int pdeId) =>
      (db.delete(db.programDayExercises)..where((e) => e.id.equals(pdeId))).go();

  /// Сохраняет порядок упражнений после перетаскивания.
  Future<void> reorder(int dayId, List<int> pdeIdsInOrder) => db.transaction(() async {
        for (var i = 0; i < pdeIdsInOrder.length; i++) {
          await (db.update(db.programDayExercises)..where((e) => e.id.equals(pdeIdsInOrder[i])))
              .write(ProgramDayExercisesCompanion(sortOrder: Value(i)));
        }
      });

  /// Переносит упражнение в другой день (в конец списка).
  Future<void> moveToDay(int pdeId, int targetDayId) => db.transaction(() async {
        final n = (await dayExercises(targetDayId)).length;
        await (db.update(db.programDayExercises)..where((e) => e.id.equals(pdeId)))
            .write(ProgramDayExercisesCompanion(programDayId: Value(targetDayId), sortOrder: Value(n)));
      });

  /// Копирует упражнения дня вместе с планом по неделям в другой день той же программы.
  /// При [replace] упражнения целевого дня сначала удаляются, иначе копии добавляются в конец.
  Future<int> copyDay({required int fromDayId, required int toDayId, bool replace = false}) {
    return db.transaction(() async {
      if (replace) {
        await (db.delete(db.programDayExercises)..where((e) => e.programDayId.equals(toDayId))).go();
      }
      var order = (await dayExercises(toDayId)).length;
      final source = await dayExercises(fromDayId);
      for (final e in source) {
        final newId = await db.into(db.programDayExercises).insert(ProgramDayExercisesCompanion.insert(
              programDayId: toDayId,
              exerciseId: e.exerciseId,
              sortOrder: Value(order++),
              restSec: Value(e.restSec),
              loadMode: Value(e.loadMode),
              startWeightKg: Value(e.startWeightKg),
              weeklyStepKg: Value(e.weeklyStepKg),
            ));
        for (final v in await plansOf(e.id)) {
          final p = v.plan;
          await db.into(db.exerciseWeekPlans).insert(ExerciseWeekPlansCompanion.insert(
                programDayExerciseId: newId,
                programWeekId: p.programWeekId,
                sets: p.sets,
                repsMin: p.repsMin,
                repsMax: p.repsMax,
                weightKg: Value(p.weightKg),
                percent1rm: Value(p.percent1rm),
                targetRir: Value(p.targetRir),
                isManual: Value(p.isManual),
              ));
        }
      }
      return source.length;
    });
  }

  Future<void> updatePde(int pdeId, ProgramDayExercisesCompanion data) async {
    await (db.update(db.programDayExercises)..where((e) => e.id.equals(pdeId))).write(data);
    await recalcPlans(pdeId);
  }

  // ---------- План по неделям ----------

  Future<List<WeekPlanView>> plansOf(int pdeId) async {
    final q = db.select(db.exerciseWeekPlans).join([
      innerJoin(db.programWeeks, db.programWeeks.id.equalsExp(db.exerciseWeekPlans.programWeekId)),
    ])
      ..where(db.exerciseWeekPlans.programDayExerciseId.equals(pdeId))
      ..orderBy([OrderingTerm.asc(db.programWeeks.weekNo)]);
    final rows = await q.get();
    return [for (final r in rows) WeekPlanView(r.readTable(db.exerciseWeekPlans), r.readTable(db.programWeeks))];
  }

  Stream<List<WeekPlanView>> watchPlans(int pdeId) {
    final q = db.select(db.exerciseWeekPlans).join([
      innerJoin(db.programWeeks, db.programWeeks.id.equalsExp(db.exerciseWeekPlans.programWeekId)),
    ])
      ..where(db.exerciseWeekPlans.programDayExerciseId.equals(pdeId))
      ..orderBy([OrderingTerm.asc(db.programWeeks.weekNo)]);
    return q.watch().map((rows) =>
        [for (final r in rows) WeekPlanView(r.readTable(db.exerciseWeekPlans), r.readTable(db.programWeeks))]);
  }

  /// Правка строки плана пользователем. Ручная правка веса ставит is_manual.
  Future<void> updatePlan(int planId, ExerciseWeekPlansCompanion data) async {
    await (db.update(db.exerciseWeekPlans)..where((p) => p.id.equals(planId))).write(data);
    final plan = await (db.select(db.exerciseWeekPlans)..where((p) => p.id.equals(planId))).getSingle();
    await recalcPlans(plan.programDayExerciseId);
  }

  /// Последний известный расчётный 1ПМ упражнения (для режима «% от 1ПМ»).
  Future<double?> latestE1rm(int exerciseId) async {
    final row = await (db.select(db.weeklyExerciseStats)
          ..where((s) => s.exerciseId.equals(exerciseId) & s.bestE1rmKg.isNotNull())
          ..orderBy([(s) => OrderingTerm.desc(s.weekStart)])
          ..limit(1))
        .getSingleOrNull();
    return row?.bestE1rmKg;
  }

  /// Пересчитывает веса плана по режиму нагрузки и строит разгрузочные недели.
  /// Строки с is_manual не трогаются.
  Future<void> recalcPlans(int pdeId) async {
    final item = await pde(pdeId);
    final settings = await db.getSettings();
    final programId = await _programIdOfDay(item.programDayId);
    final prog = await (db.select(db.programs)..where((p) => p.id.equals(programId))).getSingle();
    final step = settings.weightRoundingKg;
    final mode = LoadMode.fromDb(item.loadMode);
    final e1rm = mode == LoadMode.percent ? await latestE1rm(item.exerciseId) : null;
    final plans = await plansOf(pdeId);

    var workIdx = 0;
    ExerciseWeekPlan? prevWork;
    for (final v in plans) {
      var p = v.plan;
      if (v.week.isDeload) {
        if (!p.isManual && prevWork != null) {
          final d = deloadFrom(
            sets: prevWork.sets,
            weightKg: prevWork.weightKg,
            targetRir: prevWork.targetRir,
            setsK: prog.deloadSetsK,
            weightK: prog.deloadWeightK,
            rirAdd: prog.deloadRirAdd,
            step: step,
          );
          await (db.update(db.exerciseWeekPlans)..where((x) => x.id.equals(p.id))).write(ExerciseWeekPlansCompanion(
            sets: Value(d.sets),
            repsMin: Value(prevWork.repsMin),
            repsMax: Value(prevWork.repsMax),
            weightKg: Value(d.weightKg),
            targetRir: Value(d.targetRir),
          ));
        }
        continue;
      }
      if (!p.isManual) {
        final w = plannedWeight(
          mode: mode,
          workWeekIndex: workIdx,
          step: step,
          manualWeight: p.weightKg,
          percent1rm: p.percent1rm,
          e1rm: e1rm,
          startWeight: item.startWeightKg,
          weeklyStep: item.weeklyStepKg,
        );
        if (w != p.weightKg) {
          await (db.update(db.exerciseWeekPlans)..where((x) => x.id.equals(p.id)))
              .write(ExerciseWeekPlansCompanion(weightKg: Value(w)));
          p = p.copyWith(weightKg: Value(w));
        }
      }
      prevWork = p;
      workIdx++;
    }
  }

  Future<void> recalcProgram(int programId) async {
    for (final d in await daysOf(programId)) {
      for (final e in await dayExercises(d.id)) {
        await recalcPlans(e.id);
      }
    }
  }

  /// Длительность дня в секундах по плану указанной недели.
  Future<int> dayDuration(int dayId, int weekId) async {
    final settings = await db.getSettings();
    final items = <DayLoadItem>[];
    for (final e in await dayExercises(dayId)) {
      final plan = await (db.select(db.exerciseWeekPlans)
            ..where((p) => p.programDayExerciseId.equals(e.id) & p.programWeekId.equals(weekId)))
          .getSingleOrNull();
      if (plan != null) items.add(DayLoadItem(sets: plan.sets, restSec: e.restSec));
    }
    return dayDurationSec(items, setDurationSec: settings.setDurationSec, warmupMin: settings.warmupMin);
  }

  /// Убирает один подход у упражнения во всех рабочих неделях (не меньше 1).
  Future<void> removeOneSet(int pdeId) => db.transaction(() async {
        for (final v in await plansOf(pdeId)) {
          if (v.week.isDeload || v.plan.sets <= 1) continue;
          await (db.update(db.exerciseWeekPlans)..where((x) => x.id.equals(v.plan.id)))
              .write(ExerciseWeekPlansCompanion(sets: Value(v.plan.sets - 1)));
        }
        await recalcPlans(pdeId);
      });

  /// Сокращает отдых у всех упражнений дня на [deltaSec] (не меньше 30 с).
  Future<void> shortenRest(int dayId, {int deltaSec = 30}) => db.transaction(() async {
        for (final e in await dayExercises(dayId)) {
          final r = e.restSec - deltaSec;
          await (db.update(db.programDayExercises)..where((x) => x.id.equals(e.id)))
              .write(ProgramDayExercisesCompanion(restSec: Value(r < 30 ? 30 : r)));
        }
      });
}

class DayExerciseView {
  DayExerciseView(this.item, this.exercise, this.plans);
  final ProgramDayExercise item;
  final Exercise exercise;
  final List<WeekPlanView> plans;
}

class WeekPlanView {
  WeekPlanView(this.plan, this.week);
  final ExerciseWeekPlan plan;
  final ProgramWeek week;
}
