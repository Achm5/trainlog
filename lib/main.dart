import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/database.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationSupportDirectory();
  final db = AppDatabase.file(File(p.join(dir.path, dbFileName)));
  runApp(ProviderScope(overrides: [databaseProvider.overrideWithValue(db)], child: const TrainLogApp()));
}
