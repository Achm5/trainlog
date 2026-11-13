import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/report_repo.dart';
import '../domain/dates.dart';
import '../domain/planning.dart';

/// Ресурсы отчёта: шрифты с кириллицей и логотип (PNG).
class PdfAssets {
  const PdfAssets({required this.regular, required this.bold, required this.logo});
  final ByteData regular;
  final ByteData bold;
  final Uint8List logo;
}

const _red = PdfColor.fromInt(0xFFEF233C);
const _ink = PdfColor.fromInt(0xFF0D0D0D);
const _muted = PdfColor.fromInt(0xFF6B6F76);
const _line = PdfColor.fromInt(0xFFDDDFE3);
const _zebra = PdfColor.fromInt(0xFFF5F6F8);
const _good = PdfColor.fromInt(0xFF2E9E4F);
const _warn = PdfColor.fromInt(0xFFE0A800);
const _bad = PdfColor.fromInt(0xFFD64545);

String _n1(double v) => ((v * 10).round() / 10).toStringAsFixed(1).replaceAll('.', ',').replaceAll(',0', '');
String _signedPct(double v) => '${v > 0 ? '+' : ''}${v.toStringAsFixed(1).replaceAll('.', ',')}%';
String _tons(double kg) => _n1(kg / 1000);
String _kg(double v) => formatKg((v * 10).round() / 10);

String reportFileName(MesocycleReport r) {
  final name = r.programName.trim().replaceAll(RegExp(r'[^0-9A-Za-zА-Яа-яЁё_-]+'), '-');
  return 'achm-report-${name.isEmpty ? 'cycle' : name}-${ymd(r.generatedAt)}.pdf';
}

