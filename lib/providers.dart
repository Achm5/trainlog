import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/analytics_repo.dart';
import 'data/app_state.dart';
import 'data/database.dart';
import 'data/journal_repo.dart';
import 'data/nutrition_repo.dart';
import 'data/planner_repo.dart';
import 'data/reference_repo.dart';
import 'data/rules_repo.dart';
import 'services/notifications.dart';
import 'services/off_client.dart';

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

  /// Полная длительность текущего отсчёта — для кольца прогресса.
  int totalSec = 0;

  void start(int seconds) {
    final notifications = NotificationService.instance;
    if (seconds <= 0) return stop();
    totalSec = seconds;
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

final appStateProvider = Provider<AppStateStore>((ref) => MemoryAppState());
final rulesRepoProvider =
    Provider<RulesRepo>((ref) => RulesRepo(ref.watch(databaseProvider), ref.watch(appStateProvider)));
final newRecommendationsProvider = StreamProvider<List<RecommendationView>>(
    (ref) => ref.watch(rulesRepoProvider).watchRecommendations(status: 'new'));
final allRecommendationsProvider =
    StreamProvider<List<RecommendationView>>((ref) => ref.watch(rulesRepoProvider).watchRecommendations());
final rulesProvider = StreamProvider<List<Rule>>((ref) => ref.watch(rulesRepoProvider).watchRules());

final nutritionRepoProvider = Provider<NutritionRepo>((ref) => NutritionRepo(ref.watch(databaseProvider)));
final offClientProvider = Provider<OffClient>((ref) => OffClient());
final foodDayProvider =
    StreamProvider.family<List<FoodEntry>, String>((ref, d) => ref.watch(nutritionRepoProvider).watchDay(d));
final targetProvider =
    StreamProvider.family<NutritionTarget?, String>((ref, d) => ref.watch(nutritionRepoProvider).watchTarget(d));
final dayWeightProvider =
    StreamProvider.family<BodyWeightLog?, String>((ref, d) => ref.watch(nutritionRepoProvider).watchWeight(d));
final weightsProvider =
    StreamProvider.family<List<BodyWeightLog>, String?>((ref, from) => ref.watch(nutritionRepoProvider).watchWeights(fromYmd: from));
final productsProvider =
    StreamProvider.family<List<Product>, String>((ref, q) => ref.watch(nutritionRepoProvider).watchProducts(query: q));
final productProvider = StreamProvider.family<Product?, int>((ref, id) => ref.watch(nutritionRepoProvider).watchProduct(id));
