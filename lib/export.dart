import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'state.dart';
import 'theme.dart' show norm, labelOf, verdictOf;

/// Plain-text summary for WhatsApp, email, notes…
String summaryText(Map<String, dynamic> d) {
  final b = StringBuffer('${d['title'] ?? 'Report'}\n\n${d['summary'] ?? ''}\n');
  if ('${d['urgent'] ?? ''}'.trim().isNotEmpty) b.write('\nImportant: ${d['urgent']}\n');
  for (final r in (d['reports'] as List? ?? []).whereType<Map>()) {
    b.write('\n${r['title']}: ${r['summary'] ?? ''}\n');
    for (final i in (r['items'] as List? ?? []).whereType<Map>()) {
      final range = '${i['range'] ?? ''}'.trim();
      b.write('- ${i['name']}: ${i['value']}${range.isNotEmpty ? ' (normal $range)' : ''} — ${i['meaning'] ?? ''}\n');
    }
  }
  final q = (d['questions'] as List? ?? []);
  if (q.isNotEmpty) {
    b.write('\nQuestions for my doctor:\n');
    for (var i = 0; i < q.length; i++) {
      b.write('${i + 1}. ${q[i]}\n');
    }
  }
  b.write('\nExplained by Lab Results Reader (labresultsreader.moezzadigital.com). For education only, not medical advice.');
  return b.toString();
}

/// Opens the phone's share sheet (WhatsApp, Gmail, Messages…).
Future<void> shareSummary(Entry e) async {
  await SharePlus.instance.share(ShareParams(text: summaryText(e.result), subject: 'My lab report summary: ${e.title}'));
}

String _fileName(Entry e) {
  final t = e.title.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  return '${t.isEmpty ? 'Lab-report' : t}-summary.pdf';
}

/// Opens Android's print screen, where "Save as PDF" is one of the printers.
Future<void> savePdf(Entry e) async {
  await Printing.layoutPdf(name: _fileName(e), onLayout: (_) => buildPdf(e));
}

/// Shares the PDF file itself (WhatsApp, email, Drive…).
Future<void> sharePdf(Entry e) async {
  await Printing.sharePdf(bytes: await buildPdf(e), filename: _fileName(e));
}

Future<(pw.Font?, pw.Font?, List<pw.Font>)> _fonts(String lang) async {
  try {
    final base = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    pw.Font? extra;
    switch (lang) {
      case 'Hindi':
        extra = await PdfGoogleFonts.notoSansDevanagariRegular();
        break;
      case 'Arabic':
        extra = await PdfGoogleFonts.notoSansArabicRegular();
        break;
      case 'Chinese (Simplified)':
        extra = await PdfGoogleFonts.notoSansSCRegular();
        break;
      case 'Japanese':
        extra = await PdfGoogleFonts.notoSansJPRegular();
        break;
      case 'Korean':
        extra = await PdfGoogleFonts.notoSansKRRegular();
        break;
    }
    return (base, bold, extra == null ? <pw.Font>[] : [extra]);
  } catch (_) {
    return (null, null, <pw.Font>[]); // offline: built-in font
  }
}

const _accent = PdfColor.fromInt(0xFF0B6E5C);
const _muted = PdfColor.fromInt(0xFF6B7280);
const _line = PdfColor.fromInt(0xFFE5E7EB);
PdfColor _st(String s) => s == 'bad'
    ? const PdfColor.fromInt(0xFFC2410C)
    : (s == 'warn' ? const PdfColor.fromInt(0xFFB45309) : const PdfColor.fromInt(0xFF15803D));

