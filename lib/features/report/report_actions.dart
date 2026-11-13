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

Future<PdfAssets> loadPdfAssets() async => PdfAssets(
      regular: await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
      bold: await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
      logo: Uint8List.sublistView(await rootBundle.load('assets/pdf/logo.png')),
    );

/// Собирает PDF-отчёт за мезоцикл программы и предлагает отправить его или сохранить в файл.
Future<void> exportMesocycleReport(BuildContext context, WidgetRef ref, int programId) async {
  toast(context, 'Готовлю отчёт…');
  File file;
  String title;
  try {
    final report = await ReportRepo(ref.read(databaseProvider)).build(programId);
    final bytes = await buildMesocyclePdf(report, await loadPdfAssets());
    final dir = await getTemporaryDirectory();
    file = File(p.join(dir.path, reportFileName(report)));
    await file.writeAsBytes(bytes, flush: true);
    title = 'Отчёт за мезоцикл «${report.programName}»';
  } catch (e) {
    if (context.mounted) toast(context, 'Не удалось сформировать отчёт: $e');
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
            title: const Text('Отправить тренеру'),
            subtitle: const Text('Мессенджер, почта, облако'),
            onTap: () => Navigator.pop(c, 'share'),
          ),
          ListTile(
            leading: const Icon(Icons.save_alt),
            title: const Text('Сохранить в файл'),
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
          dialogTitle: 'Сохранить отчёт',
          fileName: p.basename(file.path),
          bytes: await file.readAsBytes(),
        );
        if (path != null && context.mounted) toast(context, 'Отчёт сохранён');
    }
  } catch (e) {
    if (context.mounted) toast(context, 'Ошибка: $e');
  }
}
