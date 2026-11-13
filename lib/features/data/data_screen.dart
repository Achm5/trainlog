import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/app_state.dart';
import '../../data/backup.dart';
import '../../data/database.dart';
import '../../domain/dates.dart';
import '../../providers.dart';
import '../../services/error_log.dart';
import '../../services/security.dart';
import '../common.dart';
import 'pin_pad.dart';

final lastBackupProvider = FutureProvider<DateTime?>((ref) async {
  final v = await ref.watch(appStateProvider).get(stateLastBackupAt);
  return v == null ? null : DateTime.tryParse(v);
});

/// Данные и защита: резервная копия, импорт, CSV, PIN и биометрия.
class DataScreen extends ConsumerStatefulWidget {
  const DataScreen({super.key});

  @override
  ConsumerState<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends ConsumerState<DataScreen> {
  bool _busy = false;
  bool _bioEnabled = false;
  bool _bioAvailable = false;

  BackupService get _backup => BackupService(ref.read(databaseProvider));

  @override
  void initState() {
    super.initState();
    () async {
      final enabled = await ref.read(appStateProvider).get(stateBiometricEnabled) == '1';
      final available = await BiometricService().available();
      if (mounted) {
        setState(() {
          _bioEnabled = enabled;
          _bioAvailable = available;
        });
      }
    }();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on BackupException catch (e) {
      if (mounted) toast(context, e.message);
    } catch (e, st) {
      ErrorLog.record('данные и защита', e, st);
      if (mounted) toast(context, 'Ошибка: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<File> _makeBackup() async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, BackupService.fileName(DateTime.now())));
    await _backup.exportTo(file);
    return file;
  }

  Future<void> _markBackedUp() async {
    await ref.read(appStateProvider).set(stateLastBackupAt, DateTime.now().toIso8601String());
    ref.invalidate(lastBackupProvider);
  }

  Future<void> _shareBackup() => _run(() async {
        final file = await _makeBackup();
        await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'Резервная копия Achm'));
        await _markBackedUp();
      });

  Future<void> _saveBackup() => _run(() async {
        final file = await _makeBackup();
        final path = await FilePicker.saveFile(
          dialogTitle: 'Сохранить резервную копию',
          fileName: p.basename(file.path),
          bytes: await file.readAsBytes(),
        );
        if (path == null) return;
        await _markBackedUp();
        if (mounted) toast(context, 'Копия сохранена');
      });

  Future<void> _import() => _run(() async {
        final picked = await FilePicker.pickFiles(type: FileType.any);
        final path = picked.isEmpty ? null : picked.first.path;
        if (path == null || !mounted) return;
        if (!await confirm(context, 'Заменить все данные?',
            message: 'Текущие программы, журнал и дневник будут заменены содержимым файла '
                '«${p.basename(path)}». Отменить это нельзя — сначала сделайте копию текущих данных.',
            ok: 'Заменить')) {
          return;
        }
        // Копируем выбранный файл в свою папку: исходник может быть недоступен для записи рядом.
        final dir = await getTemporaryDirectory();
        final local = await File(path).copy(p.join(dir.path, 'import.sqlite'));
        try {
          await _backup.importFrom(local);
        } finally {
          if (await local.exists()) await local.delete();
        }
        await ref.read(journalRepoProvider).recalcAll();
        if (mounted) toast(context, 'Данные восстановлены из копии');
      });

  Future<void> _shareCsv(String name, Future<String> Function() build) => _run(() async {
        final dir = await getTemporaryDirectory();
        final file = File(p.join(dir.path, '$name-${ymd(today())}.csv'));
        await file.writeAsBytes(Uint8List.fromList(utf8.encode(await build())));
        await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
      });

  Future<void> _setPin(Setting s) async {
    final first = await _askPin('Новый PIN (4–8 цифр)');
    if (first == null || !mounted) return;
    if (!isValidPin(first)) return toast(context, 'PIN — от 4 до 8 цифр');
    final second = await _askPin('Повторите PIN');
    if (second == null || !mounted) return;
    if (first != second) return toast(context, 'PIN не совпадает');
    await ref.read(referenceRepoProvider).updateSettings(SettingsCompanion(pinHash: Value(pinHash(first))));
    if (mounted) toast(context, 'PIN установлен');
  }

  Future<void> _removePin(Setting s) async {
    final pin = await _askPin('Текущий PIN');
    if (pin == null || !mounted) return;
    if (pinHash(pin) != s.pinHash) return toast(context, 'Неверный PIN');
    await ref.read(referenceRepoProvider).updateSettings(const SettingsCompanion(pinHash: Value(null)));
    await ref.read(appStateProvider).set(stateBiometricEnabled, null);
    if (mounted) setState(() => _bioEnabled = false);
  }

  Future<String?> _askPin(String title) => askPinPad(context, title);

  @override
  Widget build(BuildContext context) {
    final last = ref.watch(lastBackupProvider).value;
    final settings = ref.watch(settingsProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Данные и защита')),
      body: ListView(
        children: [
          if (_busy) const LinearProgressIndicator(),
          const ListTile(title: Text('Резервная копия', style: TextStyle(fontWeight: FontWeight.bold))),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(last == null ? 'Копий ещё не было' : 'Последняя копия: ${ruDate(last)}'),
            subtitle: const Text('Все данные хранятся только на телефоне. Без копии они пропадут при потере телефона '
                'или удалении приложения.'),
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Поделиться копией базы'),
            subtitle: const Text('Файл .sqlite — в облако, мессенджер или на почту'),
            onTap: _shareBackup,
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Сохранить копию в файл'),
            subtitle: const Text('Например, в «Загрузки»'),
            onTap: _saveBackup,
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Восстановить из копии'),
            subtitle: const Text('Импорт файла с заменой всех данных'),
            onTap: _import,
          ),
          const Divider(),
          const ListTile(title: Text('Выгрузка в CSV', style: TextStyle(fontWeight: FontWeight.bold))),
          ListTile(
            leading: const Icon(Icons.fitness_center),
            title: const Text('Журнал тренировок'),
            subtitle: const Text('Строка на подход'),
            onTap: () => _shareCsv('achm-journal', _backup.journalCsv),
          ),
          ListTile(
            leading: const Icon(Icons.restaurant),
            title: const Text('Дневник питания'),
            subtitle: const Text('Строка на запись'),
            onTap: () => _shareCsv('achm-diary', _backup.diaryCsv),
          ),
          const Divider(),
          const ListTile(title: Text('Диагностика', style: TextStyle(fontWeight: FontWeight.bold))),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Журнал ошибок'),
            subtitle: const Text('Что пошло не так на этом телефоне; хранится локально'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/errors'),
          ),
          const Divider(),
          const ListTile(title: Text('Защита', style: TextStyle(fontWeight: FontWeight.bold))),
          if (settings != null && settings.pinHash == null)
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Установить PIN'),
              subtitle: const Text('Запрашивается при запуске приложения'),
              onTap: () => _setPin(settings),
            ),
          if (settings != null && settings.pinHash != null) ...[
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('PIN установлен'),
              subtitle: const Text('Нажмите, чтобы отключить'),
              onTap: () => _removePin(settings),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: const Text('Вход по биометрии'),
              subtitle: Text(_bioAvailable ? 'Отпечаток или лицо вместо PIN' : 'На устройстве не настроена биометрия'),
              value: _bioEnabled && _bioAvailable,
              onChanged: !_bioAvailable
                  ? null
                  : (v) async {
                      await ref.read(appStateProvider).set(stateBiometricEnabled, v ? '1' : null);
                      setState(() => _bioEnabled = v);
                    },
            ),
          ],
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('PIN не шифрует базу и не восстанавливается: если забыли его, переустановите приложение '
                'и восстановите данные из резервной копии.'),
          ),
        ],
      ),
    );
  }
}

