class ExpenseReportData {
  final DateTime startDate;
  final DateTime endDate;
  final double totalIn;
  final double totalOut;
  final int transactionCount;
  final List<ExpenseCategoryReport> categories;
  final List<ExpenseTrendPoint> trend;

  const ExpenseReportData({
    required this.startDate,
    required this.endDate,
    required this.totalIn,
    required this.totalOut,
    required this.transactionCount,
    required this.categories,
    required this.trend,
  });

  double get net => totalIn - totalOut;

  double get averageDailyExpense {
    final days = endDate.difference(startDate).inDays + 1;
    if (days <= 0) return totalOut;
    return totalOut / days;
  }

  ExpenseCategoryReport? get topExpenseCategory {
    final expenseCategories =
        categories.where((category) => category.totalOut > 0).toList();
    if (expenseCategories.isEmpty) return null;
    expenseCategories.sort((a, b) => b.totalOut.compareTo(a.totalOut));
    return expenseCategories.first;
  }
}

class ExpenseCategoryReport {
  final int id;
  final String title;
  final String? colorHex;
  final int? iconCode;
  final String? iconFontFamily;
  final bool hidden;
  final double totalIn;
  final double totalOut;
  final int itemCount;

  const ExpenseCategoryReport({
    required this.id,
    required this.title,
    this.colorHex,
    this.iconCode,
    this.iconFontFamily,
    required this.hidden,
    required this.totalIn,
    required this.totalOut,
    required this.itemCount,
  });

  double get net => totalIn - totalOut;
}

class ExpenseTrendPoint {
  final String label;
  final DateTime periodStart;
  final double totalIn;
  final double totalOut;

  const ExpenseTrendPoint({
    required this.label,
    required this.periodStart,
    required this.totalIn,
    required this.totalOut,
  });
}
