import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

Future<void> launchUrlString(String url) async {
  if (!await launchUrl(Uri.parse(url))) {
    throw Exception('Could not launch $url');
  }
}

void copyToClipboard(BuildContext context, String text) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Copied "$text" to clipboard!')),
  );
}

String? getFileExtension(String filePath) {
  return path.extension(filePath).toLowerCase(); // Returns the extension with a dot (e.g., ".txt")
}

double sumTotalInOut(List<Map<String, dynamic>> data, String id) {
  return data.fold(0, (sum, item) => sum + (item[id] ?? 0));
}

Future<Uint8List> generateExpensePdf({
  required List<Map<String, dynamic>> expenseData,
  String? closingId,
  String? startDate,
  String? endDate,
}) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.Page(
      build: (pw.Context context) {
        return pw.Column(
          children: [
            pw.Header(level: 0, text: 'Expense Report'),
            pw.Table.fromTextArray(
              context: context,
              data: [
                ['Title', 'Income', 'Expense', 'Balance'],
                ...expenseData.map((e) => [
                  e['title'],
                  e['total_in'].toString(),
                  e['total_out'].toString(),
                  (e['total_in'] - e['total_out']).toString(),
                ]),
              ],
            ),
          ],
        );
      },
    ),
  );

  return pdf.save();
}




String generateExpenseCsv(List<Map<String, dynamic>> expenseData) {
  final csvRows = <String>[];

  // Add header
  csvRows.add('Category,Income,Expense,Balance');

  // Add data rows
  for (final expense in expenseData) {
    final balance = expense['total_in'] - expense['total_out'];
    csvRows.add([
      '"${expense['title']}"',
      expense['total_in'].toStringAsFixed(2),
      expense['total_out'].toStringAsFixed(2),
      balance.toStringAsFixed(2),
    ].join(','));
  }

  // Add totals
  csvRows.add('');
  csvRows.add('Total Income,${_calculateTotal(expenseData, 'total_in').toStringAsFixed(2)},,');
  csvRows.add('Total Expense,,${_calculateTotal(expenseData, 'total_out').toStringAsFixed(2)},');
  csvRows.add('Net Balance,,,${_calculateNetBalance(expenseData).toStringAsFixed(2)}');

  return csvRows.join('\n');
}

// Helper functions
String _getPeriodText(String? closingId, String? startDate, String? endDate) {
  if (startDate != null && endDate != null) {
    return 'Period: ${DateFormat('MMM d, yyyy').format(DateTime.parse(startDate))} to ${DateFormat('MMM d, yyyy').format(DateTime.parse(endDate))}';
  } else if (closingId != null && closingId != 'all') {
    return closingId == 'latest' ? 'Latest Closing Period' : 'Closing ID: $closingId';
  }
  return '';
}

double _calculateTotal(List<Map<String, dynamic>> data, String key) {
  return data.fold(0.0, (sum, item) => sum + (item[key] as num));
}

double _calculateNetBalance(List<Map<String, dynamic>> data) {
  return _calculateTotal(data, 'total_in') - _calculateTotal(data, 'total_out');
}