Future<Uint8List> buildPdf(Entry e) async {
  final r = e.result;
  final (base, bold, fallback) = await _fonts(e.lang);
  final rtl = e.lang == 'Arabic';
  final doc = pw.Document(title: e.title, author: 'Lab Results Reader');
  final theme = pw.ThemeData.withFont(base: base, bold: bold, fontFallback: fallback);
  final overall = norm(r['overall']);
  final urgent = '${r['urgent'] ?? ''}'.trim();
  final questions = (r['questions'] as List? ?? []).map((x) => '$x').toList();

  pw.Widget pill(String s) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: pw.BoxDecoration(color: _st(s), borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Text(labelOf[s] ?? '', style: const pw.TextStyle(color: PdfColors.white, fontSize: 8)),
      );

  doc.addPage(pw.MultiPage(
    theme: theme,
    pageFormat: PdfPageFormat.a4.copyWith(marginLeft: 40, marginRight: 40, marginTop: 40, marginBottom: 40),
    textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
    header: (ctx) => pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      margin: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _line))),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Lab Results Reader', style: pw.TextStyle(color: _accent, fontWeight: pw.FontWeight.bold, fontSize: 11)),
        pw.Text('${AppState.I.profName(e.profileId)} · ${fmtDate(e.createdAt)}', style: const pw.TextStyle(color: _muted, fontSize: 9)),
      ]),
    ),
    footer: (ctx) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Expanded(
          child: pw.Text('For educational use only. Not medical advice or a diagnosis. Always confirm results with your doctor.',
              style: const pw.TextStyle(color: _muted, fontSize: 7.5)),
        ),
        pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(color: _muted, fontSize: 7.5)),
      ]),
    ),
    build: (ctx) => [
      pw.Text(e.title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 10),
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _line), borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(verdictOf[overall] ?? '', style: pw.TextStyle(color: _st(overall), fontWeight: pw.FontWeight.bold, fontSize: 13)),
          pw.SizedBox(height: 4),
          pw.Text('${r['summary'] ?? ''}', style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 2)),
        ]),
      ),
      if (urgent.isNotEmpty) ...[
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(color: const PdfColor.fromInt(0xFFFFF1EB), borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Text(urgent, style: pw.TextStyle(color: _st('bad'), fontWeight: pw.FontWeight.bold, fontSize: 10.5)),
        ),
      ],
      for (final rep in (r['reports'] as List? ?? []).whereType<Map>()) ...[
        pw.SizedBox(height: 14),
        pw.Row(children: [
          pw.Expanded(child: pw.Text('${rep['title'] ?? ''}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold))),
          pill(norm(rep['status'])),
        ]),
        if ('${rep['summary'] ?? ''}'.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2, bottom: 4),
            child: pw.Text('${rep['summary']}', style: const pw.TextStyle(color: _muted, fontSize: 9.5)),
          ),
        pw.Table(
          border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _line, width: 0.6), bottom: pw.BorderSide(color: _line, width: 0.6)),
          columnWidths: {0: const pw.FlexColumnWidth(2.2), 1: const pw.FlexColumnWidth(1.3), 2: const pw.FlexColumnWidth(1.4), 3: const pw.FlexColumnWidth(3.4)},
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF3F4F6)),
              children: [
                for (final h in ['Test', 'Your result', 'Normal range', 'What it means'])
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(h, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _muted))),
              ],
            ),
            for (final it in (rep['items'] as List? ?? []).whereType<Map>())
              pw.TableRow(children: [
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${it['name'] ?? ''}', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold))),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text('${it['value'] ?? ''}', style: pw.TextStyle(fontSize: 9.5, color: _st(norm(it['status'])), fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${it['range'] ?? ''}', style: const pw.TextStyle(fontSize: 9, color: _muted))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${it['meaning'] ?? ''}', style: const pw.TextStyle(fontSize: 9))),
              ]),
          ],
        ),
      ],
      if (questions.isNotEmpty) ...[
        pw.SizedBox(height: 16),
        pw.Text('Questions for your doctor', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        for (var i = 0; i < questions.length; i++)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3),
            child: pw.Text('${i + 1}. ${questions[i]}', style: const pw.TextStyle(fontSize: 10.5)),
          ),
      ],
    ],
  ));
  return doc.save();
}
