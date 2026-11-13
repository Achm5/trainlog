import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/report_repo.dart';
import '../../providers.dart';
import '../../services/mesocycle_pdf.dart';
import '../common.dart';
import 'package:trainlog/i18n.dart';

Future<PdfAssets> loadPdfAssets() async => PdfAssets(
      regular: await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
      bold: await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
      logo: Uint8List.sublistView(await rootBundle.load('assets/pdf/logo.png')),
    );

/// Собирает PDF-отчёт за мезоцикл программы и предлагает отправить его или сохранить в файл.
Future<void> exportMesocycleReport(BuildContext context, WidgetRef ref, int programId) async {
  toast(context, tr('Готовлю отчёт…'));
  File file;
  String title;
  try {
    final report = await ReportRepo(ref.read(databaseProvider)).build(programId);
    final bytes = await buildMesocyclePdf(report, await loadPdfAssets());
    final dir = await getTemporaryDirectory();
    file = File(p.join(dir.path, reportFileName(report)));
    await file.writeAsBytes(bytes, flush: true);
    title = tr('Отчёт за мезоцикл «{0}»', [report.programName]);
  } catch (e) {
    if (context.mounted) toast(context, tr('Не удалось сформировать отчёт: {0}', [e]));
    return;
  }
  if (!context.mounted) return;

  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: Text(title),
            subtitle: Text(p.basename(file.path)),
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: Text(tr('Отправить тренеру')),
            subtitle: Text(tr('Мессенджер, почта, облако')),
            onTap: () => Navigator.pop(c, 'share'),
          ),
          ListTile(
            leading: const Icon(Icons.save_alt),
            title: Text(tr('Сохранить в файл')),
            onTap: () => Navigator.pop(c, 'save'),
          ),
        ],
      ),
    ),
  );

  try {
    switch (action) {
      case 'share':
        await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          text: title,
        ));
      case 'save':
        final path = await FilePicker.saveFile(
          dialogTitle: tr('Сохранить отчёт'),
          fileName: p.basename(file.path),
          bytes: await file.readAsBytes(),
        );
        if (path != null && context.mounted) toast(context, tr('Отчёт сохранён'));
    }
  } catch (e) {
    if (context.mounted) toast(context, tr('Ошибка: {0}', [e]));
  }
}
