import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

import '../../controller/reportServiceProvider.dart';
import '../../utlis/filesave.dart';



// 1. Define the provider with complete PDF generation logic
final pdfReportProvider = FutureProvider.autoDispose.family<pw.Document, Map<String, dynamic>>((ref, params) async {
  final pdf = pw.Document();
  final dataService = ref.read(reportServiceProvider);

  // Get all required data
  final summaryData = await dataService.getSummaryData(
    closingId: params['closingId'],
    startDate: params['startDate'],
    endDate: params['endDate'],
  );

  final monthlyData = await dataService.getMonthlyData(
    closingId: params['closingId'],
    startDate: params['startDate'],
    endDate: params['endDate'],
  );

  final expenseDetails = await dataService.getExpenseDetails(
    closingId: params['closingId'],
    startDate: params['startDate'],
    endDate: params['endDate'],
  );

  // Page 1 - Summary
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.undefined,
      build: (pw.Context context) => _buildSummaryPage(
        data: summaryData,
        period: params['period'],
      ),
    ),
  );

  // Page 2 - Monthly Breakdown
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.undefined,
      build: (pw.Context context) => _buildMonthlyPage(
        data: monthlyData,
      ),
    ),
  );

  // Page 3 - Detailed Expenses
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.undefined,
      build: (pw.Context context) => _buildDetailsPage(
        data: expenseDetails,
      ),
    ),
  );

  return pdf;
});

// 2. Page building functions
pw.Widget _buildSummaryPage({
  required List<Map<String, dynamic>> data,
  required String period,
}) {
  final netIn = data.fold(0.0, (sum, item) => sum + (item['total_in'] as num));
  final netOut = data.fold(0.0, (sum, item) => sum + (item['total_out'] as num));
  final netBalance = netIn - netOut;

  return pw.Padding(padding: pw.EdgeInsets.all(10),child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Header(
        level: 0,
        child: pw.Text('Expense Report', style: pw.TextStyle(fontSize: 24)),
      ),
      pw.Paragraph(text: 'Period: $period'),
      pw.SizedBox(height: 20),
      pw.TableHelper.fromTextArray(
        headers: ['Category', 'Balance'],
        data: data.map((e) {
          final balance = (e['total_in'] as num) - (e['total_out'] as num);
          return [
            e['title'],
            pw.Text(
              _formatCurrency(balance),
              style: pw.TextStyle(
                color: balance > 0
                    ? PdfColors.green
                    : balance < 0
                    ? PdfColors.red
                    : PdfColors.black,
              ),
            ),
          ];
        }).toList(),
        headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
        headerDecoration: const pw.BoxDecoration(
          color: PdfColors.blue700,
        ),
        cellAlignment: pw.Alignment.centerRight,
        cellPadding: const pw.EdgeInsets.all(4),
      ),
      pw.Divider(),
      pw.SizedBox(height: 10),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Net In: ${_formatCurrency(netIn)}',
                style: pw.TextStyle(fontSize: 14, color: PdfColors.green),
              ),
              pw.Text(
                'Net Out: ${_formatCurrency(netOut)}',
                style: pw.TextStyle(fontSize: 14, color: PdfColors.red),
              ),
              pw.Text(
                'Net Balance: ${_formatCurrency(netBalance)}',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: netBalance >= 0 ? PdfColors.green : PdfColors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  ));
}


