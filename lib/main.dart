import 'dart:io';

import 'package:flutter/foundation.dart';
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
import 'services/error_log.dart';
import 'services/notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationSupportDirectory();
  // Журнал ошибок: необработанные исключения пишутся в файл на телефоне («Данные и защита» → «Журнал ошибок»).
  ErrorLog.init(File(p.join(dir.path, 'errors.log')));
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    ErrorLog.record(details.context?.toDescription() ?? 'интерфейс', details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorLog.record('фоновая операция', error, stack);
    return false;
  };
  try {
    await NotificationService.instance.init();
  } catch (e, st) {
    ErrorLog.record('уведомления', e, st);
  }
  final db = AppDatabase.file(File(p.join(dir.path, dbFileName)));
  final state = FileAppState(File(p.join(dir.path, 'app_state.json')));

  // Закрытие недели — при первом запуске на новой неделе; пропущенные недели по очереди.
  try {
    final nutrition = NutritionRepo(db);
    await RulesRepo(db, state).closeWeeks(extra: (week) async {
      await nutrition.applyAdaptiveTdee(week);
    });
  } catch (e, st) {
    debugPrint('Закрытие недели не выполнено: $e');
    ErrorLog.record('закрытие недели', e, st);
  }

  final savedTabs = await state.get(stateNavTabs);
  final overtrainingOn = await state.get(stateOvertrainingWarning) != '0';

  runApp(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      appStateProvider.overrideWithValue(state),
      if (savedTabs != null)
        initialNavTabsProvider.overrideWithValue(savedTabs.split(',').where((t) => t.isNotEmpty).toSet()),
      initialOvertrainingProvider.overrideWithValue(overtrainingOn),
    ],
    child: const TrainLogApp(),
  ));
}
