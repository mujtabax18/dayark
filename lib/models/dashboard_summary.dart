class DashboardSummary {
  const DashboardSummary({
    required this.expenses,
    required this.meters,
    required this.habits,
    required this.grocery,
    required this.pills,
    required this.loans,
    required this.invoiceCount,
    required this.mediaFileCount,
    required this.scannedPageCount,
    required this.diaryEntryCount,
  });

  final ExpenseHomeSummary expenses;
  final MeterHomeSummary meters;
  final HabitHomeSummary habits;
  final GroceryHomeSummary grocery;
  final PillHomeSummary pills;
  final LoanHomeSummary loans;
  final int invoiceCount;
  final int mediaFileCount;
  final int scannedPageCount;
  final int diaryEntryCount;

  bool get hasExpenseSummary => expenses.transactionCount > 0;
  bool get hasMeterSummary => meters.items.isNotEmpty;
  bool get hasHabitSummary => habits.items.isNotEmpty;
  bool get hasGrocerySummary => grocery.entries.isNotEmpty;
  bool get hasPillSummary => pills.occurrences.isNotEmpty;
  bool get hasLoanSummary => loans.activeAccounts > 0;
  bool get hasInvoiceSummary => invoiceCount > 0;
  bool get hasMediaSummary => mediaFileCount > 0;
  bool get hasScannerSummary => scannedPageCount > 0;
  bool get hasDiarySummary => diaryEntryCount > 0;

  bool get hasAnySummary =>
      hasExpenseSummary ||
      hasMeterSummary ||
      hasHabitSummary ||
      hasGrocerySummary ||
      hasPillSummary ||
      hasLoanSummary ||
      hasInvoiceSummary ||
      hasMediaSummary ||
      hasScannerSummary ||
      hasDiarySummary;

  bool hasSummaryForFeature(int featureId) {
    return switch (featureId) {
      1 => hasMeterSummary,
      2 => hasGrocerySummary,
      3 => hasExpenseSummary,
      5 => hasDiarySummary,
      6 => hasHabitSummary,
      8 => hasInvoiceSummary,
      9 => hasLoanSummary,
      10 => hasMediaSummary,
      11 => hasPillSummary,
      12 => hasScannerSummary,
      _ => false,
    };
  }

  List<int> availableSummaryIds(Iterable<int> preferredOrder) {
    final ordered = <int>[];
    for (final id in preferredOrder) {
      if (hasSummaryForFeature(id) && !ordered.contains(id)) {
        ordered.add(id);
      }
    }
    return ordered;
  }
}

class ExpenseHomeSummary {
  const ExpenseHomeSummary({
    required this.income,
    required this.expense,
    required this.categoryCount,
    required this.transactionCount,
  });

  final double income;
  final double expense;
  final int categoryCount;
  final int transactionCount;

  double get remaining => income - expense;
}

class MeterHomeSummary {
  const MeterHomeSummary({
    required this.items,
    required this.totalUnitsUsed,
  });

  final List<MeterHomeItem> items;
  final double totalUnitsUsed;
}

class MeterHomeItem {
  const MeterHomeItem({
    required this.id,
    required this.name,
    required this.unitLabel,
    required this.colorValue,
    required this.iconKey,
    required this.unitsUsed,
    this.baseline,
    this.latestReading,
  });

  final int id;
  final String name;
  final String unitLabel;
  final int colorValue;
  final String iconKey;
  final double? baseline;
  final double? latestReading;
  final double unitsUsed;
}

class HabitHomeSummary {
  const HabitHomeSummary({required this.items});

  final List<HabitHomeItem> items;

  int get completed => items.where((item) => item.isCompleted).length;
  int get due => items.where((item) => !item.isCompleted).length;
  int get total => items.length;
  double get completionRate => total == 0 ? 0 : completed / total;
}

class HabitHomeItem {
  const HabitHomeItem({
    required this.id,
    required this.title,
    required this.category,
    required this.deadlineHour,
    required this.deadlineMinute,
    required this.isCompleted,
    required this.canComplete,
    required this.currentStreak,
    required this.colorValue,
    required this.iconCode,
    this.description,
  });

  final int id;
  final String title;
  final String? description;
  final String category;
  final int deadlineHour;
  final int deadlineMinute;
  final bool isCompleted;
  final bool canComplete;
  final int currentStreak;
  final int colorValue;
  final int iconCode;
}

class GroceryHomeSummary {
  const GroceryHomeSummary({
    required this.planCount,
    required this.pendingItems,
    required this.pendingChores,
    required this.overdue,
    required this.entries,
  });

  final int planCount;
  final int pendingItems;
  final int pendingChores;
  final int overdue;
  final List<GroceryHomeEntry> entries;

  int get totalRemaining => pendingItems + pendingChores;
}

class GroceryHomeEntry {
  const GroceryHomeEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.priority,
    required this.isOverdue,
    this.groceryId,
    this.subtitle,
  });

  final int id;
  final String kind;
  final String title;
  final String? subtitle;
  final String priority;
  final bool isOverdue;
  final int? groceryId;

  bool get isChore => kind == 'chore';
}

class PillHomeSummary {
  const PillHomeSummary({
    required this.pending,
    required this.taken,
    required this.missed,
    required this.skipped,
    required this.occurrences,
  });

  final int pending;
  final int taken;
  final int missed;
  final int skipped;
  final List<PillHomeOccurrence> occurrences;

  int get total => pending + taken + missed + skipped;
}

class PillHomeOccurrence {
  const PillHomeOccurrence({
    required this.id,
    required this.pillName,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.status,
    required this.colorHex,
    required this.canTake,
    this.dosage,
    this.notes,
  });

  final int id;
  final String pillName;
  final String scheduledDate;
  final String scheduledTime;
  final String status;
  final String colorHex;
  final bool canTake;
  final String? dosage;
  final String? notes;
}

class LoanHomeSummary {
  const LoanHomeSummary({
    required this.toReceive,
    required this.toPay,
    required this.overdueAmount,
    required this.overdueAccounts,
    required this.activeAccounts,
    required this.settledAccounts,
    required this.collectedThisMonth,
    required this.paidThisMonth,
  });

  final double toReceive;
  final double toPay;
  final double overdueAmount;
  final int overdueAccounts;
  final int activeAccounts;
  final int settledAccounts;
  final double collectedThisMonth;
  final double paidThisMonth;
}
