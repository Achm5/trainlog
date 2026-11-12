import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'features/analytics/analytics_screen.dart';
import 'features/data/data_screen.dart';
import 'features/data/lock_gate.dart';
import 'features/journal/session_screen.dart';
import 'features/journal/today_screen.dart';
import 'features/nutrition/nutrition_screen.dart';
import 'features/nutrition/profile_screen.dart';
import 'features/planner/exercise_plan_screen.dart';
import 'features/planner/program_form_screen.dart';
import 'features/planner/program_screen.dart';
import 'features/planner/programs_screen.dart';
import 'features/recommendations/recommendations.dart';
import 'features/reference/exercise_edit_screen.dart';
import 'features/reference/exercises_screen.dart';
import 'features/reference/muscle_groups_screen.dart';
import 'features/settings/settings_screen.dart';

int _id(GoRouterState s) => int.parse(s.pathParameters['id']!);

final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (c, s) => const HomeShell()),
    GoRoute(path: '/program/new', builder: (c, s) => const ProgramFormScreen()),
    GoRoute(path: '/program/:id', builder: (c, s) => ProgramScreen(programId: _id(s))),
    GoRoute(path: '/program/:id/edit', builder: (c, s) => ProgramFormScreen(programId: _id(s))),
    GoRoute(path: '/plan/:id', builder: (c, s) => ExercisePlanScreen(pdeId: _id(s))),
    GoRoute(path: '/session/:id', builder: (c, s) => SessionScreen(sessionId: _id(s))),
    GoRoute(path: '/exercises', builder: (c, s) => const ExercisesScreen()),
    GoRoute(path: '/exercise/new', builder: (c, s) => const ExerciseEditScreen()),
    GoRoute(path: '/exercise/:id', builder: (c, s) => ExerciseEditScreen(exerciseId: _id(s))),
    GoRoute(path: '/muscles', builder: (c, s) => const MuscleGroupsScreen()),
    GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
    GoRoute(path: '/recommendations', builder: (c, s) => const RecommendationsScreen()),
    GoRoute(path: '/rules', builder: (c, s) => const RulesScreen()),
    GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
    GoRoute(path: '/data', builder: (c, s) => const DataScreen()),
  ],
);

ThemeData _theme(Brightness b) => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F7A6B), brightness: b),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    );

class TrainLogApp extends StatelessWidget {
  const TrainLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Achm',
      builder: (context, child) => LockGate(child: child ?? const SizedBox.shrink()),
      routerConfig: appRouter,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ThemeMode.system,
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: const [TodayScreen(), ProgramsScreen(), AnalyticsScreen(), NutritionScreen(), MoreScreen()],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.fitness_center), label: 'Журнал'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'План'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'Аналитика'),
          NavigationDestination(icon: Icon(Icons.restaurant), label: 'Питание'),
          NavigationDestination(icon: Icon(Icons.menu), label: 'Ещё'),
        ],
      ),
    );
  }
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const ListTile(title: Text('Справочники и настройки', style: TextStyle(fontWeight: FontWeight.bold))),
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: const Text('Профиль и питание'),
          subtitle: const Text('Пол, возраст, рост, активность, цель и БЖУ'),
          onTap: () => context.push('/profile'),
        ),
        ListTile(
          leading: const Icon(Icons.list_alt),
          title: const Text('Упражнения'),
          subtitle: const Text('Справочник, вариации, свои упражнения'),
          onTap: () => context.push('/exercises'),
        ),
        ListTile(
          leading: const Icon(Icons.accessibility_new),
          title: const Text('Группы мышц'),
          subtitle: const Text('Целевые коридоры подходов в неделю'),
          onTap: () => context.push('/muscles'),
        ),
        ListTile(
          leading: const Icon(Icons.lightbulb_outline),
          title: const Text('Рекомендации'),
          subtitle: const Text('История решений и откат изменений плана'),
          onTap: () => context.push('/recommendations'),
        ),
        ListTile(
          leading: const Icon(Icons.rule),
          title: const Text('Правила'),
          subtitle: const Text('Пороги, приоритеты и паузы движка рекомендаций'),
          onTap: () => context.push('/rules'),
        ),
        ListTile(
          leading: const Icon(Icons.backup_outlined),
          title: const Text('Данные и защита'),
          subtitle: const Text('Резервная копия, импорт, CSV, PIN'),
          onTap: () => context.push('/data'),
        ),
        ListTile(
          leading: const Icon(Icons.settings),
          title: const Text('Настройки'),
          subtitle: const Text('Параметры расчётов'),
          onTap: () => context.push('/settings'),
        ),
      ],
    );
  }
}
