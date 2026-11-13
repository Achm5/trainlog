import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:trainlog/data/analytics_repo.dart';
import 'package:trainlog/data/database.dart';
import 'package:trainlog/data/journal_repo.dart';
import 'package:trainlog/data/nutrition_repo.dart';
import 'package:trainlog/data/planner_repo.dart';
import 'package:trainlog/data/report_repo.dart';
import 'package:trainlog/services/mesocycle_pdf.dart';

void main() {
  late AppDatabase db;
  late PlannerRepo planner;
  late JournalRepo journal;
  late int programId, dayId;

  setUp(() async {
    db = AppDatabase.memory();
    planner = PlannerRepo(db);
    journal = JournalRepo(db);
    programId = await planner.createProgram(
        name: 'Силовой блок', startDate: DateTime.utc(2026, 10, 5), weeksCount: 4, timeLimitMin: 75, weekdays: [1, 4], deloadWeekNo: 4);
    await planner.activate(programId);
    dayId = (await planner.daysOf(programId)).first.id;
    for (final name in ['Жим лёжа', 'Приседания со штангой']) {
      final ex = await (db.select(db.exercises)..where((e) => e.name.equals(name))).getSingle();
      final pde = await planner.addExercise(dayId: dayId, exerciseId: ex.id, sets: 3, repsMin: 5, repsMax: 5);
      await planner.updatePde(pde,
          const ProgramDayExercisesCompanion(loadMode: Value('linear'), startWeightKg: Value(100), weeklyStepKg: Value(2.5)));
    }
    await (db.update(db.settings)).write(const SettingsCompanion(name: Value('Алексей')));
  });
  tearDown(() => db.close());

  /// Тренировка первого дня недели [weekNo]: все подходы по плану, [reps] повторов.
  Future<void> session(int weekNo, {int reps = 5, String? note}) async {
    final week = (await planner.weeksOf(programId))[weekNo - 1];
    final sid = await journal.startPlannedSession(
        dayId: dayId, weekId: week.id, date: DateTime.parse('${week.startDate}T00:00:00Z'));
    final sets = await (db.select(db.setLogs).join([
      innerJoin(db.sessionExercises, db.sessionExercises.id.equalsExp(db.setLogs.sessionExerciseId)),
    ])..where(db.sessionExercises.sessionId.equals(sid))).get();
    for (final r in sets) {
      final s = r.readTable(db.setLogs);
      await journal.saveSet(s.id, weightKg: s.plannedWeightKg, reps: reps, rir: 2);
    }
    if (note != null) await journal.setSessionNote(sid, note);
    await journal.finishSession(sid);
  }

  test('данные отчёта за мезоцикл', () async {
    await session(1);
    await session(2, note: 'Тяжело шёл присед');
    await session(3, reps: 1); // недобор 4 — «частично»
    await NutritionRepo(db).setWeight(DateTime.utc(2026, 10, 5), 82);
    await NutritionRepo(db).setWeight(DateTime.utc(2026, 10, 26), 81);

    final r = await ReportRepo(db).build(programId, now: DateTime.utc(2026, 11, 2));
    expect(r.athlete, 'Алексей');
    expect(r.programName, 'Силовой блок');
    expect(r.from, DateTime.utc(2026, 10, 5));
    expect(r.to, DateTime.utc(2026, 11, 1));
    expect(r.sessionsPlanned, 8);
    expect(r.sessionsDone, 3);
    expect(r.weeks.map((w) => w.sessions).toList(), [1, 1, 1, 0]);
    expect(r.weeks.last.isDeload, isTrue);
    expect(r.setsTotal, 18);
    expect(r.setsPartial, 6);
    expect(r.setsFailed, 0);
    expect(r.doneShare, closeTo(12 / 18, 1e-9));
    // 100 × 5 × 3 × 2 упражнения + 102,5 × … + 105 × 1 × …
    expect(r.tonnageKg, closeTo(3000 + 3075 + 630, 1e-6));
    expect(r.exercises, hasLength(2));
    expect(r.exercises.first.e1rm, hasLength(3));
    expect(r.exercises.first.deltaPct, isNotNull);
    expect(r.muscles, isNotEmpty);
    expect(r.notes.single.text, 'Тяжело шёл присед');
    expect(r.weightStart, isNotNull);
    expect(r.weightEnd, isNotNull);

    final pdf = await buildMesocyclePdf(
      r,
      PdfAssets(
        regular: ByteData.sublistView(File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync()),
        bold: ByteData.sublistView(File('assets/fonts/Roboto-Bold.ttf').readAsBytesSync()),
        logo: File('assets/pdf/logo.png').readAsBytesSync(),
      ),
    );
    expect(String.fromCharCodes(pdf.sublist(0, 5)), '%PDF-');
    expect(pdf.length, greaterThan(10000));
    expect(reportFileName(r), 'achm-report-Силовой-блок-2026-11-02.pdf');
  });

  test('отчёт пустой программы строится', () async {
    final r = await ReportRepo(db).build(programId);
    expect(r.sessionsDone, 0);
    expect(r.doneShare, isNull);
    expect(r.exercises, isEmpty);
    final pdf = await buildMesocyclePdf(
      r,
      PdfAssets(
        regular: ByteData.sublistView(File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync()),
        bold: ByteData.sublistView(File('assets/fonts/Roboto-Bold.ttf').readAsBytesSync()),
        logo: File('assets/pdf/logo.png').readAsBytesSync(),
      ),
    );
    expect(pdf.length, greaterThan(1000));
  });

  test('недели нагрузки для проверки перетренированности', () async {
    await session(1);
    await session(2);
    await session(3, reps: 1);
    final weeks = await AnalyticsRepo(db).loadWeeks(DateTime.utc(2026, 10, 19), count: 4);
    expect(weeks.map((w) => w.weekStart).toList(), ['2026-09-28', '2026-10-05', '2026-10-12', '2026-10-19']);
    expect(weeks.map((w) => w.trained).toList(), [false, true, true, true]);
    expect(weeks.last.setsPartial, 6);
    expect(weeks[1].e1rmByExercise.keys.toSet(), {'Жим лёжа', 'Приседания со штангой'});
    final check = await AnalyticsRepo(db).overtraining(DateTime.utc(2026, 10, 28));
    expect(check.weekStart, '2026-10-19');
    expect(check.warn, isFalse);
  });
}
