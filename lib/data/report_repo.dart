import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/dates.dart';
import 'database.dart';
import 'planner_repo.dart';

/// Данные отчёта за мезоцикл (недели программы) для тренера.
class MesocycleReport {
  MesocycleReport({
    required this.athlete,
    required this.programName,
    required this.from,
    required this.to,
    required this.weeksCount,
    required this.generatedAt,
    required this.sessionsPlanned,
    required this.sessionsDone,
    required this.weeks,
    required this.exercises,
    required this.muscles,
    required this.decisions,
    required this.notes,
    this.weightStart,
    this.weightEnd,
  });

  final String athlete;
  final String programName;
  final DateTime from;
  final DateTime to;
  final int weeksCount;
  final DateTime generatedAt;
  final int sessionsPlanned;
  final int sessionsDone;
  final List<ReportWeek> weeks;
  final List<ReportExercise> exercises;
  final List<ReportMuscle> muscles;
  final List<ReportDecision> decisions;
  final List<ReportNote> notes;
  final double? weightStart;
  final double? weightEnd;

  int get setsDone => weeks.fold(0, (a, w) => a + w.setsDone);
  int get setsPartial => weeks.fold(0, (a, w) => a + w.setsPartial);
  int get setsFailed => weeks.fold(0, (a, w) => a + w.setsFailed);
  int get setsTotal => setsDone + setsPartial + setsFailed;
  double get tonnageKg => weeks.fold(0.0, (a, w) => a + w.tonnageKg);

  /// Доля выполненных подходов (зелёные, включая небольшой недобор), null — подходов нет.
  double? get doneShare => setsTotal == 0 ? null : setsDone / setsTotal;
}

class ReportWeek {
  ReportWeek({
    required this.weekNo,
    required this.start,
    required this.isDeload,
    this.sessions = 0,
    this.workSets = 0,
    this.setsDone = 0,
    this.setsPartial = 0,
    this.setsFailed = 0,
    this.tonnageKg = 0,
  });
  final int weekNo;
  final DateTime start;
  final bool isDeload;
  int sessions;
  int workSets;
  int setsDone;
  int setsPartial;
  int setsFailed;
  double tonnageKg;

  int get setsTotal => setsDone + setsPartial + setsFailed;
}

class ReportExercise {
  ReportExercise({required this.name, required this.isCompound, required this.e1rm});
  final String name;
  final bool isCompound;

  /// Лучший расчётный 1ПМ по рабочим (не разгрузочным) неделям, по порядку.
  final List<double> e1rm;

  double get first => e1rm.first;
  double get last => e1rm.last;
  double get best => e1rm.reduce((a, b) => a > b ? a : b);

  /// Изменение последнего значения к первому, %; null — меньше двух недель.
  double? get deltaPct => e1rm.length < 2 || first <= 0 ? null : (last - first) / first * 100;
}

class ReportMuscle {
  ReportMuscle({required this.name, required this.avgSets, required this.targetMin, required this.targetMax});
  final String name;
  final double avgSets;
  final int targetMin;
  final int targetMax;
}

class ReportDecision {
  ReportDecision({required this.date, required this.rule, required this.status, this.exercise});
  final DateTime date;
  final String rule;
  final String status; // accepted | rejected | expired
  final String? exercise;
}

class ReportNote {
  ReportNote(this.date, this.text);
  final DateTime date;
  final String text;
}

class ReportRepo {
  ReportRepo(this.db);
  final AppDatabase db;

  late final _planner = PlannerRepo(db);

