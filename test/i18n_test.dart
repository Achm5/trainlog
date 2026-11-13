import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trainlog/data/database.dart';
import 'package:trainlog/domain/planning.dart';
import 'package:trainlog/domain/plates.dart';
import 'package:trainlog/domain/program_templates.dart';
import 'package:trainlog/domain/rules.dart';
import 'package:trainlog/domain/strength.dart';
import 'package:trainlog/i18n.dart';
import 'package:trainlog/i18n_en.dart';

void main() {
  tearDown(() {
    I18n.lang = AppLang.ru;
    I18n.pounds = false;
  });

  test('русский по умолчанию: ключ и есть текст, аргументы подставляются', () {
    expect(tr('Неделя {0}', [3]), 'Неделя 3');
    expect(tr('{0} кг × {1}', ['100', 8]), '100 кг × 8');
    expect(trName('Жим лёжа'), 'Жим лёжа');
    expect(formatKg(102.5), '102,5');
  });

  test('английский: перевод, запасной вариант и названия из справочника', () {
    I18n.lang = AppLang.en;
    expect(tr('Неделя {0}', [3]), 'Week 3');
    expect(tr('Строка без перевода {0}', [1]), 'Строка без перевода 1');
    expect(tr('{0} кг × {1}', ['100', 8]), '100 kg × 8');
    expect(trName('Жим лёжа'), 'Bench press');
    expect(trName('Моё упражнение'), 'Моё упражнение');
    expect(trName('Понедельник'), 'Monday');
    expect(formatKg(102.5), '102.5');
    expect(SetStatus.failed.label, 'Failed');
    expect(LoadMode.linear.label, 'Linear step');
  });

  test('фунты: значения пересчитываются, «кг» в тексте меняется на lb', () {
    I18n.pounds = true;
    expect(formatKg(100), '220,5');
    expect(formatKg(45 * kgPerLb), '45');
    expect(tr('{0} кг × {1}', [formatKg(20 * kgPerLb), 5]), '20 lb × 5');
    expect(tr('Белок: {0} г/кг', ['1,8']), 'Белок: 1,8 г/кг'); // норма на килограмм массы остаётся
    expect(trKeepKg('Вес, кг'), 'Вес, кг');
    expect(weightFromDisplay(weightToDisplay(82.4)), closeTo(82.4, 1e-9));
    expect(formatTonnage(10000), '22,0 k lb');
    expect(roundingSteps.map(formatKg).toList(), ['1', '2,5', '5', '10']);
    expect(formatKg(defaultRoundingStep), '5');
    I18n.lang = AppLang.en;
    expect(tr('Вес: {0} кг', [formatKg(100)]), 'Weight: 220.5 lb');
  });

  test('фунты: шаг правил ложится на сетку 5 lb, блины считаются в фунтах', () {
    I18n.pounds = true;
    final step = defaultRoundingStep;
    final up = increasedWeight(weight: 225 * kgPerLb, pct: 0.025, step: step);
    expect(formatKg(up), '230');
    final down = reducedWeight(weight: 135 * kgPerLb, pct: 0.025, step: step);
    expect(formatKg(down), '130');
    final load = platesFor(targetKg: 225, barKg: 45, plates: const [45, 35, 25, 10, 5, 2.5])!;
    expect(load.perSide, {45.0: 2});
    expect(load.exact, isTrue);
  });

  test('в килограммах шаг правил прежний', () {
    expect(increasedWeight(weight: 100, pct: 0.025, step: 2.5), 102.5);
    expect(reducedWeight(weight: 60, pct: 0.025, step: 1), 57.5);
  });

  test('словарь: плейсхолдеры перевода совпадают с ключом, пустых переводов нет', () {
    final ph = RegExp(r'\{\d+\}');
    for (final e in enStrings.entries) {
      expect(e.value.trim(), isNotEmpty, reason: e.key);
      expect(ph.allMatches(e.value).map((m) => m[0]).toSet(), ph.allMatches(e.key).map((m) => m[0]).toSet(),
          reason: e.key);
    }
  });

  test('каждая простая строка tr(\'…\') из кода есть в словаре', () {
    final call = RegExp(r"\btr(?:KeepKg)?\('((?:[^'\\$]|\\.)*)'[,)]");
    final missing = <String>{};
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.contains('i18n')) continue;
      for (final m in call.allMatches(f.readAsStringSync())) {
        // Сравниваем как в исходнике: экранирование в словаре раскрыто компилятором.
        final key = m[1]!.replaceAll(r"\'", "'").replaceAll(r'\n', '\n').replaceAll(r'\"', '"');
        if (RegExp('[А-Яа-яЁё]').hasMatch(key) && !enStrings.containsKey(key)) missing.add(key);
      }
    }
    expect(missing, isEmpty);
  });

  test('названия справочника и готовых программ переведены', () async {
    final db = AppDatabase.memory();
    final names = <String>{
      for (final e in await db.select(db.exercises).get()) e.name,
      for (final m in await db.select(db.muscleGroups).get()) m.name,
      for (final e in await db.select(db.equipment).get()) e.name,
      for (final r in await db.select(db.rules).get()) r.name,
      for (final t in programTemplates) ...[t.name, t.description, for (final d in t.days) d.name],
    };
    expect(names.where((n) => !enNames.containsKey(n)).toList(), isEmpty);
    await db.close();
  });
}
