import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/analytics_repo.dart';
import 'data/database.dart';
import 'data/journal_repo.dart';
import 'data/planner_repo.dart';
import 'data/reference_repo.dart';
import 'services/notifications.dart';

final databaseProvider = Provider<AppDatabase>((ref) => throw StateError('База открывается в main()'));

final plannerRepoProvider = Provider<PlannerRepo>((ref) => PlannerRepo(ref.watch(databaseProvider)));
final journalRepoProvider = Provider<JournalRepo>((ref) => JournalRepo(ref.watch(databaseProvider)));

final settingsProvider = StreamProvider<Setting>((ref) => ref.watch(databaseProvider).watchSettings());

final referenceRepoProvider = Provider<ReferenceRepo>((ref) => ReferenceRepo(ref.watch(databaseProvider)));

final muscleGroupsProvider = StreamProvider<List<MuscleGroup>>((ref) => ref.watch(referenceRepoProvider).watchMuscleGroups());
final equipmentProvider = StreamProvider<List<EquipmentItem>>((ref) => ref.watch(referenceRepoProvider).watchEquipment());
final exercisesProvider = StreamProvider.family<List<ExerciseView>, bool>(
    (ref, includeArchived) => ref.watch(referenceRepoProvider).watchExercises(includeArchived: includeArchived));

final programsProvider = StreamProvider<List<Program>>((ref) => ref.watch(plannerRepoProvider).watchPrograms());
final activeProgramProvider = StreamProvider<Program?>((ref) => ref.watch(plannerRepoProvider).watchActiveProgram());
final programProvider = StreamProvider.family<Program?, int>((ref, id) => ref.watch(plannerRepoProvider).watchProgram(id));
final programWeeksProvider =
    StreamProvider.family<List<ProgramWeek>, int>((ref, id) => ref.watch(plannerRepoProvider).watchWeeks(id));
final programDaysProvider =
    StreamProvider.family<List<ProgramDay>, int>((ref, id) => ref.watch(plannerRepoProvider).watchDays(id));
final dayExercisesProvider =
    StreamProvider.family<List<DayExerciseView>, int>((ref, dayId) => ref.watch(plannerRepoProvider).watchDayExercises(dayId));
final pdeProvider =
    StreamProvider.family<ProgramDayExercise?, int>((ref, id) => ref.watch(plannerRepoProvider).watchPde(id));
final weekPlansProvider =
    StreamProvider.family<List<WeekPlanView>, int>((ref, pdeId) => ref.watch(plannerRepoProvider).watchPlans(pdeId));

final analyticsRepoProvider = Provider<AnalyticsRepo>((ref) => AnalyticsRepo(ref.watch(databaseProvider)));

final inProgressSessionProvider =
    StreamProvider<WorkoutSession?>((ref) => ref.watch(journalRepoProvider).watchInProgress());
final historyProvider = StreamProvider<List<SessionSummary>>((ref) => ref.watch(journalRepoProvider).watchHistory());
final sessionProvider =
    StreamProvider.family<WorkoutSession?, int>((ref, id) => ref.watch(journalRepoProvider).watchSession(id));
final sessionExercisesProvider = StreamProvider.family<List<SessionExerciseView>, int>(
    (ref, id) => ref.watch(journalRepoProvider).watchSessionExercises(id));

/// Таймер отдыха: момент окончания или null, если таймер не запущен.
class RestTimer extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  bool _permissionAsked = false;

  void start(int seconds) {
    final notifications = NotificationService.instance;
    if (seconds <= 0) return stop();
    final end = DateTime.now().add(Duration(seconds: seconds));
    state = end;
    () async {
      if (!_permissionAsked) {
        _permissionAsked = true;
        await notifications.requestPermission();
      }
      await notifications.scheduleRestEnd(end);
    }();
  }

  void stop() {
    state = null;
    NotificationService.instance.cancelRest();
  }
}

final restTimerProvider = NotifierProvider<RestTimer, DateTime?>(RestTimer.new);
