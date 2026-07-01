import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'body_utils.dart';

Future<void> exportJournalPdf(List<Map<String, dynamic>> entries) async {
  final doc = pw.Document();

  final sorted = [...entries]..sort((a, b) {
      final da = DateTime.tryParse(a['created_at'] as String? ?? '') ?? DateTime.now();
      final db = DateTime.tryParse(b['created_at'] as String? ?? '') ?? DateTime.now();
      return da.compareTo(db);
    });

  const accent = PdfColor.fromInt(0xFF9b72cf);
  const ink    = PdfColor.fromInt(0xFF2d1a0e);
  const muted  = PdfColor.fromInt(0xFF8b6050);
  const border = PdfColor.fromInt(0xFFd4b896);
  const paper  = PdfColor.fromInt(0xFFfdf6e3);

  // ── Cover page ────────────────────────────────────────────────────────────
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      build: (ctx) => pw.Container(
        color: paper,
        child: pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('✦', style: pw.TextStyle(fontSize: 36, color: accent)),
              pw.SizedBox(height: 20),
              pw.Text('DevineJournal',
                  style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: accent,
                      letterSpacing: 2)),
              pw.SizedBox(height: 10),
              pw.Text('${sorted.length} ${sorted.length == 1 ? 'entry' : 'entries'}',
                  style: pw.TextStyle(fontSize: 14, color: muted)),
              pw.SizedBox(height: 4),
              pw.Text('Exported ${DateFormat('MMMM d, yyyy').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 12, color: muted)),
            ],
          ),
        ),
      ),
    ),
  );

  // ── One page per entry ───────────────────────────────────────────────────
  for (final e in sorted) {
    final title = (e['title'] as String? ?? '').trim();
    final body  = bodyToPlainText(e['body'] as String? ?? '').trim();
    final mood  = e['mood']  as String? ?? '';
    final tags  = (e['tags']  as String? ?? '')
        .split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final dt = DateTime.tryParse(e['created_at'] as String? ?? '');
    final dateStr = dt != null ? DateFormat('EEEE, MMMM d, yyyy').format(dt.toLocal()) : '';

    // Strip markdown for PDF (simple approach: remove bold/italic markers and headers)
    final plainBody = body
        .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*(.+?)\*'), r'$1')
        .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^-\s+', multiLine: true), '• ');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(36),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Date + mood header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(dateStr, style: pw.TextStyle(fontSize: 10, color: muted)),
                if (mood.isNotEmpty) pw.Text(mood, style: pw.TextStyle(fontSize: 14)),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: border, thickness: 0.5),
            pw.SizedBox(height: 10),

            // Title
            if (title.isNotEmpty) ...[
              pw.Text(title,
                  style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: ink)),
              pw.SizedBox(height: 12),
            ],

            // Body
            pw.Expanded(
              child: pw.Text(
                plainBody.isEmpty ? '(no content)' : plainBody,
                style: pw.TextStyle(fontSize: 12, color: ink, lineSpacing: 4),
              ),
            ),

            // Tags footer
            if (tags.isNotEmpty) ...[
              pw.Divider(color: border, thickness: 0.4),
              pw.SizedBox(height: 4),
              pw.Text(tags.map((t) => '#$t').join('  '),
                  style: pw.TextStyle(fontSize: 9, color: muted)),
            ],
          ],
        ),
      ),
    );
  }

  await Printing.layoutPdf(onLayout: (_) async => doc.save());
}