  Future<MesocycleReport> build(int programId, {DateTime? now}) async {
    final program = await (db.select(db.programs)..where((p) => p.id.equals(programId))).getSingle();
    final settings = await db.getSettings();
    final programWeeks = await _planner.weeksOf(programId);
    final days = await _planner.daysOf(programId);
    final from = weekStart(parseYmd(program.startDate));
    final to = addDays(from, 7 * program.weeksCount - 1);
    final fromYmd = ymd(from), toYmd = ymd(to);

    final weeks = [
      for (final w in programWeeks)
        ReportWeek(weekNo: w.weekNo, start: weekStart(parseYmd(w.startDate)), isDeload: w.isDeload),
    ];
    ReportWeek? weekOf(String dateYmd) {
      final ws = weekStart(parseYmd(dateYmd));
      return weeks.where((w) => w.start == ws).firstOrNull;
    }

    // Завершённые тренировки периода (плановые и свободные).
    final sessions = await (db.select(db.workoutSessions)
          ..where((s) => s.status.equals('completed') & s.date.isBetweenValues(fromYmd, toYmd))
          ..orderBy([(s) => OrderingTerm.asc(s.date), (s) => OrderingTerm.asc(s.startedAt)]))
        .get();
    final weekIds = {for (final w in programWeeks) w.id};
    for (final s in sessions) {
      weekOf(s.date)?.sessions++;
    }
    final sessionsDone = sessions.where((s) => s.programWeekId != null && weekIds.contains(s.programWeekId)).length;

    // Недельные агрегаты упражнений.
    final statsQ = db.select(db.weeklyExerciseStats).join([
      innerJoin(db.exercises, db.exercises.id.equalsExp(db.weeklyExerciseStats.exerciseId)),
    ])
      ..where(db.weeklyExerciseStats.weekStart.isBetweenValues(fromYmd, toYmd))
      ..orderBy([OrderingTerm.asc(db.weeklyExerciseStats.weekStart)]);
    final byExercise = <int, ReportExercise>{};
    for (final r in await statsQ.get()) {
      final st = r.readTable(db.weeklyExerciseStats);
      final ex = r.readTable(db.exercises);
      final w = weekOf(st.weekStart);
      if (w != null) {
        w.workSets += st.workSets;
        w.setsDone += st.setsDone;
        w.setsPartial += st.setsPartial;
        w.setsFailed += st.setsFailed;
        w.tonnageKg += st.tonnageKg;
      }
      final deload = st.isDeload || (w?.isDeload ?? false);
      if (st.bestE1rmKg != null && !deload) {
        byExercise
            .putIfAbsent(ex.id, () => ReportExercise(name: ex.name, isCompound: ex.kind == 'compound', e1rm: []))
            .e1rm
            .add(st.bestE1rmKg!);
      }
    }
    final exercises = byExercise.values.toList()
      ..sort((a, b) {
        if (a.isCompound != b.isCompound) return a.isCompound ? -1 : 1;
        return (b.deltaPct ?? -1e9).compareTo(a.deltaPct ?? -1e9);
      });

    // Объём по группам мышц: среднее по рабочим неделям, в которых были тренировки.
    final workWeekStarts = {
      for (final w in weeks)
        if (!w.isDeload && w.setsTotal + w.workSets > 0) ymd(w.start),
    };
    final volQ = db.select(db.weeklyMuscleVolume).join([
      innerJoin(db.muscleGroups, db.muscleGroups.id.equalsExp(db.weeklyMuscleVolume.muscleGroupId)),
    ])
      ..where(db.weeklyMuscleVolume.weekStart.isBetweenValues(fromYmd, toYmd));
    final sums = <int, double>{};
    final groups = <int, MuscleGroup>{};
    for (final r in await volQ.get()) {
      final v = r.readTable(db.weeklyMuscleVolume);
      if (!workWeekStarts.contains(v.weekStart)) continue;
      final g = r.readTable(db.muscleGroups);
      groups[g.id] = g;
      sums[g.id] = (sums[g.id] ?? 0) + v.sets;
    }
    final muscles = [
      for (final e in sums.entries)
        if (e.value > 0)
          ReportMuscle(
            name: groups[e.key]!.name,
            avgSets: e.value / workWeekStarts.length,
            targetMin: groups[e.key]!.targetSetsMin,
            targetMax: groups[e.key]!.targetSetsMax,
          ),
    ]..sort((a, b) => b.avgSets.compareTo(a.avgSets));

    // Вес тела: первое и последнее взвешивание периода (по тренду, если он есть).
    final weights = await (db.select(db.bodyWeightLogs)
          ..where((w) => w.date.isBetweenValues(fromYmd, toYmd))
          ..orderBy([(w) => OrderingTerm.asc(w.date)]))
        .get();

    // Решения по рекомендациям программы.
    final recQ = db.select(db.recommendations).join([
      innerJoin(db.rules, db.rules.id.equalsExp(db.recommendations.ruleId)),
    ])
      ..where(db.recommendations.programId.equals(programId) &
          db.recommendations.status.isIn(const ['accepted', 'rejected']) &
          db.recommendations.resolvedAt.isNotNull())
      ..orderBy([OrderingTerm.asc(db.recommendations.resolvedAt)]);
    final decisions = [
      for (final r in await recQ.get())
        () {
          final rec = r.readTable(db.recommendations);
          String? exercise;
          try {
            exercise = (jsonDecode(rec.facts) as Map<String, dynamic>)['exercise'] as String?;
          } on FormatException {
            exercise = null;
          }
          return ReportDecision(
            date: DateTime.fromMillisecondsSinceEpoch(rec.resolvedAt!),
            rule: r.readTable(db.rules).name,
            status: rec.status,
            exercise: exercise,
          );
        }(),
    ];

    return MesocycleReport(
      athlete: settings.name.trim(),
      programName: program.name,
      from: from,
      to: to,
      weeksCount: program.weeksCount,
      generatedAt: now ?? DateTime.now(),
      sessionsPlanned: days.length * program.weeksCount,
      sessionsDone: sessionsDone,
      weeks: weeks,
      exercises: exercises,
      muscles: muscles,
      decisions: decisions,
      notes: [
        for (final s in sessions)
          if ((s.note ?? '').trim().isNotEmpty) ReportNote(parseYmd(s.date), s.note!.trim()),
      ],
      weightStart: weights.isEmpty ? null : weights.first.trendKg ?? weights.first.weightKg,
      weightEnd: weights.length < 2 ? null : weights.last.trendKg ?? weights.last.weightKg,
    );
  }
}
