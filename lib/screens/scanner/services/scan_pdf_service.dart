import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/models/scan_model.dart';
import 'scan_storage_service.dart';

class ScanPdfService {
  static Future<File> createPdf({
    required String title,
    required List<ScanEntry> scans,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
    bool addPageNumbers = true,
    bool compress = true,
  }) async {
    if (scans.isEmpty) {
      throw const FormatException('Select at least one scan page.');
    }

    final pdf = pw.Document(
      title: title,
      creator: 'Home Helper Document Scanner',
      compress: compress,
    );
    var added = 0;
    for (var index = 0; index < scans.length; index++) {
      final path = scans[index].currentPath;
      final file = File(path);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      final image = pw.MemoryImage(bytes);
      added++;
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(18),
          build: (_) => pw.Column(
            children: [
              pw.Expanded(
                child: pw.Center(
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                ),
              ),
              if (addPageNumbers) ...[
                pw.SizedBox(height: 6),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      '${index + 1} / ${scans.length}',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (added == 0) {
      throw const FileSystemException(
        'None of the selected scan image files could be found.',
      );
    }

    final directory = await ScanStorageService().exportDirectory();
    final safeTitle = _safeName(title);
    final file = File(
      p.join(
        directory.path,
        '${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      ),
    );
    await file.writeAsBytes(await pdf.save(), flush: true);
    return file;
  }

  static String _safeName(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return cleaned.isEmpty ? 'scanned_document' : cleaned;
  }
}
