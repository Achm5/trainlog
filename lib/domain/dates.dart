/// Работа с датами в формате YYYY-MM-DD (как они хранятся в БД).
/// Все даты — «чистые» дни в UTC, чтобы переход на летнее время не сдвигал сутки.
library;

DateTime dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

DateTime today() => dateOnly(DateTime.now());

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseYmd(String s) {
  final p = s.split('-');
  return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

DateTime addDays(DateTime d, int days) => DateTime.utc(d.year, d.month, d.day + days);

int daysBetween(DateTime from, DateTime to) => dateOnly(to).difference(dateOnly(from)).inDays;

/// Понедельник недели, в которую попадает [d].
DateTime weekStart(DateTime d) => addDays(dateOnly(d), -(d.weekday - 1));

/// Ближайший понедельник: сегодня, если сегодня понедельник, иначе следующий.
DateTime nearestMonday(DateTime d) {
  final day = dateOnly(d);
  return day.weekday == DateTime.monday ? day : addDays(day, 8 - day.weekday);
}

/// Понедельники недель, которые нужно закрыть: все недели строго после
/// [lastClosedWeekStart] и строго до недели, в которую попадает [now].
/// Если [lastClosedWeekStart] == null, закрывается только прошлая неделя.
List<DateTime> weeksToClose(DateTime? lastClosedWeekStart, DateTime now) {
  final current = weekStart(now);
  var w = lastClosedWeekStart == null ? addDays(current, -7) : addDays(weekStart(lastClosedWeekStart), 7);
  final result = <DateTime>[];
  while (w.isBefore(current)) {
    result.add(w);
    w = addDays(w, 7);
  }
  return result;
}

const weekdayShort = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
const weekdayFull = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];

String ruDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
