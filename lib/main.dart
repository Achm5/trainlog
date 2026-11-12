import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'data/database.dart';

final databaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError('База открывается в main()'));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationSupportDirectory();
  final db = AppDatabase.file(File(p.join(dir.path, dbFileName)));
  runApp(ProviderScope(overrides: [databaseProvider.overrideWithValue(db)], child: const TrainLogApp()));
}

class TrainLogApp extends ConsumerWidget {
  const TrainLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Тренировки',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal), useMaterial3: true),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const Scaffold(body: Center(child: Text('Тренировки'))),
    );
  }
}
