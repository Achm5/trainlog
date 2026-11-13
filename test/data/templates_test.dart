import 'package:flutter_test/flutter_test.dart';
import 'package:trainlog/data/database.dart';
import 'package:trainlog/data/planner_repo.dart';
import 'package:trainlog/domain/program_templates.dart';

void main() {
  test('каждый шаблон создаёт черновик с упражнениями из справочника', () async {
    final db = AppDatabase.memory();
    final planner = PlannerRepo(db);
    expect(programTemplates.map((t) => t.id).toSet().length, programTemplates.length);
    for (final t in programTemplates) {
      final id = await planner.createFromTemplate(t, startDate: DateTime.utc(2026, 11, 16));
      final program = await (db.select(db.programs)..where((p) => p.id.equals(id))).getSingle();
      expect(program.status, 'draft');
      expect(program.name, t.name);
      final weeks = await planner.weeksOf(id);
      expect(weeks.length, t.weeks);
      expect(weeks.where((w) => w.isDeload).single.weekNo, t.weeks);
      final days = await planner.daysOf(id);
      expect(days.map((d) => d.name).toList(), [for (final d in t.days) d.name]);
      var count = 0;
      for (final d in days) {
        final items = await planner.dayExercises(d.id);
        count += items.length;
        for (final item in items) {
          final plans = await planner.plansOf(item.id);
          expect(plans.length, t.weeks);
          expect(plans.first.plan.weightKg, isNull);
          // Разгрузка строится из последней рабочей недели: подходов меньше.
          expect(plans.last.plan.sets, lessThanOrEqualTo(plans.first.plan.sets));
        }
      }
      expect(count, t.exercisesCount);
    }
    await db.close();
  });
}