pw.Widget _buildMonthlyPage({
  required List<Map<String, dynamic>> data,
}) {
  // Get all month titles from the first item's keys (assuming all items have same months)
  final monthKeys = data.isNotEmpty
      ? data.first.keys.where((key) => key.endsWith('_in')).map((key) => key.replaceAll('_in', '')).toList()
      : <String>[];

  // Format month titles for display
  final monthTitles = monthKeys.map((key) {
    if (key == 'current') return 'Current';
    return key.replaceAll('_', ' ').capitalize();
  }).toList();

  return pw.Padding(
    padding: pw.EdgeInsets.all(10),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(
          level: 1,
          child: pw.Text('Monthly Breakdown by Category', style: pw.TextStyle(fontSize: 20)),
        ),
        pw.SizedBox(height: 15),
        pw.Table(
          border: pw.TableBorder.all(),
          defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
          columnWidths: _buildColumnWidths(monthTitles.length),
          children: [
            // Header Row
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _paddedCell('Category', isHeader: true),
                for (var title in monthTitles)
                  _paddedCell(title, isHeader: true),
              ],
            ),
            // Data Rows
            for (var category in data)
              pw.TableRow(
                children: [
                  _paddedCell(category['category']),
                  for (var i = 0; i < monthKeys.length; i++)
                    _buildMonthCell(category, monthKeys[i]),
                ],
              ),
            // Totals Row
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _paddedCell('TOTAL', isHeader: true),
                for (var i = 0; i < monthKeys.length; i++)
                  _buildMonthTotalCell(data, monthKeys[i]),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

// Helper functions
Map<int, pw.TableColumnWidth> _buildColumnWidths(int monthCount) {
  return {
    0: const pw.FixedColumnWidth(120),
    for (var i = 0; i < monthCount; i++)
      i + 1: const pw.FixedColumnWidth(100),
  };
}

pw.Widget _buildMonthCell(Map<String, dynamic> category, String monthKey) {
  final balance = (category['${monthKey}_in'] as num) - (category['${monthKey}_out'] as num);
  return _paddedCell(
    _formatCurrency(balance),
    textColor: balance > 0 ? PdfColors.green :balance == 0? PdfColors.black:PdfColors.red,
  );
}

pw.Widget _buildMonthTotalCell(List<Map<String, dynamic>> data, String monthKey) {
  final total = data.fold<num>(0, (sum, category) =>
  sum +
      (category['${monthKey}_in'] as num) -
      (category['${monthKey}_out'] as num)
  );
  return _paddedCell(_formatCurrency(total), isHeader: true);
}

// Add this extension for string capitalization
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}

/// Helper widget for cell padding and optional styling
pw.Widget _paddedCell(String text, {bool isHeader = false, PdfColor? textColor}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: textColor ?? PdfColors.black,
        fontSize: 10,
      ),
    ),
  );
}

pw.Widget _buildDetailsPage({
  required List<Map<String, dynamic>> data,
}) {
  // final sortedData = List<Map<String, dynamic>>.from(data)
  //   ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
  final  sortedData=data;
  debugPrint(data.toString());
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Header(
        level: 1,
        child: pw.Text('Detailed Expenses', style: pw.TextStyle(fontSize: 20)),
      ),
      pw.SizedBox(height: 15),
      pw.Table(
        border: pw.TableBorder.all(),
        children: [
          pw.TableRow(
            children: [
              for (var header in ['Date', 'Category', 'Item', 'Notes', 'Amount'])
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(header, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
            ],
          ),
          ...sortedData.map((expense) {
            final isIncome = expense['in_or_out'] == 'In';
            return pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(_formatDate(expense['date'])),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(expense['category_title']),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(expense['name']),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(expense['notes'] ?? ''),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    _formatCurrency(expense['price']),
                    style: pw.TextStyle(
                      color: isIncome ? PdfColors.green : PdfColors.red,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ],
      ),
    ],
  );
}


// 3. Helper functions
String _formatCurrency(num amount) {
  return '${amount >= 0 ? '+' : '-'}\$${amount.abs().toStringAsFixed(2)}';
}

String _formatDate(String dateString) {
  try {
    return DateFormat('MMM dd, yyyy').format(DateTime.parse(dateString));
  } catch (e) {
    return dateString;
  }
}

// 4. Main export function
Future<void> generateAndShareExpenseReport({
  required BuildContext context,
  required WidgetRef ref,
  String? closingId,
  String? startDate,
  String? endDate,
}) async {
  final scaffoldMessenger = ScaffoldMessenger.of(context);

  // try {
    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('Generating PDF report...')),
    );

    final period = startDate != null && endDate != null
        ? '${DateFormat('MMM d, yyyy').format(DateTime.parse(startDate))} - ${DateFormat('MMM d, yyyy').format(DateTime.parse(endDate))}'
        : 'All Time';

    final pdfDoc = await ref.read(pdfReportProvider({
      'closingId': closingId,
      'startDate': startDate,
      'endDate': endDate,
      'period': period,
    }).future);

    final bytes = await pdfDoc.save();
    await FileSaver.saveAndSharePdf(
      bytes,
      'Expense_Report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
    );

    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('PDF report generated successfully')),
    );
  // } catch (e) {
  //   scaffoldMessenger.showSnackBar(
  //     SnackBar(content: Text('Failed to generate PDF: ${e.toString()}')),
  //   );
  //   debugPrint('PDF Generation Error: $e');
  //
  //   // Show detailed error dialog in debug mode
  //   assert(() {
  //     showDialog(
  //       context: context,
  //       builder: (ctx) => AlertDialog(
  //         title: const Text('PDF Generation Failed'),
  //         content: Text(e.toString()),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.pop(ctx),
  //             child: const Text('OK'),
  //           ),
  //         ],
  //       ),
  //     );
  //     return true;
  //   }());
  // }
}