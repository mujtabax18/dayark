// helper_functions.dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class PdfReportService {
  static Future<pw.Document> generateExpenseReport({
    required List<Map<String, dynamic>> summaryData,
    required List<Map<String, dynamic>> monthlyData,
    required List<Map<String, dynamic>> expenseDetails,
    String? reportTitle,
    String? period,
  }) async {
    final pdf = pw.Document();

    // First Page - Summary
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return _buildSummaryPage(
            data: summaryData,
            title: reportTitle,
            period: period,
          );
        },
      ),
    );

    // Second Page - Monthly Breakdown
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return _buildMonthlyPage(data: monthlyData);
        },
      ),
    );

    // Third Page - Detailed Expenses
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return _buildDetailsPage(data: expenseDetails);
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _buildSummaryPage({
    required List<Map<String, dynamic>> data,
    String? title,
    String? period,
  }) {
    final netBalance = data.fold(0.0, (sum, item) {
      final balance = (item['total_in'] as num) - (item['total_out'] as num);
      return sum + balance;
    });

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(
          level: 0,
          child: pw.Text(
            title ?? 'Expense Report',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
        ),
        if (period != null) pw.Text('Period: $period'),
        pw.SizedBox(height: 20),
        pw.Table.fromTextArray(
          context: null,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headers: ['Category', 'Income', 'Expense', 'Balance'],
          data: [
            ...data.map((e) {
              final balance = (e['total_in'] as num) - (e['total_out'] as num);
              return [
                e['title'],
                _formatCurrency(e['total_in']),
                _formatCurrency(e['total_out']),
                pw.Text(
                  _formatCurrency(balance),
                  style: pw.TextStyle(
                    color: balance >= 0 ? PdfColors.green : PdfColors.red,
                  ),
                ),
              ];
            }),
          ],
        ),
        pw.Divider(),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
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
    );
  }

  static pw.Widget _buildMonthlyPage({
    required List<Map<String, dynamic>> data,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(
          level: 1,
          child: pw.Text(
            'Monthly Breakdown',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 15),
        pw.Table.fromTextArray(
          context: null,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headers: ['Month', 'Category', 'Income', 'Expense', 'Balance'],
          data: data.expand((month) {
            final monthTitle = month['month_title'];
            return (month['categories'] as List).map((category) {
              final balance =
                  (category['total_in'] as num) - (category['total_out'] as num);
              return [
                monthTitle,
                category['title'],
                _formatCurrency(category['total_in']),
                _formatCurrency(category['total_out']),
                pw.Text(
                  _formatCurrency(balance),
                  style: pw.TextStyle(
                    color: balance >= 0 ? PdfColors.green : PdfColors.red,
                  ),
                ),
              ];
            });
          }).toList(),
        ),
      ],
    );
  }

  static pw.Widget _buildDetailsPage({
    required List<Map<String, dynamic>> data,
  }) {
    // Sort by date
    data.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(
          level: 1,
          child: pw.Text(
            'Detailed Expenses',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 15),
        pw.Table.fromTextArray(
          context: null,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headers: ['Date', 'Category', 'Item', 'Description', 'Amount'],
          data: data.map((expense) {
            return [
              _formatDate(expense['date']),
              expense['category_title'],
              expense['name'],
              expense['notes'] ?? '',
              pw.Text(
                _formatCurrency(expense['price']),
                style: pw.TextStyle(
                  color: (expense['in_or_out'] == 'In')
                      ? PdfColors.green
                      : PdfColors.red,
                ),
              ),
            ];
          }).toList(),
        ),
      ],
    );
  }

  static String _formatCurrency(num amount) {
    return '${amount >= 0 ? '+' : '-'}\$${amount.abs().toStringAsFixed(2)}';
  }

  static String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }
}