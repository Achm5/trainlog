import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/error_log.dart';
import '../common.dart';

/// Журнал ошибок: что пошло не так на этом телефоне. Хранится локально, отправляется только вручную.
class ErrorLogScreen extends StatefulWidget {
  const ErrorLogScreen({super.key});

  @override
  State<ErrorLogScreen> createState() => _ErrorLogScreenState();
}

class _ErrorLogScreenState extends State<ErrorLogScreen> {
  String _text = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    try {
      _text = ErrorLog.instance?.read() ?? '';
    } catch (e) {
      _text = 'Не удалось прочитать журнал: $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    final empty = _text.trim().isEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(empty ? 'Журнал ошибок' : 'Журнал ошибок · ${logEntriesCount(_text)}'),
        actions: [
          IconButton(
            tooltip: 'Отправить',
            icon: const Icon(Icons.share_outlined),
            onPressed: empty
                ? null
                : () => SharePlus.instance.share(ShareParams(text: _text, subject: 'Achm: журнал ошибок')),
          ),
          IconButton(
            tooltip: 'Очистить',
            icon: const Icon(Icons.delete_outline),
            onPressed: empty
                ? null
                : () async {
                    if (!await confirm(context, 'Очистить журнал ошибок?')) return;
                    ErrorLog.instance?.clear();
                    if (mounted) setState(_load);
                  },
          ),
        ],
      ),
      body: empty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Ошибок не записано. Если приложение поведёт себя странно, причина появится здесь — '
                  'её можно будет отправить кнопкой вверху. Журнал хранится только на телефоне.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectableText(_text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
    );
  }
}
