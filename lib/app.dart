import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'features/analytics/analytics_screen.dart';
import 'features/data/data_screen.dart';
import 'features/data/lock_gate.dart';
import 'features/journal/session_screen.dart';
import 'features/motion.dart';
import 'features/journal/plate_calculator.dart';
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
import 'providers.dart';

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
    GoRoute(
      path: '/section/:sid',
      builder: (c, s) => navSections.firstWhere((t) => t.id == s.pathParameters['sid'], orElse: () => navSections.first).screen,
    ),
  ],
);

const brandRed = Color(0xFFEF233C);
const brandBlack = Color(0xFF0D0D0D);

/// Фирменные цвета: чёрный #0D0D0D и красный #EF233C.
ThemeData _theme(Brightness b) {
  final base = ColorScheme.fromSeed(seedColor: brandRed, brightness: b);
  final scheme = b == Brightness.dark
      ? base.copyWith(
          primary: brandRed,
          onPrimary: Colors.white,
          surface: brandBlack,
          onSurface: const Color(0xFFF2F2F2),
          surfaceContainerLowest: const Color(0xFF080808),
          surfaceContainerLow: const Color(0xFF151515),
          surfaceContainer: const Color(0xFF1A1A1A),
          surfaceContainerHigh: const Color(0xFF212121),
          surfaceContainerHighest: const Color(0xFF2A2A2A),
        )
      : base.copyWith(primary: brandRed, onPrimary: Colors.white, onSurface: brandBlack);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(backgroundColor: scheme.surface, surfaceTintColor: Colors.transparent),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeSlideTransitionsBuilder()},
    ),
  );
}

class TrainLogApp extends StatelessWidget {
  const TrainLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Achm',
      // Крупный системный шрифт ограничиваем, чтобы подписи и кнопки не ломали вёрстку.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.15,
        child: LockGate(child: child ?? const SizedBox.shrink()),
      ),
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

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> with SingleTickerProviderStateMixin {
  String _current = 'journal';

  // Мягкое проявление вкладки при переключении (состояние вкладок сохраняется).
  late final _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 220), value: 1);

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(navTabsProvider);
    final tabs = [for (final t in navSections) if (t.fixed || enabled.contains(t.id)) t];
    var index = tabs.indexWhere((t) => t.id == _current);
    if (index < 0) index = 0;
    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: IndexedStack(
            index: index,
            children: [for (final t in tabs) KeyedSubtree(key: ValueKey(t.id), child: t.screen)],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        // Больше пяти разделов — только значки, без подписей.
        labelBehavior: tabs.length > 5
            ? NavigationDestinationLabelBehavior.alwaysHide
            : NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) {
          if (tabs[i].id == _current) return;
          setState(() => _current = tabs[i].id);
          _fade.forward(from: 0.25);
        },
        destinations: [
          for (final t in tabs) NavigationDestination(icon: Icon(t.icon), label: t.label, tooltip: t.title),
        ],
      ),
    );
  }
}

/// Раздел, который можно вынести в нижнее меню.
class NavSection {
  const NavSection(this.id, this.label, this.title, this.icon, this.screen, {this.fixed = false});
  final String id;
  final String label;
  final String title;
  final IconData icon;
  final Widget screen;

  /// Закреплённые разделы нельзя убрать из меню.
  final bool fixed;
}

const navSections = <NavSection>[
  NavSection('journal', 'Журнал', 'Журнал тренировок', Icons.fitness_center, TodayScreen(), fixed: true),
  NavSection('plan', 'План', 'Программы', Icons.calendar_month, ProgramsScreen()),
  NavSection('analytics', 'Анализ', 'Аналитика', Icons.show_chart, AnalyticsScreen()),
  NavSection('nutrition', 'Питание', 'Питание', Icons.restaurant, NutritionScreen()),
  NavSection('recs', 'Советы', 'Рекомендации', Icons.lightbulb_outline, RecommendationsScreen()),
  NavSection('exercises', 'Упражн.', 'Упражнения', Icons.list_alt, ExercisesScreen()),
  NavSection('more', 'Ещё', 'Ещё', Icons.menu, MoreScreen(), fixed: true),
];

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(navTabsProvider);
    return ListView(
      children: [
        for (final t in navSections)
          if (!t.fixed && !enabled.contains(t.id) && t.id != 'recs' && t.id != 'exercises')
            ListTile(
              leading: Icon(t.icon),
              title: Text(t.title),
              subtitle: const Text('Раздел скрыт из нижнего меню'),
              onTap: () => context.push('/section/${t.id}'),
            ),
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
          leading: const Icon(Icons.calculate_outlined),
          title: const Text('Калькулятор блинов'),
          subtitle: const Text('Какие диски повесить на гриф под нужный вес'),
          onTap: () => showPlateCalculator(
            context,
            weightKg: 100,
            step: ref.read(settingsProvider).value?.weightRoundingKg ?? 2.5,
          ),
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
