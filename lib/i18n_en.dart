/// Английские строки интерфейса. Ключ — русский текст из кода, значение — перевод.
/// Файл собирается скриптом из словаря; при добавлении строки в код добавьте сюда её перевод.
library;

const enStrings = <String, String>{
  'Раздел скрыт из нижнего меню':
      'Section hidden from the bottom bar',
  'Справочники и настройки':
      'Reference and settings',
  'Профиль и питание':
      'Profile and nutrition',
  'Пол, возраст, рост, активность, цель и БЖУ':
      'Sex, age, height, activity, goal and macros',
  'Упражнения':
      'Exercises',
  'Справочник, вариации, свои упражнения':
      'Library, variations, custom exercises',
  'Группы мышц':
      'Muscle groups',
  'Целевые коридоры подходов в неделю':
      'Weekly set targets',
  'Рекомендации':
      'Recommendations',
  'История решений и откат изменений плана':
      'Decision history and plan rollback',
  'Правила':
      'Rules',
  'Пороги, приоритеты и паузы движка рекомендаций':
      'Thresholds, priorities and cooldowns of the recommendation engine',
  'Калькулятор блинов':
      'Plate calculator',
  'Какие диски повесить на гриф под нужный вес':
      'Which plates to load for a target weight',
  'Данные и защита':
      'Data and security',
  'Резервная копия, импорт, CSV, PIN':
      'Backup, import, CSV, PIN',
  'Настройки':
      'Settings',
  'Параметры расчётов':
      'Calculation parameters',
  'Файл не является резервной копией приложения.':
      'This file is not an app backup.',
  'В файле нет таблиц приложения — это не резервная копия.':
      'The file has no app tables — it is not a backup.',
  'Копия сделана более новой версией приложения. Обновите приложение и повторите импорт.':
      'The backup was made by a newer app version. Update the app and import again.',
  'Не удалось прочитать резервную копию: {0}':
      'Could not read the backup: {0}',
  'Дата':
      'Date',
  'Сессия':
      'Session',
  'Упражнение':
      'Exercise',
  'Подход':
      'Set',
  'Разминка':
      'Warm-up',
  'План, кг':
      'Planned, kg',
  'План, повторы':
      'Planned reps',
  'Вес, кг':
      'Weight, kg',
  'Повторы':
      'Reps',
  'Статус':
      'Status',
  'Вес снижен':
      'Weight reduced',
  '1ПМ, кг':
      '1RM, kg',
  'Заметка':
      'Note',
  'да':
      'yes',
  'нет':
      'no',
  'Приём пищи':
      'Meal',
  'Продукт':
      'Food',
  'Граммы':
      'Grams',
  'Ккал':
      'Kcal',
  'Белки, г':
      'Protein, g',
  'Жиры, г':
      'Fat, g',
  'Углеводы, г':
      'Carbs, g',
  'Продукт удалён':
      'Food deleted',
  'В справочнике нет упражнения «{0}»':
      'Exercise “{0}” is not in the library',
  'Файл пуст':
      'The file is empty',
  'Нет колонки «{0}»':
      'Missing column “{0}”',
  'Не число в колонке «{0}»: {1}':
      'Not a number in column “{0}”: {1}',
  'В программе должно быть от 3 до 12 недель':
      'A program must have 3 to 12 weeks',
  'Импорт':
      'Import',
  'Пустое упражнение: {0}':
      'Empty exercise: {0}',
  '{0} (копия)':
      '{0} (copy)',
  'У упражнения нет вариаций':
      'This exercise has no variations',
  'Неизвестное действие: {0}':
      'Unknown action: {0}',
  'Пн':
      'Mon',
  'Вт':
      'Tue',
  'Ср':
      'Wed',
  'Чт':
      'Thu',
  'Пт':
      'Fri',
  'Сб':
      'Sat',
  'Вс':
      'Sun',
  'Понедельник':
      'Monday',
  'Вторник':
      'Tuesday',
  'Среда':
      'Wednesday',
  'Четверг':
      'Thursday',
  'Пятница':
      'Friday',
  'Суббота':
      'Saturday',
  'Воскресенье':
      'Sunday',
  'Сидячий образ жизни':
      'Sedentary',
  '1–3 тренировки в неделю':
      '1–3 workouts a week',
  '3–5 тренировок':
      '3–5 workouts',
  '6–7 тренировок':
      '6–7 workouts',
  'Физическая работа + тренировки':
      'Physical job + workouts',
  'Набор':
      'Gain',
  'Снижение жира':
      'Fat loss',
  'Удержание':
      'Maintain',
  'Завтрак':
      'Breakfast',
  'Обед':
      'Lunch',
  'Ужин':
      'Dinner',
  'Перекус':
      'Snack',
  'Расчётный 1ПМ снижается {0} нед. подряд в {1} из {2} упражнений: {3}{4}.':
      'Estimated 1RM has dropped {0} weeks in a row in {1} of {2} exercises: {3}{4}.',
  'Недоборы повторов: {0} подходов жёлтые и красные ({1} нед. подряд, порог {2}).':
      'Missed reps: {0} of sets were yellow or red ({1} weeks in a row, threshold {2}).',
  '{0} — {1} подх. при максимуме {2}':
      '{0} — {1} sets with a maximum of {2}',
  'Объём выше коридора больше чем на {0}: {1}.':
      'Volume above the target range by more than {0}: {1}.',
  '{0} нед. тренировок подряд без разгрузки и отдыха.':
      '{0} weeks of training in a row without a deload or rest.',
  'только гриф':
      'bar only',
  'За выбранный период нет завершённых тренировок. Графики появятся после первой сессии.':
      'No completed workouts in this period. Charts appear after the first session.',
  'Сила без заметных изменений за период.':
      'No noticeable strength change over the period.',
  ', снижаются: {0}':
      ', declining: {0}',
  ' Лучший рост — {0} ({1}).':
      ' Best gain — {0} ({1}).',
  'Растут: {0} из {1} упражнений{2}.{3}':
      'Improving: {0} of {1} exercises{2}.{3}',
  'Расчётный максимум (1ПМ) по неделям, кг':
      'Estimated max (1RM) by week, kg',
  'Линия вверх — становитесь сильнее. Серые полосы — недели разгрузки.':
      'Line going up means you are getting stronger. Grey bands are deload weeks.',
  'Упражнения — нажмите, чтобы показать на графике':
      'Exercises — tap to show on the chart',
  ' · к прошлой неделе {0}':
      ' · vs last week {0}',
  '{0} кг{1}':
      '{0} kg{1}',
  'Изменение за неделю: {0}':
      'Weekly change: {0}',
  'Столбец вверх (зелёный) — 1ПМ вырос к прошлой неделе, вниз (красный) — просел, %.':
      'Bar up (green) — 1RM rose vs the previous week, down (red) — it dropped, %.',
  'Нет данных об объёме за период. Они появятся после завершённой тренировки.':
      'No volume data for the period. It appears after a completed workout.',
  'Неделя с {0}: в целевом коридоре {1} из {2} групп, ниже — {3}, выше — {4}.':
      'Week of {0}: {1} of {2} groups in the target range, below — {3}, above — {4}.',
  'Рабочие подходы за неделю по группам мышц':
      'Working sets per week by muscle group',
  'Светлая зона — целевой коридор. Нажмите на группу, чтобы увидеть её динамику.':
      'Light zone is the target range. Tap a group to see its trend.',
  'в коридоре':
      'in range',
  'ниже цели':
      'below target',
  'выше цели':
      'above target',
  '{0}: подходы по неделям':
      '{0}: sets by week',
  'Пунктир — коридор {0}–{1} подходов.':
      'Dashed lines — target range of {0}–{1} sets.',
  'Нет подходов по плану за период. Свободные тренировки сюда не попадают.':
      'No planned sets in this period. Free workouts are not counted here.',
  'По плану выполнено {0} подходов из {1}; частично — {2}, провалено — {3}.':
      'Completed {0} of {1} planned sets; partial — {2}, failed — {3}.',
  'выполнено: {0}':
      'done: {0}',
  'частично (недобор 3–5): {0}':
      'partial (3–5 reps short): {0}',
  'провал (недобор 6+): {0}':
      'failed (6+ reps short): {0}',
  'Доля подходов по статусам по неделям, %':
      'Share of sets by status per week, %',
  'Чем больше зелёного, тем точнее план попадает в ваши силы.':
      'The more green, the better the plan matches your strength.',
  'Запишите вес хотя бы два раза на вкладке «Питание» — здесь появится график с трендом.':
      'Log your weight at least twice on the Nutrition tab — a trend chart will appear here.',
  'Вес стабилен: тренд {0} кг.':
      'Weight is stable: trend {0} kg.',
  'вырос':
      'rose',
  'снизился':
      'dropped',
  'Тренд веса {0} на {1} кг за период и сейчас {2} кг.':
      'Weight trend {0} by {1} kg over the period and is now {2} kg.',
  'Вес тела, кг':
      'Body weight, kg',
  'Точки — взвешивания, линия — сглаженный тренд без суточных колебаний.':
      'Dots are weigh-ins, the line is a smoothed trend without daily swings.',
  'Последнее взвешивание: {0} кг ({1}). Взвешиваний за период: {2}.':
      'Last weigh-in: {0} kg ({1}). Weigh-ins in the period: {2}.',
  'Аналитика':
      'Analytics',
  'PDF-отчёт за мезоцикл':
      'Mesocycle PDF report',
  'Тренировок':
      'Workouts',
  'План':
      'Plan',
  'Сила растёт':
      'Strength up',
  'Вес':
      'Weight',
  'Сила':
      'Strength',
  'Объём':
      'Volume',
  'Выберите упражнение':
      'Choose an exercise',
  'Ошибка: {0}':
      'Error: {0}',
  'Да':
      'Yes',
  'Отмена':
      'Cancel',
  'Сохранить':
      'Save',
  '{0} мин':
      '{0} min',
  '{0} ч {1} мин':
      '{0} h {1} min',
  'Резервная копия Achm':
      'Achm backup',
  'Сохранить резервную копию':
      'Save backup',
  'Копия сохранена':
      'Backup saved',
  'Заменить все данные?':
      'Replace all data?',
  'Текущие программы, журнал и дневник будут заменены содержимым файла «{0}». Отменить это нельзя — сначала сделайте копию текущих данных.':
      'Current programs, journal and diary will be replaced with the contents of “{0}”. This cannot be undone — back up your current data first.',
  'Заменить':
      'Replace',
  'Данные восстановлены из копии':
      'Data restored from backup',
  'Новый PIN (4–8 цифр)':
      'New PIN (4–8 digits)',
  'PIN — от 4 до 8 цифр':
      'PIN must be 4 to 8 digits',
  'Повторите PIN':
      'Repeat PIN',
  'PIN не совпадает':
      'PINs do not match',
  'PIN установлен':
      'PIN is set',
  'Текущий PIN':
      'Current PIN',
  'Неверный PIN':
      'Wrong PIN',
  'Резервная копия':
      'Backup',
  'Копий ещё не было':
      'No backups yet',
  'Последняя копия: {0}':
      'Last backup: {0}',
  'Все данные хранятся только на телефоне. Без копии они пропадут при потере телефона или удалении приложения.':
      'All data is stored only on this phone. Without a backup it is lost if the phone is lost or the app is removed.',
  'Поделиться копией базы':
      'Share database backup',
  'Файл .sqlite — в облако, мессенджер или на почту':
      '.sqlite file — to cloud, messenger or email',
  'Сохранить копию в файл':
      'Save backup to a file',
  'Например, в «Загрузки»':
      'For example, to Downloads',
  'Восстановить из копии':
      'Restore from backup',
  'Импорт файла с заменой всех данных':
      'Import a file, replacing all data',
  'Выгрузка в CSV':
      'CSV export',
  'Журнал тренировок':
      'Workout journal',
  'Строка на подход':
      'One row per set',
  'Дневник питания':
      'Food diary',
  'Строка на запись':
      'One row per entry',
  'Защита':
      'Security',
  'Установить PIN':
      'Set a PIN',
  'Запрашивается при запуске приложения':
      'Asked when the app starts',
  'Нажмите, чтобы отключить':
      'Tap to turn off',
  'Вход по биометрии':
      'Biometric unlock',
  'Отпечаток или лицо вместо PIN':
      'Fingerprint or face instead of PIN',
  'На устройстве не настроена биометрия':
      'Biometrics are not set up on this device',
  'PIN не шифрует базу и не восстанавливается: если забыли его, переустановите приложение и восстановите данные из резервной копии.':
      'The PIN does not encrypt the database and cannot be recovered: if you forget it, reinstall the app and restore your data from a backup.',
  'Пора сделать резервную копию':
      'Time to back up',
  'Копии не было больше недели':
      'No backup for more than a week',
  'Позже':
      'Later',
  'Сделать':
      'Back up',
  'Введите PIN':
      'Enter PIN',
  'Биометрия':
      'Biometrics',
  'Готово':
      'Done',
  'Блины на штангу':
      'Barbell plates',
  '{0} кг':
      '{0} kg',
  'Гриф':
      'Bar',
  'Вес меньше грифа ({0} кг).':
      'Weight is less than the bar ({0} kg).',
  'На каждую сторону':
      'Per side',
  'Стандартными дисками точно не набрать: получится {0} кг, не хватает {1} кг на сторону.':
      'Cannot be loaded exactly with standard plates: you get {0} kg, {1} kg short per side.',
  'Завершить тренировку?':
      'Finish workout?',
  'Невыполненных подходов: {0}. Они будут отмечены как пропущенные.':
      'Unfinished sets: {0}. They will be marked as skipped.',
  'Завершить':
      'Finish',
  'Тренировка завершена · {0}':
      'Workout finished · {0}',
  'Тренировка':
      'Workout',
  'Заметка к тренировке':
      'Workout note',
  'Удалить тренировку?':
      'Delete workout?',
  'Все подходы этой сессии будут удалены.':
      'All sets of this session will be deleted.',
  'Добавить упражнение':
      'Add exercise',
  'Удалить тренировку':
      'Delete workout',
  'Заметка: {0}':
      'Note: {0}',
  'Завершить тренировку':
      'Finish workout',
  'Все подходы выполнены':
      'All sets done',
  'Откройте приложение, чтобы завершить тренировку':
      'Open the app to finish the workout',
  '{0} повт.':
      '{0} reps',
  '{0} кг × {1}':
      '{0} kg × {1}',
  'Отдых · дальше {0}':
      'Rest · next {0}',
  'Подход {0} из {1}':
      'Set {0} of {1}',
  'Подходы {0} из {1}':
      'Sets {0} of {1}',
  'План: {0} × {1}–{2} · {3} кг · RIR {4}':
      'Plan: {0} × {1}–{2} · {3} kg · RIR {4}',
  'Прошлый раз ({0}): {1}':
      'Last time ({0}): {1}',
  'Убрать упражнение из тренировки?':
      'Remove exercise from workout?',
  'Добавить подход':
      'Add set',
  'Добавить разминочный подход':
      'Add warm-up set',
  'Убрать упражнение':
      'Remove exercise',
  'Р':
      'W',
  '{0} кг × {1}{2}':
      '{0} kg × {1}{2}',
  'Пропущен':
      'Skipped',
  'Разминочный подход':
      'Warm-up set',
  'Подход без плана':
      'Set without a plan',
  'рекорд 1ПМ {0} кг':
      '1RM record {0} kg',
  'разминка':
      'warm-up',
  'вес снижен':
      'weight reduced',
  'По плану':
      'As planned',
  'Ввести':
      'Enter',
  'План: {0} кг × {1}':
      'Plan: {0} kg × {1}',
  'RIR — повторов в запасе':
      'RIR — reps in reserve',
  'Не идёт в аналитику':
      'Not counted in analytics',
  'Заметка к подходу':
      'Set note',
  'Сохранить подход':
      'Save set',
  'Пропустить':
      'Skip',
  'Сбросить':
      'Reset',
  'Удалить подход':
      'Delete set',
  'Отдых окончен':
      'Rest is over',
  'Отдых: {0}:{1}':
      'Rest: {0}:{1}',
  '+30 с':
      '+30 s',
  'Закрыть':
      'Close',
  'Стоп':
      'Stop',
  'Журнал · {0}, {1}':
      'Journal · {0}, {1}',
  'Незавершённая тренировка':
      'Unfinished workout',
  'Начата {0}':
      'Started {0}',
  'Продолжить':
      'Continue',
  'Нет активной программы':
      'No active program',
  'Создайте программу на вкладке «План» и сделайте её активной — тренировки дня будут предзаполняться из плана.':
      'Create a program on the Plan tab and make it active — daily workouts will be pre-filled from the plan.',
  'Цикл начнётся {0}':
      'The cycle starts {0}',
  'Цикл завершён. Создайте следующую программу на вкладке «План».':
      'The cycle is over. Create the next program on the Plan tab.',
  ' · разгрузка':
      ' · deload',
  '{0} · неделя {1} из {2}{3}':
      '{0} · week {1} of {2}{3}',
  'Сегодня':
      'Today',
  'Открыть':
      'Open',
  'Начать':
      'Start',
  'Свободная тренировка':
      'Free workout',
  'История':
      'History',
  'Тренировок пока нет':
      'No workouts yet',
  'не завершена':
      'not finished',
  'Возможна перетренированность':
      'Possible overtraining',
  'Неделя с {0}: совпало признаков — {1}.':
      'Week of {0}: signs matched — {1}.',
  'Стоит подумать о разгрузочной неделе, сне и питании. Это ориентир по журналу, а не медицинская оценка.':
      'Consider a deload week, sleep and nutrition. This is a guide based on your journal, not a medical assessment.',
  'Скрыть до следующей недели':
      'Hide until next week',
  'Отключить':
      'Turn off',
  'Новый рекорд!':
      'New record!',
  'Расчётный 1ПМ: {0} кг':
      'Estimated 1RM: {0} kg',
  'Вес {0}, кг':
      'Weight {0}, kg',
  'Съедено: {0} ккал':
      'Eaten: {0} kcal',
  'Б {0} · Ж {1} · У {2} г':
      'P {0} · F {1} · C {2} g',
  'Норма не рассчитана: заполните профиль (пол, дата рождения, рост) и запишите вес.':
      'Target not calculated: fill in your profile (sex, date of birth, height) and log your weight.',
  'Заполнить профиль':
      'Fill in profile',
  ' / {0} ккал':
      ' / {0} kcal',
  'осталось {0}':
      '{0} left',
  'сверх нормы {0}':
      '{0} over target',
  'Белки':
      'Protein',
  'Жиры':
      'Fat',
  'Углеводы':
      'Carbs',
  'адаптивный':
      'adaptive',
  'по формуле':
      'formula',
  'Расход {0} ккал ({1}) · базовый обмен {2}':
      'Expenditure {0} kcal ({1}) · BMR {2}',
  'Вес не записан':
      'Weight not logged',
  'Вес: {0} кг':
      'Weight: {0} kg',
  'Взвешивайтесь утром — по тренду считается расход':
      'Weigh in the morning — expenditure is calculated from the trend',
  'Тренд: {0} кг':
      'Trend: {0} kg',
  'Записать вес':
      'Log weight',
  'Вода: {0} мл':
      'Water: {0} ml',
  'Вода: {0} / {1} мл':
      'Water: {0} / {1} ml',
  'Отменить последнюю запись':
      'Undo last entry',
  'Запишите вес — рассчитаю дневную норму.':
      'Log your weight and I will calculate the daily target.',
  '+{0} мл':
      '+{0} ml',
  'Другое':
      'Other',
  'Сколько выпито, мл':
      'How much, ml',
  'мл':
      'ml',
  '{0} / {1} г':
      '{0} / {1} g',
  '{0} ккал':
      '{0} kcal',
  'Скопировать со вчера':
      'Copy from yesterday',
  'Вчера этот приём пищи пуст':
      'This meal was empty yesterday',
  'Скопировано записей: {0}':
      'Entries copied: {0}',
  'Добавить продукт':
      'Add food',
  '{0} г · Б {1} Ж {2} У {3}':
      '{0} g · P {1} F {2} C {3}',
  'г':
      'g',
  'Введите название':
      'Enter a name',
  'Укажите калорийность на 100 г':
      'Enter calories per 100 g',
  'Новый продукт':
      'New food',
  'Избранное':
      'Favorite',
  'Удалить':
      'Delete',
  'Удалить продукт?':
      'Delete food?',
  'Записи дневника с ним сохранятся.':
      'Diary entries with it will remain.',
  'Продукт входит в рецепт — сначала уберите его из рецепта':
      'The food is part of a recipe — remove it from the recipe first',
  'Название':
      'Name',
  'Марка (необязательно)':
      'Brand (optional)',
  'Штрихкод (необязательно)':
      'Barcode (optional)',
  'На 100 г':
      'Per 100 g',
  '\nЗагружено: {0}.':
      '\nLoaded: {0}.',
  'Источник данных: Open Food Facts (openfoodfacts.org), код {0}. База распространяется по лицензии Open Database License (ODbL).{1}':
      'Data source: Open Food Facts (openfoodfacts.org), code {0}. The database is distributed under the Open Database License (ODbL).{1}',
  'Правка продукта не меняет уже сделанные записи дневника: в них хранится снимок КБЖУ.':
      'Editing a food does not change existing diary entries: they store a snapshot of its nutrition.',
  '{0}: сколько граммов?':
      '{0}: how many grams?',
  'Добавлено: {0}, {1} г':
      'Added: {0}, {1} g',
  'Введите название продукта':
      'Enter the food name',
  'В карточке Open Food Facts нет калорий — заполните продукт вручную':
      'The Open Food Facts card has no calories — fill in the food manually',
  'Штрихкод {0} не найден — добавьте продукт вручную':
      'Barcode {0} not found — add the food manually',
  '{0} ккал · Б {1} Ж {2} У {3} на 100 г':
      '{0} kcal · P {1} F {2} C {3} per 100 g',
  'Сканировать штрихкод':
      'Scan barcode',
  'Новый продукт вручную':
      'New food manually',
  'Новый рецепт':
      'New recipe',
  'Название продукта':
      'Food name',
  'Недавние':
      'Recent',
  'Избранное и сохранённые':
      'Favorites and saved',
  'Сохранённые продукты':
      'Saved foods',
  'Сохранённых продуктов не найдено':
      'No saved foods found',
  'Ищу…':
      'Searching…',
  'Искать в Open Food Facts':
      'Search Open Food Facts',
  'Ничего не найдено (карточки без калорий не показываются). Добавьте продукт вручную.':
      'Nothing found (cards without calories are hidden). Add the food manually.',
  'Данные: Open Food Facts (openfoodfacts.org), лицензия Open Database License (ODbL).':
      'Data: Open Food Facts (openfoodfacts.org), Open Database License (ODbL).',
  'Наведите камеру на штрихкод':
      'Point the camera at the barcode',
  'Имя':
      'Name',
  'не указано':
      'not set',
  'Пол':
      'Sex',
  'Муж.':
      'Male',
  'Жен.':
      'Female',
  'Дата рождения':
      'Date of birth',
  'не указана':
      'not set',
  'Рост':
      'Height',
  'не указан':
      'not set',
  '{0} см':
      '{0} cm',
  'Рост, см':
      'Height, cm',
  'Активность':
      'Activity',
  'Поправка на цель: {0}{1}%':
      'Goal adjustment: {0}{1}%',
  'Белок: {0} г/кг':
      'Protein: {0} g/kg',
  'Жиры, не менее':
      'Fat, at least',
  '{0} г/кг':
      '{0} g/kg',
  'Жиры, г/кг (не менее 0,8)':
      'Fat, g/kg (at least 0.8)',
  'Калорий в 1 кг массы':
      'Calories per 1 kg of body mass',
  'Приближённая константа для адаптивного расхода':
      'Approximate constant for adaptive expenditure',
  'ккал на 1 кг':
      'kcal per 1 kg',
  'Норма появится, когда будут указаны дата рождения и рост и записан вес на вкладке «Питание».':
      'The target appears once date of birth and height are set and weight is logged on the Nutrition tab.',
  'Текущая норма: {0} ккал':
      'Current target: {0} kcal',
  'Белки {0} г · жиры {1} г · углеводы {2} г':
      'Protein {0} g · fat {1} g · carbs {2} g',
  'Базовый обмен {0} · расход {1} ккал ({2}) · действует с {3}':
      'BMR {0} · expenditure {1} kcal ({2}) · effective from {3}',
  'Норма поднята до базового обмена: ниже него калорийность не опускается.':
      'Target raised to BMR: calories never go below it.',
  'Сбросить расход к формульному':
      'Reset expenditure to the formula',
  'Приложение не даёт медицинских рекомендаций.':
      'The app does not give medical advice.',
  '{0}: граммы':
      '{0}: grams',
  'Введите название рецепта':
      'Enter the recipe name',
  'Добавьте хотя бы один ингредиент':
      'Add at least one ingredient',
  'Рецепт':
      'Recipe',
  'Название рецепта':
      'Recipe name',
  'Ингредиенты':
      'Ingredients',
  '{0} г · {1} ккал':
      '{0} g · {1} kcal',
  'Добавить ингредиент':
      'Add ingredient',
  'Общий вес: {0} г\nНа 100 г: {1} ккал · Б {2} · Ж {3} · У {4}':
      'Total weight: {0} g\nPer 100 g: {1} kcal · P {2} · F {3} · C {4}',
  'Сохранить рецепт':
      'Save recipe',
  'Вес рецепта считается как сумма ингредиентов. Если поправить продукт-ингредиент, откройте и сохраните рецепт заново, чтобы пересчитать его КБЖУ.':
      'Recipe weight is the sum of its ingredients. If you edit an ingredient food, open and save the recipe again to recalculate its nutrition.',
  'Ингредиент':
      'Ingredient',
  'Нет сохранённых продуктов. Сначала добавьте продукты вручную или из Open Food Facts.':
      'No saved foods. Add foods manually or from Open Food Facts first.',
  '{0} ккал на 100 г':
      '{0} kcal per 100 g',
  'Подходы (все рабочие недели)':
      'Sets (all working weeks)',
  'Повторы: нижняя граница':
      'Reps: lower bound',
  'Повторы: верхняя граница':
      'Reps: upper bound',
  'Целевой RIR (0–5)':
      'Target RIR (0–5)',
  'Задать для всех недель':
      'Apply to all weeks',
  'Способ задания веса':
      'Load mode',
  'Стартовый вес':
      'Starting weight',
  'Стартовый вес, кг':
      'Starting weight, kg',
  'Шаг в неделю':
      'Weekly step',
  '+{0} кг':
      '+{0} kg',
  'Прибавка в неделю, кг':
      'Weekly increase, kg',
  'Расчётного 1ПМ пока нет: веса появятся после первой завершённой тренировки с этим упражнением.':
      'No estimated 1RM yet: weights appear after the first completed workout with this exercise.',
  'Отдых между подходами':
      'Rest between sets',
  '{0} с':
      '{0} s',
  'Отдых, с':
      'Rest, s',
  'Изменения сохраняются сразу. Веса округляются вниз до шага округления. Вес, исправленный вручную, не пересчитывается, пока не нажать «Сбросить».':
      'Changes are saved immediately. Weights are rounded down to the rounding step. A manually edited weight is not recalculated until you tap Reset.',
  'Неделя {0} · {1}{2}':
      'Week {0} · {1}{2}',
  'Подходы':
      'Sets',
  '% от 1ПМ':
      '% of 1RM',
  'Процент от расчётного 1ПМ':
      'Percent of estimated 1RM',
  'Вес (вручную)':
      'Weight (manual)',
  'Целевой вес, кг':
      'Target weight, kg',
  'Мезоцикл':
      'Mesocycle',
  'Выберите хотя бы один день недели':
      'Choose at least one weekday',
  'Новая программа':
      'New program',
  'Параметры программы':
      'Program settings',
  'Дни недели':
      'Weekdays',
  'Лимит времени на тренировку: {0} мин':
      'Workout time limit: {0} min',
  'Длина мезоцикла: {0} нед.':
      'Mesocycle length: {0} weeks',
  'Неделя разгрузки':
      'Deload week',
  'Нет':
      'None',
  'Неделя {0} (последняя)':
      'Week {0} (last)',
  'Неделя {0}':
      'Week {0}',
  'Шаг округления веса':
      'Weight rounding step',
  'Стартовая дата':
      'Start date',
  '{0} · неделя с {1}':
      '{0} · week of {1}',
  'Разгрузка':
      'Deload',
  'Подходы × {0} (округление вверх, не меньше 1)':
      'Sets × {0} (rounded up, at least 1)',
  'Вес × {0}':
      'Weight × {0}',
  'Целевой RIR +{0}':
      'Target RIR +{0}',
  'Создать программу':
      'Create program',
  'Программа активна':
      'Program is active',
  'Копия программы: прибавить к весам, кг':
      'Program copy: add to weights, kg',
  'Копия создана, старт {0}. Веса можно поправить в упражнениях.':
      'Copy created, starts {0}. Weights can be adjusted in the exercises.',
  'Удалить программу?':
      'Delete program?',
  'План будет удалён. Записи журнала сохранятся, но потеряют связь с планом.':
      'The plan will be deleted. Journal entries remain but lose their link to the plan.',
  'Сделать активной':
      'Make active',
  'В архив':
      'Archive',
  'PDF-отчёт для тренера':
      'PDF report for coach',
  'Создать копию':
      'Create a copy',
  'Неделя {0} · с {1}{2}':
      'Week {0} · from {1}{2}',
  'В программе один тренировочный день':
      'The program has only one training day',
  'Перенести «{0}»':
      'Move “{0}”',
  'Скопировать «{0}» в день':
      'Copy “{0}” to day',
  'В дне «{0}» уже есть упражнения':
      'Day “{0}” already has exercises',
  'Заменить их копией или добавить копию в конец списка?':
      'Replace them with the copy or append the copy to the end?',
  'Добавить':
      'Append',
  'Скопировано упражнений: {0} → {1}':
      'Exercises copied: {0} → {1}',
  'Расчётная длительность: {0} из {1} мин':
      'Estimated duration: {0} of {1} min',
  'Превышен лимит времени на {0}':
      'Time limit exceeded by {0}',
  'Убрать подход: {0}':
      'Remove a set: {0}',
  'Сократить отдых на 30 с':
      'Shorten rest by 30 s',
  'Перенести упражнение':
      'Move exercise',
  'В этом дне пока нет упражнений':
      'No exercises in this day yet',
  'Нет плана на эту неделю':
      'No plan for this week',
  '{0} × {1}–{2} · {3} кг · RIR {4} · отдых {5} с':
      '{0} × {1}–{2} · {3} kg · RIR {4} · rest {5} s',
  'Убрать упражнение из дня?':
      'Remove exercise from the day?',
  'Перенести в другой день':
      'Move to another day',
  'Убрать из дня':
      'Remove from day',
  'Скопировать день в другой':
      'Copy day to another',
  'Черновик':
      'Draft',
  'Активная':
      'Active',
  'Архив':
      'Archived',
  'Готовые программы':
      'Ready-made programs',
  'Создаётся черновик: упражнения, подходы и повторы уже расставлены, последняя неделя — разгрузка. Веса и дни недели можно поменять.':
      'A draft is created: exercises, sets and reps are already laid out, the last week is a deload. Weights and weekdays can be changed.',
  '{0}\n{1} нед. · {2} упражнений':
      '{0}\n{1} weeks · {2} exercises',
  'Черновик создан. Задайте веса и сделайте программу активной.':
      'Draft created. Set the weights and make the program active.',
  'Не удалось создать программу: {0}':
      'Could not create the program: {0}',
  'Программы':
      'Programs',
  'Импорт программы из CSV':
      'Import program from CSV',
  'Программа импортирована как черновик':
      'Program imported as a draft',
  'Не удалось импортировать: {0}':
      'Import failed: {0}',
  'Программа':
      'Program',
  'Программ пока нет. Возьмите готовую и поправьте под себя или соберите мезоцикл с нуля: дни недели, упражнения и прогрессию по неделям.':
      'No programs yet. Take a ready-made one and adjust it, or build a mesocycle from scratch: weekdays, exercises and weekly progression.',
  '{0} · {1} нед. · с {2}':
      '{0} · {1} weeks · from {2}',
  ' (недобор повторов в последней: {0})':
      ' (reps short in the last one: {0})',
  'сделан верх диапазона повторов во всех рабочих подходах':
      'top of the rep range hit in every working set',
  'запас RIR не меньше {0} сверх целевого':
      'RIR at least {0} above target',
  'Последние {0} сессии «{1}» выполнены частично{2}. Предлагается оставить вес и снизить повторы: {3}–{4} → {5}–{6} во всех следующих неделях.':
      'The last {0} sessions of “{1}” were partial{2}. Suggested: keep the weight and lower the reps: {3}–{4} → {5}–{6} in all following weeks.',
  'Расчётный 1ПМ «{0}» не вырос на {1}% за {2} нед. подряд ({3} кг, разгрузки не учитываются). На выбор: сменить вариацию или добавить подход в неделю.':
      'Estimated 1RM of “{0}” has not grown by {1}% for {2} weeks in a row ({3} kg, deloads excluded). Options: change the variation or add a set per week.',
  'Без роста 1ПМ {0} нед.: {1} ({2} из {3} базовых упражнений).':
      'No 1RM growth for {0} weeks: {1} ({2} of {3} compound exercises).',
  'Жёлтых и красных подходов за неделю: {0} ({1} из {2}).':
      'Yellow and red sets this week: {0} ({1} of {2}).',
  '{0} Предлагается поставить разгрузку на неделю {1}, остаток цикла сдвинется.':
      '{0} Suggested: move the deload to week {1}; the rest of the cycle shifts.',
  'Новая':
      'New',
  'Принята':
      'Accepted',
  'Отклонена':
      'Rejected',
  'Истекла':
      'Expired',
  'Не удалось применить: {0}':
      'Could not apply: {0}',
  'Сменить вариацию на':
      'Change variation to',
  'Вариация изменена':
      'Variation changed',
  'Сменить вариацию':
      'Change variation',
  'Подход добавлен в план':
      'Set added to the plan',
  '+1 подход':
      '+1 set',
  'Изменения записаны в план':
      'Changes written to the plan',
  'Принять':
      'Accept',
  'Отклонить':
      'Reject',
  'Откатить изменения':
      'Roll back changes',
  'Откатить рекомендацию?':
      'Roll back the recommendation?',
  'План вернётся к прежним значениям.':
      'The plan returns to its previous values.',
  'План возвращён':
      'Plan restored',
  'Рекомендаций пока нет. Правила проверяются после каждой завершённой тренировки и при закрытии недели.':
      'No recommendations yet. Rules are checked after every finished workout and when a week closes.',
  'Условие (JSON)':
      'Condition (JSON)',
  'Действие (JSON)':
      'Action (JSON)',
  'Некорректный JSON: нужен объект с полем "type"':
      'Invalid JSON: an object with a "type" field is required',
  '{0} · приоритет {1} · пауза {2} дн.':
      '{0} · priority {1} · cooldown {2} d',
  'Приоритет':
      'Priority',
  'Пауза перед повторным срабатыванием':
      'Cooldown before firing again',
  '{0} дн.':
      '{0} d',
  'Пауза, дней':
      'Cooldown, days',
  'Условие':
      'Condition',
  'Действие':
      'Action',
  'Укажите хотя бы одну группу мышц':
      'Choose at least one muscle group',
  'У основной группы мышц доля должна быть 1,0':
      'The primary muscle group must have a share of 1.0',
  'Удалить упражнение?':
      'Delete exercise?',
  'Если упражнение есть в журнале или программах, оно будет перенесено в архив.':
      'If the exercise is used in the journal or programs, it will be archived instead.',
  'Упражнение удалено':
      'Exercise deleted',
  'Упражнение используется — перенесено в архив':
      'Exercise is in use — moved to archive',
  'Новое упражнение':
      'New exercise',
  'Вернуть из архива':
      'Restore from archive',
  'Базовое':
      'Compound',
  'Изолирующее':
      'Isolation',
  'Оборудование':
      'Equipment',
  'Не указано':
      'Not set',
  'Базовое движение':
      'Base movement',
  'Заполните, если это вариация другого упражнения':
      'Fill in if this is a variation of another exercise',
  'Это базовое движение':
      'This is a base movement',
  'Группы мышц и доли':
      'Muscle groups and shares',
  'Основная группа — 1,0; вторичные — 0,25–0,75.':
      'Primary group — 1.0; secondary — 0.25–0.75.',
  'Выбор упражнения':
      'Choose exercise',
  'Скрыть архивные':
      'Hide archived',
  'Показать архивные':
      'Show archived',
  'Своё упражнение':
      'Custom exercise',
  'Поиск по названию':
      'Search by name',
  'Группа мышц':
      'Muscle group',
  'Тип':
      'Type',
  'Ничего не найдено':
      'Nothing found',
  ' (в архиве)':
      ' (archived)',
  'Все · {0}':
      'All · {0}',
  'Коридор: {0}–{1} подходов в неделю':
      'Range: {0}–{1} sets per week',
  'Цель: {0}–{1} подходов в неделю':
      'Target: {0}–{1} sets per week',
  'Готовлю отчёт…':
      'Preparing the report…',
  'Отчёт за мезоцикл «{0}»':
      'Mesocycle report “{0}”',
  'Не удалось сформировать отчёт: {0}':
      'Could not build the report: {0}',
  'Отправить тренеру':
      'Send to coach',
  'Мессенджер, почта, облако':
      'Messenger, email, cloud',
  'Сохранить в файл':
      'Save to a file',
  'Сохранить отчёт':
      'Save report',
  'Отчёт сохранён':
      'Report saved',
  'Нижнее меню':
      'Bottom bar',
  '«Журнал» и «Ещё» закреплены. Скрытые разделы открываются из «Ещё». Если разделов больше пяти, в меню остаются только значки.':
      'Journal and More are pinned. Hidden sections open from More. With more than five sections the bar shows icons only.',
  'Уведомления и предупреждения':
      'Notifications and warnings',
  'Ход тренировки на экране блокировки':
      'Workout progress on the lock screen',
  'Постоянное уведомление во время тренировки: следующий подход и отсчёт отдыха':
      'Ongoing notification during a workout: next set and rest countdown',
  'Предупреждать о перетренированности':
      'Warn about overtraining',
  'Карточка в «Журнале» после закрытия недели, если совпало два признака и больше: падение 1ПМ, много недоборов, скачок тоннажа, объём выше коридора, 6+ недель без разгрузки':
      'A card in the Journal after a week closes if two or more signs match: 1RM drop, many missed reps, tonnage spike, volume above range, 6+ weeks without a deload',
  'Расчёты тренировок':
      'Workout calculations',
  'Целевые веса плана округляются вниз до шага':
      'Planned weights are rounded down to the step',
  'Учитывать RIR в расчётном 1ПМ':
      'Use RIR in estimated 1RM',
  'В формулу Эпли подставляется «повторы + RIR»':
      'The Epley formula uses “reps + RIR”',
  'Расчётный 1ПМ пересчитан':
      'Estimated 1RM recalculated',
  'Время одного подхода':
      'Time per set',
  'Для расчёта длительности тренировки':
      'Used to estimate workout duration',
  'Время подхода, с':
      'Time per set, s',
  'Добавляется к длительности каждого дня':
      'Added to the duration of every day',
  'Разминка, мин':
      'Warm-up, min',
  'Закрытие недели не выполнено: {0}':
      'Week closing failed: {0}',
  'База открывается в main()':
      'The database is opened in main()',
  'Отчёт за мезоцикл — {0}':
      'Mesocycle report — {0}',
  '{0} — {1} · {2} нед.':
      '{0} — {1} · {2} weeks',
  'Отчёт за мезоцикл':
      'Mesocycle report',
  'Спортсмен: {0}':
      'Athlete: {0}',
  'Отчёт за мезоцикл · {0}':
      'Mesocycle report · {0}',
  'Achm · сформировано {0}':
      'Achm · generated {0}',
  'стр. {0} из {1}':
      'page {0} of {1}',
  'вырос в {0}':
      'rose in {0}',
  'снизился в {0}':
      'dropped in {0}',
  'без изменений в {0}':
      'unchanged in {0}',
  'Проведено тренировок по плану: {0} из {1}.':
      'Planned workouts done: {0} of {1}.',
  'Выполнено {0}% подходов (жёлтых — {1}, красных — {2} из {3}).':
      '{0}% of sets completed (yellow — {1}, red — {2} of {3}).',
  'Расчётный 1ПМ {0} из {1} упражнений.':
      'Estimated 1RM {0} of {1} exercises.',
  'кг, {0}{1} кг по тренду':
      'kg, {0}{1} kg by trend',
  'по взвешиваниям периода':
      'from weigh-ins in the period',
  'Тренировки':
      'Workouts',
  'по плану программы':
      'per program plan',
  'Выполнение плана':
      'Plan completion',
  'зелёные подходы':
      'green sets',
  'Тоннаж':
      'Tonnage',
  'рабочие подходы':
      'working sets',
  'Вес тела':
      'Body weight',
  'Сила: расчётный 1ПМ, кг':
      'Strength: estimated 1RM, kg',
  'По формуле Эпли, лучший подход недели; разгрузочные недели не учитываются.':
      'Epley formula, best set of the week; deload weeks excluded.',
  'Нет завершённых подходов с весом за период.':
      'No completed weighted sets in the period.',
  'Недель':
      'Weeks',
  'Начало':
      'Start',
  'Конец':
      'End',
  'Лучший':
      'Best',
  'Изменение':
      'Change',
  '{0} (изол.)':
      '{0} (isol.)',
  'Нагрузка по неделям':
      'Load by week',
  'Выполнение — доля зелёных подходов. Полоса — тоннаж недели относительно максимального.':
      'Completion is the share of green sets. The bar is weekly tonnage relative to the maximum.',
  'Нед.':
      'Wk',
  'С даты':
      'From',
  'Трен.':
      'Sess.',
  'Подх.':
      'Sets',
  'Выполнено':
      'Completed',
  '{0} · разгр.':
      '{0} · deload',
  'Объём по группам мышц':
      'Volume by muscle group',
  'Среднее число рабочих подходов в неделю (с долями упражнений) против целевого коридора.':
      'Average working sets per week (with exercise shares) vs the target range.',
  'Группа':
      'Group',
  'Подходов в неделю':
      'Sets per week',
  'Коридор':
      'Range',
  'Оценка':
      'Rating',
  'ниже':
      'below',
  'выше':
      'above',
  'Изменения плана по рекомендациям':
      'Plan changes from recommendations',
  'Правило':
      'Rule',
  'Решение':
      'Decision',
  'вся программа':
      'whole program',
  'принято':
      'accepted',
  'отклонено':
      'rejected',
  'Заметки к тренировкам':
      'Workout notes',
  'Данные из журнала тренировок Achm. Статусы подходов: зелёный — выполнен (недобор до 2 повторов), жёлтый — недобор 3–5, красный — 6 и больше.':
      'Data from the Achm workout journal. Set statuses: green — done (up to 2 reps short), yellow — 3–5 short, red — 6 or more.',
  'Пора делать следующий подход':
      'Time for the next set',
  'Таймер отдыха':
      'Rest timer',
  'Сигнал об окончании отдыха между подходами':
      'Signal when rest between sets is over',
  'Ход тренировки':
      'Workout progress',
  'Следующий подход и таймер отдыха на экране блокировки':
      'Next set and rest timer on the lock screen',
  'Open Food Facts ответил ошибкой {0}. Попробуйте позже.':
      'Open Food Facts returned error {0}. Try again later.',
  'Нет соединения с интернетом. Доступны ручной ввод и сохранённые продукты.':
      'No internet connection. Manual entry and saved foods are available.',
  'Open Food Facts не отвечает. Проверьте интернет и попробуйте ещё раз.':
      'Open Food Facts is not responding. Check your connection and try again.',
  'Open Food Facts вернул некорректный ответ.':
      'Open Food Facts returned an invalid response.',
  'Вход в приложение':
      'Unlock the app',
  'Тоннаж недели в {0} раза выше среднего за {1} нед. ({2} против {3}).':
      'Weekly tonnage is {0}× the {1}-week average ({2} vs {3}).',
  'т':
      't',
  'Выполнен':
      'Done',
  'Небольшой недобор':
      'Slightly short',
  'Частично':
      'Partial',
  'Провал':
      'Failed',
  'Диски: {0} кг.':
      'Plates: {0} kg.',
  'Две последние сессии «{0}» со статусом «провал»{1}. Предлагается снизить вес с {2} до {3} кг ({4}). Веса следующих недель сдвинутся на {5} кг.':
      'The last two sessions of “{0}” were failed{1}. Suggested: lower the weight from {2} to {3} kg ({4}). Weights in the following weeks shift by {5} kg.',
  'Последние {0} сессии «{1}» выполнены полностью: {2}. Предлагается прибавить вес с {3} до {4} кг ({5}). Веса следующих недель сдвинутся на +{6} кг.':
      'The last {0} sessions of “{1}” were fully completed: {2}. Suggested: raise the weight from {3} to {4} kg ({5}). Weights in the following weeks shift by +{6} kg.',
  'Язык и единицы':
      'Language and units',
  'Язык':
      'Language',
  'Единицы веса':
      'Weight units',
  'Штанга и вес тела. В базе веса хранятся в килограммах':
      'Barbell and body weight. Weights are stored in kilograms',
  '3 мес':
      '3 mo',
  '6 мес':
      '6 mo',
  '12 мес':
      '12 mo',
  'Всё время':
      'All time',
  'Вручную':
      'Manual',
  'Линейный шаг':
      'Linear step',
  'Журнал':
      'Journal',
  'Анализ':
      'Stats',
  'Питание':
      'Nutrition',
  'Советы':
      'Tips',
  'Упражн.':
      'Exerc.',
  'Ещё':
      'More',
};

