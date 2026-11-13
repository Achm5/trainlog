import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/app_state.dart';
import 'data/database.dart';
import 'data/nutrition_repo.dart';
import 'data/rules_repo.dart';
import 'providers.dart';
import 'services/notifications.dart';
import 'package:trainlog/i18n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  final dir = await getApplicationSupportDirectory();
  final db = AppDatabase.file(File(p.join(dir.path, dbFileName)));
  final state = FileAppState(File(p.join(dir.path, 'app_state.json')));

  // Язык и единицы нужны до первых расчётов и текста: правила и уведомления их уже используют.
  final savedLang = await state.get(stateLang);
  final deviceLang = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  I18n.lang = (savedLang ?? deviceLang) == 'ru' ? AppLang.ru : AppLang.en;
  I18n.pounds = await state.get(stateUnits) == 'lb';

  // Закрытие недели — при первом запуске на новой неделе; пропущенные недели по очереди.
  try {
    final nutrition = NutritionRepo(db);
    await RulesRepo(db, state).closeWeeks(extra: (week) async {
      await nutrition.applyAdaptiveTdee(week);
    });
  } catch (e) {
    debugPrint(tr('Закрытие недели не выполнено: {0}', [e]));
  }

  final savedTabs = await state.get(stateNavTabs);
  final overtrainingOn = await state.get(stateOvertrainingWarning) != '0';
  final workoutNotificationOn = await state.get(stateWorkoutNotification) != '0';
  // Уведомление о ходе тренировки могло остаться от закрытого приложения; экран тренировки покажет его снова.
  await NotificationService.instance.cancelWorkout();

  runApp(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      appStateProvider.overrideWithValue(state),
      if (savedTabs != null)
        initialNavTabsProvider.overrideWithValue(savedTabs.split(',').where((t) => t.isNotEmpty).toSet()),
      initialOvertrainingProvider.overrideWithValue(overtrainingOn),
      initialWorkoutNotificationProvider.overrideWithValue(workoutNotificationOn),
    ],
    child: const TrainLogApp(),
  ));
}
