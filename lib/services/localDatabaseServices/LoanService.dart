import '../db/drift_database.dart';

import '../../models/LoanModel.dart';
import '../database_service.dart';

class LoanService {
  LoanService(this._databaseService);

  final DatabaseService _databaseService;

  Future<int> addLoan(LoanModel loan) async {
    final db = await _databaseService.database;
    return db.insert(
      'loans',
      loan.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> updateLoan(LoanModel loan) async {
    if (loan.id == null) {
      throw ArgumentError('A loan ID is required for update.');
    }
    final db = await _databaseService.database;
    final values = loan.toMap()..remove('id');
    final result = await db.update(
      'loans',
      values,
      where: 'id = ?',
      whereArgs: <Object?>[loan.id],
    );
    await _checkAndUpdateLoanStatus(loan.id!);
    return result;
  }

  Future<int> archiveLoan(int id, {bool archived = true}) async {
    final db = await _databaseService.database;
    return db.update(
      'loans',
      <String, Object?>{
        'archived_at': archived ? DateTime.now().toIso8601String() : null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<int> deleteLoan(int id) async {
    final db = await _databaseService.database;
    return db.transaction<int>((txn) async {
      await txn.delete(
        'loan_transactions',
        where: 'loan_id = ?',
        whereArgs: <Object?>[id],
      );
      return txn.delete(
        'loans',
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }

  Future<List<LoanModel>> getLoans({
    int? type,
    String statusFilter = 'active',
    String query = '',
    String sort = 'smart',
    bool includeArchived = false,
  }) async {
    final db = await _databaseService.database;
    final where = <String>[];
    final args = <Object?>[];

    if (!includeArchived) {
      where.add('archived_at IS NULL');
    }
    if (type != null) {
      where.add('loan_type = ?');
      args.add(type);
    }
    switch (statusFilter) {
      case 'active':
        where.add('status = 0');
        break;
      case 'settled':
        where.add('status = 1');
        break;
      case 'overdue':
        where.add('status = 0');
        where.add("due_date IS NOT NULL AND TRIM(due_date) != ''");
        where.add("date(due_date) < date('now', 'localtime')");
        break;
      case 'due_soon':
        where.add('status = 0');
        where.add("due_date IS NOT NULL AND TRIM(due_date) != ''");
        where.add(
          "date(due_date) BETWEEN date('now', 'localtime') "
          "AND date('now', 'localtime', '+7 day')",
        );
        break;
      case 'all':
      default:
        break;
    }

    final normalizedQuery = query.trim();
    if (normalizedQuery.isNotEmpty) {
      where.add('''
        (entity_name LIKE ? COLLATE NOCASE
          OR phone LIKE ? COLLATE NOCASE
          OR reference_number LIKE ? COLLATE NOCASE
          OR category LIKE ? COLLATE NOCASE)
      ''');
      final token = '%$normalizedQuery%';
      args.addAll(<Object?>[token, token, token, token]);
    }

    final orderBy = switch (sort) {
      'name' => 'entity_name COLLATE NOCASE ASC',
      'balance_high' => '(amount + interest_amount) DESC, start_date DESC',
      'oldest' => 'start_date ASC, id ASC',
      'latest' => 'start_date DESC, id DESC',
      'due_date' =>
        "CASE WHEN due_date IS NULL OR TRIM(due_date) = '' THEN 1 ELSE 0 END, "
            'date(due_date) ASC, start_date DESC',
      _ =>
        "status ASC, CASE WHEN due_date IS NULL OR TRIM(due_date) = '' THEN 1 ELSE 0 END, "
            "CASE WHEN status = 0 AND date(due_date) < date('now', 'localtime') THEN 0 ELSE 1 END, "
            'date(due_date) ASC, updated_at DESC, id DESC',
    };

    final result = await db.query(
      'loans',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: orderBy,
    );
    return result.map(LoanModel.fromMap).toList(growable: false);
  }

  Future<LoanModel?> getLoanById(int id) async {
    final db = await _databaseService.database;
    final result = await db.query(
      'loans',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return result.isEmpty ? null : LoanModel.fromMap(result.first);
  }

  Future<int> addTransaction(LoanTransaction transaction) async {
    if (transaction.amount <= 0) {
      throw ArgumentError('Transaction amount must be greater than zero.');
    }
    final db = await _databaseService.database;
    final id = await db.insert(
      'loan_transactions',
      transaction.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    await _touchLoan(transaction.loanId);
    await _checkAndUpdateLoanStatus(transaction.loanId);
    return id;
  }

  Future<int> updateTransaction(LoanTransaction transaction) async {
    if (transaction.id == null) {
      throw ArgumentError('A transaction ID is required for update.');
    }
    if (transaction.amount <= 0) {
      throw ArgumentError('Transaction amount must be greater than zero.');
    }
    final db = await _databaseService.database;
    final values = transaction.toMap()..remove('id');
    final result = await db.update(
      'loan_transactions',
      values,
      where: 'id = ?',
      whereArgs: <Object?>[transaction.id],
    );
    await _touchLoan(transaction.loanId);
    await _checkAndUpdateLoanStatus(transaction.loanId);
    return result;
  }

  Future<List<LoanTransaction>> getTransactions(
    int loanId, {
    int? limit,
  }) async {
    final db = await _databaseService.database;
    final result = await db.query(
      'loan_transactions',
      where: 'loan_id = ?',
      whereArgs: <Object?>[loanId],
      orderBy: 'date DESC, id DESC',
      limit: limit,
    );
    return result.map(LoanTransaction.fromMap).toList(growable: false);
  }

  Future<int> deleteTransaction(int id, int loanId) async {
    final db = await _databaseService.database;
    final result = await db.delete(
      'loan_transactions',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    await _touchLoan(loanId);
    await _checkAndUpdateLoanStatus(loanId);
    return result;
  }

  Future<KhataAccountSnapshot> getAccountSnapshot(int loanId) async {
    final loan = await getLoanById(loanId);
    if (loan == null) {
      return const KhataAccountSnapshot(
        openingAmount: 0,
        addedCharges: 0,
        payments: 0,
        discounts: 0,
        outstanding: 0,
        entryCount: 0,
      );
    }

    final db = await _databaseService.database;
    final result = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE
          WHEN transaction_type IN ('charge', 'interest') THEN amount
          ELSE 0 END), 0) AS added_charges,
        COALESCE(SUM(CASE
          WHEN transaction_type = 'payment' THEN amount
          ELSE 0 END), 0) AS payments,
        COALESCE(SUM(CASE
          WHEN transaction_type = 'discount' THEN amount
          ELSE 0 END), 0) AS discounts,
        COUNT(*) AS entry_count,
        MAX(date) AS last_transaction_at
      FROM loan_transactions
      WHERE loan_id = ?
    ''', <Object?>[loanId]);

    final row = result.first;
    final opening = loan.totalAmount;
    final added = _toDouble(row['added_charges']);
    final payments = _toDouble(row['payments']);
    final discounts = _toDouble(row['discounts']);
    final outstanding = (opening + added - payments - discounts)
        .clamp(0, double.infinity)
        .toDouble();

    return KhataAccountSnapshot(
      openingAmount: opening,
      addedCharges: added,
      payments: payments,
      discounts: discounts,
      outstanding: outstanding,
      entryCount: _toInt(row['entry_count']),
      lastTransactionAt: row['last_transaction_at']?.toString(),
    );
  }

  /// Backward-compatible method used by older UI code.
  Future<double> getPaidAmount(int loanId) async {
    final snapshot = await getAccountSnapshot(loanId);
    return snapshot.totalCredits;
  }

  Future<KhataDashboardSummary> getDashboardSummary() async {
    final loans = await getLoans(
      statusFilter: 'all',
      includeArchived: false,
    );
    var toReceive = 0.0;
    var toPay = 0.0;
    var overdueAmount = 0.0;
    var overdueAccounts = 0;
    var activeAccounts = 0;
    var settledAccounts = 0;

    for (final loan in loans) {
      final snapshot = await getAccountSnapshot(loan.id!);
      if (snapshot.outstanding <= 0.005 || loan.isSettled) {
        settledAccounts++;
        continue;
      }
      activeAccounts++;
      if (loan.isGiven) {
        toReceive += snapshot.outstanding;
      } else {
        toPay += snapshot.outstanding;
      }
      if (loan.isOverdue) {
        overdueAccounts++;
        overdueAmount += snapshot.outstanding;
      }
    }

    final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1)
        .toIso8601String();
    final db = await _databaseService.database;
    final monthRows = await db.rawQuery('''
      SELECT
        l.loan_type,
        COALESCE(SUM(t.amount), 0) AS total
      FROM loan_transactions t
      INNER JOIN loans l ON l.id = t.loan_id
      WHERE t.transaction_type = 'payment'
        AND t.date >= ?
        AND l.archived_at IS NULL
      GROUP BY l.loan_type
    ''', <Object?>[monthStart]);

    var collectedThisMonth = 0.0;
    var paidThisMonth = 0.0;
    for (final row in monthRows) {
      final total = _toDouble(row['total']);
      if (_toInt(row['loan_type']) == 0) {
        collectedThisMonth = total;
      } else {
        paidThisMonth = total;
      }
    }

    return KhataDashboardSummary(
      toReceive: toReceive,
      toPay: toPay,
      overdueAmount: overdueAmount,
      overdueAccounts: overdueAccounts,
      activeAccounts: activeAccounts,
      settledAccounts: settledAccounts,
      collectedThisMonth: collectedThisMonth,
      paidThisMonth: paidThisMonth,
    );
  }

  Future<List<KhataMonthlyActivity>> getMonthlyActivity({
    int months = 6,
  }) async {
    final safeMonths = months.clamp(1, 24).toInt();
    final now = DateTime.now();
    final firstMonth = DateTime(now.year, now.month - safeMonths + 1, 1);
    final db = await _databaseService.database;
    final rows = await db.rawQuery('''
      SELECT
        substr(t.date, 1, 7) AS month_key,
        l.loan_type,
        t.transaction_type,
        COALESCE(SUM(t.amount), 0) AS total
      FROM loan_transactions t
      INNER JOIN loans l ON l.id = t.loan_id
      WHERE t.date >= ?
        AND l.archived_at IS NULL
      GROUP BY month_key, l.loan_type, t.transaction_type
      ORDER BY month_key ASC
    ''', <Object?>[firstMonth.toIso8601String()]);

    final map = <String, Map<String, double>>{};
    for (var index = 0; index < safeMonths; index++) {
      final month = DateTime(firstMonth.year, firstMonth.month + index, 1);
      final key = '${month.year.toString().padLeft(4, '0')}-'
          '${month.month.toString().padLeft(2, '0')}';
      map[key] = <String, double>{
        'received': 0,
        'paid': 0,
        'charges': 0,
      };
    }

    for (final row in rows) {
      final key = row['month_key']?.toString();
      if (key == null || !map.containsKey(key)) continue;
      final amount = _toDouble(row['total']);
      final type = row['transaction_type']?.toString() ?? 'payment';
      final loanType = _toInt(row['loan_type']);
      if (type == 'payment') {
        if (loanType == 0) {
          map[key]!['received'] = amount;
        } else {
          map[key]!['paid'] = amount;
        }
      } else if (type == 'charge' || type == 'interest') {
        map[key]!['charges'] = (map[key]!['charges'] ?? 0) + amount;
      }
    }

    return map.entries
        .map(
          (entry) => KhataMonthlyActivity(
            monthKey: entry.key,
            received: entry.value['received'] ?? 0,
            paid: entry.value['paid'] ?? 0,
            chargesAdded: entry.value['charges'] ?? 0,
          ),
        )
        .toList(growable: false);
  }

  Future<void> markReminderSent(int loanId) async {
    final db = await _databaseService.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'loans',
      <String, Object?>{
        'last_reminder_at': now,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: <Object?>[loanId],
    );
  }

  Future<void> _touchLoan(int loanId) async {
    final db = await _databaseService.database;
    await db.update(
      'loans',
      <String, Object?>{'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: <Object?>[loanId],
    );
  }

  Future<void> _checkAndUpdateLoanStatus(int loanId) async {
    final db = await _databaseService.database;
    final snapshot = await getAccountSnapshot(loanId);
    final newStatus = snapshot.outstanding <= 0.005 ? 1 : 0;
    await db.update(
      'loans',
      <String, Object?>{
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND status != ?',
      whereArgs: <Object?>[loanId, newStatus],
    );
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _toInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
