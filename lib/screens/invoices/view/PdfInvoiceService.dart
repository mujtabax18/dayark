import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/invoice_model.dart';

class PdfInvoiceService {
  static Future<pw.Document> buildPdf(Invoice invoice) async {
    final document = pw.Document();

    final logo = await _loadImage(invoice.logoPath);
    final background = await _loadImage(invoice.backgroundImagePath);
    final accent = _pdfColor(invoice.accentColorValue);
    final accentTint = _tint(invoice.accentColorValue, .91);
    final muted = PdfColor.fromHex('#64748B');
    final border = PdfColor.fromHex('#E2E8F0');
    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(34, 34, 34, 40),
      buildBackground: background == null
          ? null
          : (context) => pw.Container(
              width: double.infinity,
              height: double.infinity,
              alignment: pw.Alignment.center,
              child: pw.Opacity(
                opacity: invoice.backgroundOpacity.clamp(0.02, 0.20).toDouble(),
                child: pw.Image(
                  background,
                  width: 390,
                  height: 570,
                  fit: pw.BoxFit.contain,
                ),
              ),
            ),
    );

    document.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        footer: (context) => _footer(context, invoice, muted, border),
        build: (context) => [
          _header(invoice, logo, accent, accentTint, muted),
          pw.SizedBox(height: 22),
          _parties(invoice, accent, accentTint, muted, border),
          pw.SizedBox(height: 22),
          _items(invoice, accent, accentTint, muted, border),
          pw.SizedBox(height: 18),
          _totals(invoice, accent, accentTint, muted, border),
          pw.SizedBox(height: 20),
          _information(invoice, accent, accentTint, muted, border),
          pw.SizedBox(height: 28),
          _signatureArea(invoice, muted, border),
        ],
      ),
    );

    return document;
  }

  static Future<void> generateAndPreview(
    Invoice invoice,
    BuildContext context,
  ) async {
    try {
      final document = await buildPdf(invoice);
      final bytes = await document.save();
      if (!context.mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (previewContext) => Scaffold(
            appBar: AppBar(
              title: Text('Invoice #${invoice.number}'),
              actions: [
                IconButton(
                  tooltip: 'Save PDF anywhere',
                  onPressed: () => savePdf(
                    invoice,
                    context: previewContext,
                    preparedBytes: bytes,
                  ),
                  icon: const Icon(Icons.download_outlined),
                ),
              ],
            ),
            body: PdfPreview(
              build: (_) async => bytes,
              pdfFileName: _fileName(invoice),
              allowPrinting: true,
              allowSharing: true,
              canChangeOrientation: false,
              canChangePageFormat: false,
            ),
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not generate invoice PDF: $error')),
      );
    }
  }

  static Future<String?> savePdf(
    Invoice invoice, {
    BuildContext? context,
    Uint8List? preparedBytes,
  }) async {
    try {
      final bytes = preparedBytes ?? await (await buildPdf(invoice)).save();
      final location = await FilePicker.saveFile(
        dialogTitle: 'Save invoice PDF',
        fileName: _fileName(invoice),
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        bytes: bytes,
      );

      if (location == null || location.toFilePath().trim().isEmpty) {
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('PDF save cancelled.')));
        }
        return null;
      }

      // Desktop file pickers can return a path without writing the provided
      // bytes. Only write manually when a normal file-system path is returned.
      if (location.path.startsWith('/') ||
          RegExp(r'^[A-Za-z]:[\\/]').hasMatch(location.path)) {
        final file = File(location.path);
        if (!await file.exists() || await file.length() == 0) {
          await file.writeAsBytes(bytes, flush: true);
        }
      }

      if (context != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Invoice saved to $location')));
      }
      return location.path;
    } catch (error) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save PDF: $error')));
      }
      return null;
    }
  }

  static Future<void> sharePdf(Invoice invoice) async {
    final bytes = await (await buildPdf(invoice)).save();
    await Printing.sharePdf(bytes: bytes, filename: _fileName(invoice));
  }

  static Future<void> printPdf(Invoice invoice) async {
    final bytes = await (await buildPdf(invoice)).save();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static pw.Widget _header(
    Invoice invoice,
    pw.MemoryImage? logo,
    PdfColor accent,
    PdfColor accentTint,
    PdfColor muted,
  ) {
    switch (invoice.templateStyle) {
      case 'classic':
        return _classicHeader(invoice, logo, accent, muted);
      case 'minimal':
        return _minimalHeader(invoice, logo, accent, muted);
      default:
        return _modernHeader(invoice, logo, accent, accentTint, muted);
    }
  }

  static pw.Widget _modernHeader(
    Invoice invoice,
    pw.MemoryImage? logo,
    PdfColor accent,
    PdfColor accentTint,
    PdfColor muted,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: accentTint,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: accent, width: .8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (logo != null) ...[
            pw.Container(
              width: 72,
              height: 72,
              padding: const pw.EdgeInsets.all(5),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(width: 16),
          ],
          pw.Expanded(child: _businessBlock(invoice, muted, titleSize: 17)),
          pw.SizedBox(width: 16),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'INVOICE',
                style: pw.TextStyle(
                  color: accent,
                  fontSize: 25,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.8,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                '#${invoice.number}',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              _statusBadge(invoice.status, accent),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _classicHeader(
    Invoice invoice,
    pw.MemoryImage? logo,
    PdfColor accent,
    PdfColor muted,
  ) {
    return pw.Column(
      children: [
        if (logo != null)
          pw.Container(
            width: 85,
            height: 58,
            margin: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          ),
        pw.Text(
          invoice.businessName.isEmpty ? 'INVOICE' : invoice.businessName,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        if (invoice.businessAddress.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3),
            child: pw.Text(
              invoice.businessAddress,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(color: muted, fontSize: 9),
            ),
          ),
        pw.SizedBox(height: 14),
        pw.Container(height: 2, color: accent),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'INVOICE #${invoice.number}',
              style: pw.TextStyle(
                fontSize: 16,
                color: accent,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            _statusBadge(invoice.status, accent),
          ],
        ),
      ],
    );
  }

  static pw.Widget _minimalHeader(
    Invoice invoice,
    pw.MemoryImage? logo,
    PdfColor accent,
    PdfColor muted,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (logo != null) ...[
          pw.SizedBox(
            width: 62,
            height: 50,
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(width: 12),
        ],
        pw.Expanded(child: _businessBlock(invoice, muted, titleSize: 15)),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'INVOICE',
              style: pw.TextStyle(
                color: accent,
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              '#${invoice.number}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 6),
            _statusBadge(invoice.status, accent),
          ],
        ),
      ],
    );
  }

  static pw.Widget _businessBlock(
    Invoice invoice,
    PdfColor muted, {
    required double titleSize,
  }) {
    final lines = <String>[
      invoice.businessAddress,
      if (invoice.businessEmail != null) invoice.businessEmail!,
      if (invoice.businessPhone != null) invoice.businessPhone!,
      if (invoice.businessTaxId != null) 'Tax ID: ${invoice.businessTaxId}',
    ].where((value) => value.trim().isNotEmpty);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          invoice.businessName.isEmpty ? 'Your business' : invoice.businessName,
          style: pw.TextStyle(
            fontSize: titleSize,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 5),
        ...lines.map(
          (line) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Text(
              line,
              style: pw.TextStyle(color: muted, fontSize: 8.5),
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _parties(
    Invoice invoice,
    PdfColor accent,
    PdfColor accentTint,
    PdfColor muted,
    PdfColor border,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 6,
          child: _box(
            title: 'BILL TO',
            accent: accent,
            accentTint: accentTint,
            border: border,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  invoice.customerName,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  invoice.customerAddress,
                  style: pw.TextStyle(color: muted, fontSize: 9),
                ),
                if (invoice.customerEmail != null)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 2),
                    child: pw.Text(
                      invoice.customerEmail!,
                      style: pw.TextStyle(color: muted, fontSize: 9),
                    ),
                  ),
                if (invoice.customerPhone != null)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 2),
                    child: pw.Text(
                      invoice.customerPhone!,
                      style: pw.TextStyle(color: muted, fontSize: 9),
                    ),
                  ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 14),
        pw.Expanded(
          flex: 4,
          child: _box(
            title: 'INVOICE DETAILS',
            accent: accent,
            accentTint: accentTint,
            border: border,
            child: pw.Column(
              children: [
                _detailRow('Issue date', _date(invoice.date), muted),
                _detailRow('Due date', _date(invoice.dueDate), muted),
                if (invoice.purchaseOrderNumber != null)
                  _detailRow(
                    'PO / reference',
                    invoice.purchaseOrderNumber!,
                    muted,
                  ),
                _detailRow('Currency', invoice.currencySymbol, muted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _items(
    Invoice invoice,
    PdfColor accent,
    PdfColor accentTint,
    PdfColor muted,
    PdfColor border,
  ) {
    final rows = invoice.items
        .map((item) {
          final description = [
            if (item.sku != null) '[${item.sku}]',
            item.description,
          ].join(' ');
          return <String>[
            description,
            '${_quantity(item.quantity)} ${item.unit}',
            _money(invoice, item.unitPrice),
            item.discountPercent <= 0
                ? '—'
                : '${_quantity(item.discountPercent)}%',
            _money(invoice, item.total),
          ];
        })
        .toList(growable: false);

    return pw.Table.fromTextArray(
      headers: const [
        'Description',
        'Qty / unit',
        'Rate',
        'Discount',
        'Amount',
      ],
      data: rows,
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: border, width: .6),
        bottom: pw.BorderSide(color: border, width: .8),
        left: pw.BorderSide(color: border, width: .8),
        right: pw.BorderSide(color: border, width: .8),
        top: pw.BorderSide(color: border, width: .8),
      ),
      headerDecoration: pw.BoxDecoration(color: accent),
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontSize: 8.5,
        fontWeight: pw.FontWeight.bold,
      ),
      headerAlignment: pw.Alignment.centerLeft,
      cellStyle: const pw.TextStyle(fontSize: 8.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      cellAlignments: const {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      columnWidths: const {
        0: pw.FlexColumnWidth(3.4),
        1: pw.FlexColumnWidth(1.25),
        2: pw.FlexColumnWidth(1.25),
        3: pw.FlexColumnWidth(1.1),
        4: pw.FlexColumnWidth(1.4),
      },
      oddRowDecoration: pw.BoxDecoration(color: accentTint),
    );
  }

  static pw.Widget _totals(
    Invoice invoice,
    PdfColor accent,
    PdfColor accentTint,
    PdfColor muted,
    PdfColor border,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: invoice.paymentInfo.trim().isEmpty
              ? pw.SizedBox()
              : _box(
                  title: 'PAYMENT INFORMATION',
                  accent: accent,
                  accentTint: accentTint,
                  border: border,
                  child: pw.Text(
                    invoice.paymentInfo,
                    style: pw.TextStyle(color: muted, fontSize: 9),
                  ),
                ),
        ),
        pw.SizedBox(width: 18),
        pw.SizedBox(
          width: 225,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: accentTint,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: border),
            ),
            child: pw.Column(
              children: [
                _amountRow('Subtotal', invoice.subtotal, invoice, muted),
                if (invoice.itemDiscountTotal > 0)
                  _amountRow(
                    'Item discounts included',
                    -invoice.itemDiscountTotal,
                    invoice,
                    muted,
                    small: true,
                  ),
                if (invoice.discountAmount > 0)
                  _amountRow(
                    'Invoice discount',
                    -invoice.discountAmount,
                    invoice,
                    muted,
                  ),
                if (invoice.tax > 0)
                  _amountRow(
                    'Tax (${_quantity(invoice.taxRate)}%)',
                    invoice.tax,
                    invoice,
                    muted,
                  ),
                if (invoice.shippingAmount > 0)
                  _amountRow(
                    'Shipping / extra',
                    invoice.shippingAmount,
                    invoice,
                    muted,
                  ),
                pw.Divider(color: border),
                _amountRow(
                  'Total',
                  invoice.total,
                  invoice,
                  accent,
                  strong: true,
                ),
                if (invoice.paidAmount > 0)
                  _amountRow('Paid', -invoice.paidAmount, invoice, muted),
                pw.SizedBox(height: 5),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: pw.BoxDecoration(
                    color: accent,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'BALANCE DUE',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        _money(invoice, invoice.balanceDue),
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _information(
    Invoice invoice,
    PdfColor accent,
    PdfColor accentTint,
    PdfColor muted,
    PdfColor border,
  ) {
    final sections = <pw.Widget>[];

    if (invoice.notes != null) {
      sections.add(
        _box(
          title: 'NOTE',
          accent: accent,
          accentTint: accentTint,
          border: border,
          child: pw.Text(
            invoice.notes!,
            style: pw.TextStyle(color: muted, fontSize: 9),
          ),
        ),
      );
    }

    if (invoice.terms != null) {
      sections.add(
        _box(
          title: 'TERMS & CONDITIONS',
          accent: accent,
          accentTint: accentTint,
          border: border,
          child: pw.Text(
            invoice.terms!,
            style: pw.TextStyle(color: muted, fontSize: 9),
          ),
        ),
      );
    }

    if (sections.isEmpty) return pw.SizedBox();
    if (sections.length == 1) return sections.first;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(child: sections[0]),
        pw.SizedBox(width: 14),
        pw.Expanded(child: sections[1]),
      ],
    );
  }

  static pw.Widget _signatureArea(
    Invoice invoice,
    PdfColor muted,
    PdfColor border,
  ) {
    return pw.Column(
      children: [
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Container(height: 1, color: border),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Authorized signature',
                    style: pw.TextStyle(color: muted, fontSize: 8),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 55),
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Container(height: 1, color: border),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Customer signature',
                    style: pw.TextStyle(color: muted, fontSize: 8),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (invoice.footerText != null) ...[
          pw.SizedBox(height: 20),
          pw.Text(
            invoice.footerText!,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              color: muted,
              fontSize: 9,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  static pw.Widget _footer(
    pw.Context context,
    Invoice invoice,
    PdfColor muted,
    PdfColor border,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: border, width: .6)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            invoice.businessName,
            style: pw.TextStyle(color: muted, fontSize: 7.5),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(color: muted, fontSize: 7.5),
          ),
        ],
      ),
    );
  }

  static pw.Widget _box({
    required String title,
    required PdfColor accent,
    required PdfColor accentTint,
    required PdfColor border,
    required pw.Widget child,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: border),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: pw.BoxDecoration(
              color: accentTint,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                color: accent,
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: .7,
              ),
            ),
          ),
          pw.SizedBox(height: 9),
          child,
        ],
      ),
    );
  }

  static pw.Widget _detailRow(String label, String value, PdfColor muted) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 72,
            child: pw.Text(
              label,
              style: pw.TextStyle(color: muted, fontSize: 8),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _amountRow(
    String label,
    double amount,
    Invoice invoice,
    PdfColor color, {
    bool strong = false,
    bool small = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                color: color,
                fontSize: small ? 7.5 : 8.5,
                fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Text(
            '${amount < 0 ? '-' : ''}${_money(invoice, amount.abs())}',
            style: pw.TextStyle(
              color: color,
              fontSize: strong ? 11 : (small ? 7.5 : 8.5),
              fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _statusBadge(String status, PdfColor accent) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: accent, width: .8),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Text(
        _statusLabel(status).toUpperCase(),
        style: pw.TextStyle(
          color: accent,
          fontSize: 7.5,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static Future<pw.MemoryImage?> _loadImage(String? path) async {
    if (path == null || path.trim().isEmpty) return null;
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      return pw.MemoryImage(await file.readAsBytes());
    } catch (_) {
      return null;
    }
  }

  static PdfColor _pdfColor(int value) {
    return PdfColor(
      ((value >> 16) & 0xFF) / 255,
      ((value >> 8) & 0xFF) / 255,
      (value & 0xFF) / 255,
    );
  }

  static PdfColor _tint(int value, double amount) {
    final red = ((value >> 16) & 0xFF) / 255;
    final green = ((value >> 8) & 0xFF) / 255;
    final blue = (value & 0xFF) / 255;
    return PdfColor(
      red + (1 - red) * amount,
      green + (1 - green) * amount,
      blue + (1 - blue) * amount,
    );
  }

  static String _money(Invoice invoice, double value) {
    return '${invoice.currencySymbol}${value.toStringAsFixed(2)}';
  }

  static String _quantity(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }

  static String _date(DateTime value) =>
      DateFormat('dd MMM yyyy').format(value);

  static String _statusLabel(String status) {
    switch (status) {
      case 'partially_paid':
        return 'Partially paid';
      default:
        if (status.isEmpty) return 'Draft';
        return '${status[0].toUpperCase()}${status.substring(1)}';
    }
  }

  static String _fileName(Invoice invoice) {
    final safeNumber = invoice.number
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return 'invoice_${safeNumber.isEmpty ? invoice.id : safeNumber}.pdf';
  }
}