/// Названия из справочника и готовых программ (хранятся в базе по-русски).
const enNames = <String, String>{
  'Грудь': 'Chest',
  'Спина': 'Back',
  'Квадрицепсы': 'Quads',
  'Бицепс бедра': 'Hamstrings',
  'Ягодицы': 'Glutes',
  'Передняя дельта': 'Front delts',
  'Средняя дельта': 'Side delts',
  'Задняя дельта': 'Rear delts',
  'Бицепс': 'Biceps',
  'Трицепс': 'Triceps',
  'Икры': 'Calves',
  'Пресс': 'Abs',
  'Трапеции': 'Traps',
  'Разгибатели спины': 'Spinal erectors',
  'Предплечья': 'Forearms',
  'Штанга': 'Barbell',
  'Гантели': 'Dumbbells',
  'Тренажёр': 'Machine',
  'Блок': 'Cable',
  'Турник': 'Pull-up bar',
  'Собственный вес': 'Bodyweight',
  'Жим лёжа': 'Bench press',
  'Жим лёжа с паузой': 'Paused bench press',
  'Жим лёжа узким хватом': 'Close-grip bench press',
  'Жим на наклонной скамье': 'Incline bench press',
  'Жим гантелей лёжа': 'Dumbbell bench press',
  'Приседания со штангой': 'Back squat',
  'Фронтальные приседания': 'Front squat',
  'Приседания с паузой': 'Paused squat',
  'Приседания на бокс': 'Box squat',
  'Становая тяга': 'Deadlift',
  'Румынская тяга': 'Romanian deadlift',
  'Становая тяга сумо': 'Sumo deadlift',
  'Тяга с плинтов': 'Block pull',
  'Жим стоя': 'Overhead press',
  'Жим гантелей сидя': 'Seated dumbbell press',
  'Жимовой швунг': 'Push press',
  'Тяга штанги в наклоне': 'Barbell row',
  'Тяга гантели в наклоне': 'Dumbbell row',
  'Тяга Т-грифа': 'T-bar row',
  'Тяга горизонтального блока': 'Seated cable row',
  'Подтягивания': 'Pull-up',
  'Подтягивания обратным хватом': 'Chin-up',
  'Подтягивания с отягощением': 'Weighted pull-up',
  'Тяга верхнего блока': 'Lat pulldown',
  'Жим ногами': 'Leg press',
  'Отжимания на брусьях': 'Dips',
  'Сгибания рук со штангой': 'Barbell curl',
  'Сгибания рук с гантелями «молот»': 'Hammer curl',
  'Сгибания рук на скамье Скотта': 'Preacher curl',
  'Разгибания рук на блоке': 'Triceps pushdown',
  'Французский жим': 'Skull crusher',
  'Махи гантелями в стороны': 'Lateral raise',
  'Махи гантелями в наклоне': 'Bent-over reverse fly',
  'Обратные разведения в тренажёре': 'Reverse pec deck',
  'Лицевая тяга': 'Face pull',
  'Разведение гантелей лёжа': 'Dumbbell fly',
  'Сведение рук в кроссовере': 'Cable crossover',
  'Разгибания ног в тренажёре': 'Leg extension',
  'Сгибания ног лёжа': 'Lying leg curl',
  'Ягодичный мост': 'Hip thrust',
  'Подъём на носки стоя': 'Standing calf raise',
  'Подъём на носки сидя': 'Seated calf raise',
  'Скручивания': 'Crunch',
  'Подъём ног в висе': 'Hanging leg raise',
  'Шраги со штангой': 'Barbell shrug',
  'Гиперэкстензия': 'Back extension',
  'Сгибания запястий со штангой': 'Wrist curl',
  'Два провала подряд': 'Two failed sessions in a row',
  'Плато расчётного 1ПМ': 'Estimated 1RM plateau',
  'Досрочная разгрузка': 'Early deload',
  'Снизить повторы': 'Lower the reps',
  'Автопрогрессия: прибавить вес': 'Auto-progression: add weight',
  'Всё тело, 3 дня': 'Full body, 3 days',
  'Пн, Ср, Пт. Базовые движения на всё тело в каждой тренировке — для старта и возвращения после перерыва.': 'Mon, Wed, Fri. Compound lifts for the whole body in every session — for starting out or coming back after a break.',
  'Всё тело А': 'Full body A',
  'Всё тело Б': 'Full body B',
  'Всё тело В': 'Full body C',
  'Верх / низ, 4 дня': 'Upper / lower, 4 days',
  'Пн, Вт, Чт, Пт. Каждая группа мышц дважды в неделю: силовой и объёмный день.': 'Mon, Tue, Thu, Fri. Every muscle group twice a week: a strength day and a volume day.',
  'Верх: сила': 'Upper: strength',
  'Низ: сила': 'Lower: strength',
  'Верх: объём': 'Upper: volume',
  'Низ: объём': 'Lower: volume',
  'Жим / тяга / ноги, 3 дня': 'Push / pull / legs, 3 days',
  'Пн, Ср, Пт. Жимовые, тяговые и ноги — по одному дню, больше объёма на группу за тренировку.': 'Mon, Wed, Fri. Push, pull and legs — one day each, more volume per group in a session.',
  'Жим': 'Push',
  'Тяга': 'Pull',
  'Ноги': 'Legs',
};
