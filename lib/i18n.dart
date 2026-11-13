/// Язык интерфейса и единицы веса. Чистый Dart: используется и в расчётах, и в экранах.
///
/// Строки в коде остаются русскими и служат ключами: `tr('Неделя {0} из {1}', [n, total])`.
/// Английский текст берётся из словаря [enStrings]; если перевода нет, показывается русский.
library;

import 'i18n_en.dart';

enum AppLang { ru, en }

/// Текущие настройки. Задаются при запуске и при смене в «Настройках».
class I18n {
  static AppLang lang = AppLang.ru;

  /// Веса показываются и вводятся в фунтах (в базе всегда килограммы).
  static bool pounds = false;
}

const kgPerLb = 0.45359237;

/// «кг» как отдельное слово; «г/кг», «ккал/кг» и т. п. не затрагиваются.
final _kgWord = RegExp(r'(?<![A-Za-zА-Яа-яЁё/])(кг|kg)(?![A-Za-zА-Яа-яЁё])');

/// Перевод строки интерфейса с подстановкой аргументов `{0}`, `{1}`…
/// При единицах «фунты» слово «кг» в тексте заменяется на «lb».
String tr(String key, [List<Object?> args = const []]) {
  final s = trKeepKg(key, args);
  return I18n.pounds ? s.replaceAll(_kgWord, 'lb') : s;
}

/// То же, но «кг» остаётся килограммами при любых единицах (выгрузка CSV, ккал на кг массы).
String trKeepKg(String key, [List<Object?> args = const []]) {
  var s = I18n.lang == AppLang.en ? (enStrings[key] ?? key) : key;
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i]}');
  }
  return s;
}

/// Перевод названия из справочника (упражнение, группа мышц, оборудование, правило, день недели).
/// Свои названия пользователя возвращаются как есть.
String trName(String name) => I18n.lang == AppLang.en ? (enNames[name] ?? enStrings[name] ?? name) : name;

/// Килограммы → единицы показа.
double weightToDisplay(double kg) => I18n.pounds ? kg / kgPerLb : kg;

/// Введённое значение → килограммы.
double weightFromDisplay(double value) => I18n.pounds ? value * kgPerLb : value;

String get weightUnit => I18n.pounds ? 'lb' : (I18n.lang == AppLang.en ? 'kg' : 'кг');

/// Десятичный разделитель: запятая в русском интерфейсе, точка в английском.
String get decSep => I18n.lang == AppLang.en ? '.' : ',';

/// Число в виде строки с точкой → с разделителем текущего языка.
String dec(String number) => decSep == '.' ? number : number.replaceAll('.', ',');
