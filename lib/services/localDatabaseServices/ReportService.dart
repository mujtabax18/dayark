import 'package:flutter/material.dart';

import '../../screens/Expenses/controller/ExpensesController.dart';
import '../../screens/Grocery/Grocery/controller/grocery_controller.dart';
import '../database_service.dart';
import 'monthClosing.dart';

class ReportService {
  final DatabaseService dbService;

  ReportService(this.dbService);

  Future<List<Map<String, dynamic>>> getExpenseDataForReport({
    String? closingId, // null = latest
    String? startDate,
    String? endDate,
  }) async {
    final db = await dbService.database;

    String closingCondition = '';
    if (closingId != null && closingId != 'all') {
      closingCondition = closingId == 'latest'
          ? "AND ei.closing_id = (SELECT MAX(id) FROM month_closing)"
          : "AND ei.closing_id = $closingId";
    }

    String dateCondition = '';
    if (startDate != null && endDate != null) {
      dateCondition = "AND ei.date BETWEEN '$startDate' AND '$endDate'";
    }

    return await db.rawQuery('''
      SELECT 
        et.id,
        et.title, 
        COALESCE(SUM(CASE WHEN ei.in_or_out = 'In' THEN ei.price ELSE 0 END), 0) AS total_in,
        COALESCE(SUM(CASE WHEN ei.in_or_out = 'Out' THEN ei.price ELSE 0 END), 0) AS total_out
      FROM expense_titles et
      LEFT JOIN expense_items ei ON et.id = ei.expense_id
      WHERE 1=1
        $closingCondition
        $dateCondition
      GROUP BY et.id, et.title
      ORDER BY et.title ASC
    ''');
  }

  Future<String?> getClosingTitle(String? closingId) async {
    if (closingId == null || closingId == 'latest') {
      final db = await dbService.database;
      final result = await db
          .rawQuery('SELECT title FROM month_closing ORDER BY id DESC LIMIT 1');
      return result.isNotEmpty ? result.first['title'] as String : null;
    }
    return closingId;
  }

  Future<List<Map<String, dynamic>>> getSummaryData({
    String? closingId,
    String? startDate,
    String? endDate,
  }) async {
    final db = await dbService.database;
    return await db.rawQuery('''
      SELECT 
        et.id,
        et.title, 
        COALESCE(SUM(CASE WHEN ei.in_or_out = 'In' THEN ei.price ELSE 0 END), 0) AS total_in,
        COALESCE(SUM(CASE WHEN ei.in_or_out = 'Out' THEN ei.price ELSE 0 END), 0) AS total_out
      FROM expense_titles et
      LEFT JOIN expense_items ei ON et.id = ei.expense_id
      WHERE 1=1
        ${_buildClosingCondition(closingId)}
        ${_buildDateCondition(startDate, endDate)}
      GROUP BY et.id, et.title
      ORDER BY et.title ASC
    ''');
  }

  /// todo: update this for pdf
  Future<List<Map<String, dynamic>>> getMonthlyData({
    String? closingId,
    String? startDate,
    String? endDate,
  }) async {
    final db = await dbService.database;

    final monthClosingHelper = MonthClosingHelper(databaseService);
    final months = await monthClosingHelper.getAllClosings();

    /// Build month CASE columns safely
    final monthCases = months.map((month) {
      final monthKey = month.title.toLowerCase().replaceAll(' ', '_');
      return '''
      COALESCE(
        SUM(CASE WHEN mc.id = ${month.id} AND ei.in_or_out = 'Out' THEN ei.price ELSE 0 END),
        0
      ) AS ${monthKey}_out,
      COALESCE(
        SUM(CASE WHEN mc.id = ${month.id} AND ei.in_or_out = 'In' THEN ei.price ELSE 0 END),
        0
      ) AS ${monthKey}_in
    ''';
    }).join(',\n');

    /// Add comma ONLY if monthCases is not empty
    final monthCasesSql = monthCases.isNotEmpty ? '$monthCases,\n' : '';

    final sql = '''
    SELECT
      et.title AS category,
      $monthCasesSql
      COALESCE(
        SUM(CASE WHEN mc.id IS NULL AND ei.in_or_out = 'Out' THEN ei.price ELSE 0 END),
        0
      ) AS current_out,
      COALESCE(
        SUM(CASE WHEN mc.id IS NULL AND ei.in_or_out = 'In' THEN ei.price ELSE 0 END),
        0
      ) AS current_in
    FROM expense_titles et
    LEFT JOIN expense_items ei ON et.id = ei.expense_id
    LEFT JOIN month_closing mc ON mc.id = ei.closing_id
    WHERE 1=1
      ${_buildClosingCondition(closingId)}
      ${_buildDateCondition(startDate, endDate)}
    GROUP BY et.id, et.title
    ORDER BY et.title ASC
  ''';

    return await db.rawQuery(sql);
  }

  Future<List<Map<String, dynamic>>> getExpenseDetails({
    String? closingId,
    String? startDate,
    String? endDate,
  }) async {
    final db = await dbService.database;
    debugPrint('got closingId===========> ${closingId}');
    return await db.rawQuery('''
      SELECT 
        ei.date,
        et.title AS category_title,
        ei.name,
        ei.notes,
        ei.price,
        ei.in_or_out
      FROM expense_items ei
      JOIN expense_titles et ON ei.expense_id = et.id
      LEFT JOIN month_closing mc ON ei.closing_id = mc.id
      WHERE 1=1
        ${_buildClosingCondition(closingId)}
        ${_buildDateCondition(startDate, endDate)}
      ORDER BY ei.date ASC
    ''');
  }

  String _buildClosingCondition(String? closingId) {
    if (closingId == null || closingId.isEmpty) return '';
    return closingId == 'latest'
        ? "AND ei.closing_id IS NULL" // Correct condition for unclosed expenses
        : closingId == 'all'
            ? ''
            : "AND ei.closing_id = $closingId";
  }

  String _buildDateCondition(String? startDate, String? endDate) {
    if (startDate == null || endDate == null) return '';
    return "AND ei.date BETWEEN '$startDate' AND '$endDate'";
  }
}