/// PDF-отчёт за мезоцикл: итоги, сила, нагрузка по неделям, объём по группам мышц,
/// решения по рекомендациям и заметки. Логотип Achm — в правом верхнем углу каждой страницы.
Future<Uint8List> buildMesocyclePdf(MesocycleReport r, PdfAssets assets) async {
  final logo = pw.MemoryImage(assets.logo);
  final doc = pw.Document(
    title: 'Отчёт за мезоцикл — ${r.programName}',
    author: r.athlete.isEmpty ? 'Achm' : r.athlete,
    creator: 'Achm',
    theme: pw.ThemeData.withFont(base: pw.Font.ttf(assets.regular), bold: pw.Font.ttf(assets.bold)),
  );
  final period = '${ruDate(r.from)} — ${ruDate(r.to)} · ${r.weeksCount} нед.';

  pw.Widget header(pw.Context ctx) {
    final first = ctx.pageNumber == 1;
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: pw.BoxDecoration(border: pw.Border(bottom: const pw.BorderSide(color: _red, width: 1.5))),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: first
                  ? [
                      pw.Text('Отчёт за мезоцикл',
                          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _ink)),
                      pw.SizedBox(height: 3),
                      pw.Text(r.programName, style: const pw.TextStyle(fontSize: 13, color: _ink)),
                      pw.SizedBox(height: 2),
                      pw.Text(period, style: const pw.TextStyle(fontSize: 9, color: _muted)),
                      if (r.athlete.isNotEmpty)
                        pw.Text('Спортсмен: ${r.athlete}', style: const pw.TextStyle(fontSize: 9, color: _muted)),
                    ]
                  : [
                      pw.Text('Отчёт за мезоцикл · ${r.programName}',
                          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _ink)),
                      pw.Text(period, style: const pw.TextStyle(fontSize: 8, color: _muted)),
                    ],
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Image(logo, width: first ? 46 : 28, height: first ? 46 : 28),
              if (first) ...[
                pw.SizedBox(height: 2),
                pw.Text('Achm', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _ink)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget footer(pw.Context ctx) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 10),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Achm · сформировано ${ruDate(r.generatedAt)}', style: const pw.TextStyle(fontSize: 8, color: _muted)),
            pw.Text('стр. ${ctx.pageNumber} из ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: _muted)),
          ],
        ),
      );

  pw.Widget section(String title, {String? hint}) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _ink)),
            if (hint != null) pw.Text(hint, style: const pw.TextStyle(fontSize: 8, color: _muted)),
          ],
        ),
      );

  pw.Widget cell(String text, {bool bold = false, bool right = false, PdfColor? color, double size = 9}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: pw.Text(
          text,
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : null, color: color ?? _ink),
        ),
      );

  /// Таблица: первая строка — заголовок; [right] — номера колонок с выравниванием вправо.
  pw.Widget table(List<String> head, List<List<pw.Widget>> rows,
      {required Map<int, pw.TableColumnWidth> widths, Set<int> right = const {}}) {
    return pw.Table(
      columnWidths: widths,
      border: pw.TableBorder(horizontalInside: const pw.BorderSide(color: _line, width: 0.5)),
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(border: pw.Border(bottom: const pw.BorderSide(color: _ink, width: 0.8))),
          children: [
            for (var i = 0; i < head.length; i++)
              cell(head[i], bold: true, right: right.contains(i), color: _muted, size: 8),
          ],
        ),
        for (var i = 0; i < rows.length; i++)
          pw.TableRow(
            decoration: i.isOdd ? pw.BoxDecoration(color: _zebra) : null,
            children: rows[i],
          ),
      ],
    );
  }

  pw.Widget tile(String label, String value, {String? sub}) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.only(right: 6),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _line, width: 0.8), borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: _muted)),
              pw.SizedBox(height: 3),
              pw.Text(value, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: _ink)),
              if (sub != null) pw.Text(sub, style: const pw.TextStyle(fontSize: 7.5, color: _muted)),
            ],
          ),
        ),
      );

  pw.Widget bar(double share, {PdfColor color = _red}) => pw.Container(
        height: 7,
        decoration: pw.BoxDecoration(color: _zebra),
        child: () {
          final filled = (share.clamp(0.0, 1.0) * 1000).round();
          return pw.Row(children: [
            if (filled > 0)
              pw.Expanded(flex: filled, child: pw.Container(height: 7, decoration: pw.BoxDecoration(color: color))),
            if (filled < 1000) pw.Expanded(flex: 1000 - filled, child: pw.SizedBox(height: 7)),
          ]);
        }(),
      );

  // ---------- Итоги ----------
  final done = r.doneShare;
  final growing = r.exercises.where((e) => (e.deltaPct ?? 0) > 0.5).length;
  final falling = r.exercises.where((e) => (e.deltaPct ?? 0) < -0.5).length;
  final measured = r.exercises.where((e) => e.deltaPct != null).length;
  final summaryText = <String>[
    'Проведено тренировок по плану: ${r.sessionsDone} из ${r.sessionsPlanned}.',
    if (done != null)
      'Выполнено ${(done * 100).round()}% подходов (жёлтых — ${r.setsPartial}, красных — ${r.setsFailed} из ${r.setsTotal}).',
    if (measured > 0) 'Расчётный 1ПМ вырос в $growing из $measured упражнений${falling > 0 ? ', снизился в $falling' : ''}.',
  ].join(' ');

  final weightValue = r.weightStart == null
      ? '—'
      : r.weightEnd == null
          ? '${_kg(r.weightStart!)} кг'
          : '${_kg(r.weightStart!)} › ${_kg(r.weightEnd!)}';
  final weightSub = r.weightStart != null && r.weightEnd != null
      ? 'кг, ${r.weightEnd! - r.weightStart! >= 0 ? '+' : ''}${_n1(r.weightEnd! - r.weightStart!)} кг по тренду'
      : 'по взвешиваниям периода';

  final content = <pw.Widget>[
    pw.Row(children: [
      tile('Тренировки', '${r.sessionsDone} / ${r.sessionsPlanned}', sub: 'по плану программы'),
      tile('Выполнение плана', done == null ? '—' : '${(done * 100).round()}%', sub: 'зелёные подходы'),
      tile('Тоннаж', '${_tons(r.tonnageKg)} т', sub: 'рабочие подходы'),
      tile('Вес тела', weightValue, sub: weightSub),
    ]),
    pw.SizedBox(height: 8),
    pw.Text(summaryText, style: const pw.TextStyle(fontSize: 9.5, color: _ink, lineSpacing: 2)),
  ];

  // ---------- Сила ----------
  content.add(section('Сила: расчётный 1ПМ, кг', hint: 'По формуле Эпли, лучший подход недели; разгрузочные недели не учитываются.'));
  if (r.exercises.isEmpty) {
    content.add(pw.Text('Нет завершённых подходов с весом за период.', style: const pw.TextStyle(fontSize: 9, color: _muted)));
  } else {
    content.add(table(
      ['Упражнение', 'Недель', 'Начало', 'Конец', 'Лучший', 'Изменение'],
      [
        for (final e in r.exercises)
          [
            cell(e.isCompound ? e.name : '${e.name} (изол.)'),
            cell('${e.e1rm.length}', right: true),
            cell(_kg(e.first), right: true),
            cell(_kg(e.last), right: true),
            cell(_kg(e.best), right: true),
            cell(
              e.deltaPct == null ? '—' : _signedPct(e.deltaPct!),
              right: true,
              bold: true,
              color: e.deltaPct == null
                  ? _muted
                  : (e.deltaPct! > 0.5 ? _good : (e.deltaPct! < -0.5 ? _bad : _muted)),
            ),
          ],
      ],
      widths: {
        0: pw.FlexColumnWidth(4),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.2),
        4: pw.FlexColumnWidth(1.2),
        5: pw.FlexColumnWidth(1.4),
      },
      right: const {1, 2, 3, 4, 5},
    ));
  }

  // ---------- Нагрузка по неделям ----------
  final maxTon = r.weeks.fold(0.0, (a, w) => w.tonnageKg > a ? w.tonnageKg : a);
  content.add(section('Нагрузка по неделям',
      hint: 'Выполнение — доля зелёных подходов. Полоса — тоннаж недели относительно максимального.'));
  content.add(table(
    ['Нед.', 'С даты', 'Трен.', 'Подх.', 'Тоннаж, т', '', 'Выполнено'],
    [
      for (final w in r.weeks)
        [
          cell(w.isDeload ? '${w.weekNo} · разгр.' : '${w.weekNo}', color: w.isDeload ? _muted : _ink),
          cell(ruDate(w.start)),
          cell('${w.sessions}', right: true),
          cell('${w.workSets}', right: true),
          cell(w.tonnageKg > 0 ? _tons(w.tonnageKg) : '—', right: true),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
            child: bar(maxTon <= 0 ? 0 : w.tonnageKg / maxTon, color: w.isDeload ? _muted : _red),
          ),
          () {
            if (w.setsTotal == 0) return cell('—', right: true, color: _muted);
            final s = w.setsDone / w.setsTotal;
            return cell('${(s * 100).round()}%', right: true, bold: true, color: s >= 0.8 ? _good : (s >= 0.6 ? _warn : _bad));
          }(),
        ],
    ],
    widths: {
      0: pw.FlexColumnWidth(1.4),
      1: pw.FlexColumnWidth(1.6),
      2: pw.FlexColumnWidth(0.9),
      3: pw.FlexColumnWidth(0.9),
      4: pw.FlexColumnWidth(1.3),
      5: pw.FlexColumnWidth(2.6),
      6: pw.FlexColumnWidth(1.3),
    },
    right: const {2, 3, 4, 6},
  ));

  // ---------- Объём по группам мышц ----------
  if (r.muscles.isNotEmpty) {
    content.add(section('Объём по группам мышц',
        hint: 'Среднее число рабочих подходов в неделю (с долями упражнений) против целевого коридора.'));
    content.add(table(
      ['Группа', 'Подходов в неделю', 'Коридор', 'Оценка'],
      [
        for (final m in r.muscles)
          [
            cell(m.name),
            cell(_n1(m.avgSets), right: true),
            cell('${m.targetMin}–${m.targetMax}', right: true),
            m.avgSets < m.targetMin
                ? cell('ниже', color: _warn, bold: true)
                : (m.avgSets > m.targetMax ? cell('выше', color: _bad, bold: true) : cell('в коридоре', color: _good, bold: true)),
          ],
      ],
      widths: {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(1.6),
      },
      right: const {1, 2},
    ));
  }

  // ---------- Решения по рекомендациям ----------
  if (r.decisions.isNotEmpty) {
    content.add(section('Изменения плана по рекомендациям'));
    content.add(table(
      ['Дата', 'Правило', 'Упражнение', 'Решение'],
      [
        for (final d in r.decisions)
          [
            cell(ruDate(d.date)),
            cell(d.rule),
            cell(d.exercise ?? 'вся программа'),
            cell(d.status == 'accepted' ? 'принято' : 'отклонено', color: d.status == 'accepted' ? _good : _muted),
          ],
      ],
      widths: {
        0: pw.FlexColumnWidth(1.3),
        1: pw.FlexColumnWidth(3),
        2: pw.FlexColumnWidth(3),
        3: pw.FlexColumnWidth(1.4),
      },
    ));
  }

  // ---------- Заметки ----------
  if (r.notes.isNotEmpty) {
    content.add(section('Заметки к тренировкам'));
    for (final n in r.notes) {
      content.add(pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(width: 62, child: pw.Text(ruDate(n.date), style: const pw.TextStyle(fontSize: 9, color: _muted))),
            pw.Expanded(child: pw.Text(n.text, style: const pw.TextStyle(fontSize: 9, color: _ink))),
          ],
        ),
      ));
    }
  }

  content.add(pw.Padding(
    padding: const pw.EdgeInsets.only(top: 16),
    child: pw.Text(
      'Данные из журнала тренировок Achm. Статусы подходов: зелёный — выполнен (недобор до 2 повторов), '
      'жёлтый — недобор 3–5, красный — 6 и больше.',
      style: const pw.TextStyle(fontSize: 7.5, color: _muted),
    ),
  ));

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(36, 30, 36, 28),
    header: header,
    footer: footer,
    build: (ctx) => content,
  ));
  return doc.save();
}