/// Напоминание о резервной копии раз в неделю (карточка на главном экране).
class BackupReminderCard extends ConsumerStatefulWidget {
  const BackupReminderCard({super.key, required this.onOpen});
  final VoidCallback onOpen;

  @override
  ConsumerState<BackupReminderCard> createState() => _BackupReminderCardState();
}

class _BackupReminderCardState extends ConsumerState<BackupReminderCard> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final state = ref.read(appStateProvider);
    final now = DateTime.now();
    bool older(String? iso) {
      final d = iso == null ? null : DateTime.tryParse(iso);
      return d == null || now.difference(d).inDays >= 7;
    }

    final due = older(await state.get(stateLastBackupAt)) && older(await state.get(stateBackupReminderAt));
    // Пустой базе напоминать не о чем.
    final hasData = (await ref.read(databaseProvider).select(ref.read(databaseProvider).workoutSessions).get()).isNotEmpty ||
        (await ref.read(databaseProvider).select(ref.read(databaseProvider).foodLogs).get()).isNotEmpty;
    if (mounted && due && hasData) setState(() => _show = true);
  }

  Future<void> _snooze() async {
    await ref.read(appStateProvider).set(stateBackupReminderAt, DateTime.now().toIso8601String());
    if (mounted) setState(() => _show = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(lastBackupProvider, (_, next) {
      final d = next.value;
      if (d != null && DateTime.now().difference(d).inDays < 7 && _show) setState(() => _show = false);
    });
    if (!_show) return const SizedBox.shrink();
    return Card(
      child: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.backup_outlined),
            title: Text('Пора сделать резервную копию'),
            subtitle: Text('Копии не было больше недели'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: _snooze, child: const Text('Позже')),
                const SizedBox(width: 8),
                FilledButton.tonal(onPressed: widget.onOpen, child: const Text('Сделать')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
