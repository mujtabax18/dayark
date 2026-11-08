import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;

import '../screens/notificationSettings/controller/notificationSettingController.dart';
import '../services/database_service.dart';
import '../services/localDatabaseServices/ReportService.dart';
import '../services/pdf/reportservice.dart';
import '../utlis/helper_functions.dart';

final reportServiceProvider = Provider<ReportService>((ref) {
  return ReportService(ref.read(databaseServiceProvider));
});

final pdfReportProvider =
    FutureProvider.family<Uint8List, Map<String, dynamic>>((ref, params) async {
  final service = ref.read(reportServiceProvider);
  final data = await service.getExpenseDataForReport(
    closingId: params['closingId'],
    startDate: params['startDate'],
    endDate: params['endDate'],
  );
  final title = await service.getClosingTitle(params['closingId']);
  return generateExpensePdf(expenseData: data);
});

final pdfReportProvider1 =
    FutureProvider.family<pw.Document, Map<String, dynamic>>(
        (ref, params) async {
  final service = ref.read(reportServiceProvider);

  final summaryData = await service.getSummaryData(
    closingId: params['closingId'],
    startDate: params['startDate'],
    endDate: params['endDate'],
  );

  final monthlyData = await service.getMonthlyData(
    closingId: params['closingId'],
    startDate: params['startDate'],
    endDate: params['endDate'],
  );

  final expenseDetails = await service.getExpenseDetails(
    closingId: params['closingId'],
    startDate: params['startDate'],
    endDate: params['endDate'],
  );

  return PdfReportService.generateExpenseReport(
    summaryData: summaryData,
    monthlyData: monthlyData,
    expenseDetails: expenseDetails,
    reportTitle: 'Expense Report',
    period: params['period'],
  );
});
