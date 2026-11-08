class LoanModel {
  const LoanModel({
    this.id,
    required this.entityName,
    required this.loanType,
    required this.amount,
    this.interestAmount = 0,
    required this.startDate,
    this.dueDate,
    this.status = 0,
    String? notes,
    this.phone = '',
    this.address = '',
    this.category = 'General',
    this.referenceNumber = '',
    this.currencyCode = 'PKR',
    this.installmentFrequency = 'none',
    this.installmentAmount = 0,
    this.reminderEnabled = true,
    this.reminderDaysBefore = 3,
    this.lastReminderAt,
    this.createdAt,
    this.updatedAt,
    this.archivedAt,
  }) : notes = notes ?? '';

  final int? id;
  final String entityName;

  /// 0 = money to receive, 1 = money to pay.
  final int loanType;
  final double amount;
  final double interestAmount;
  final String startDate;
  final String? dueDate;

  /// 0 = active, 1 = settled.
  final int status;
  final String notes;
  final String phone;
  final String address;
  final String category;
  final String referenceNumber;
  final String currencyCode;
  final String installmentFrequency;
  final double installmentAmount;
  final bool reminderEnabled;
  final int reminderDaysBefore;
  final String? lastReminderAt;
  final String? createdAt;
  final String? updatedAt;
  final String? archivedAt;

  double get totalAmount => amount + interestAmount;
  bool get isGiven => loanType == 0;
  bool get isTaken => loanType == 1;
  bool get isSettled => status == 1;
  bool get isArchived => archivedAt != null && archivedAt!.trim().isNotEmpty;

  DateTime? get dueDateTime => _tryDate(dueDate);
  DateTime get startDateTime =>
      _tryDate(startDate) ?? DateTime.fromMillisecondsSinceEpoch(0);

  bool get isOverdue {
    final due = dueDateTime;
    if (due == null || isSettled) return false;
    return _dateOnly(due).isBefore(_dateOnly(DateTime.now()));
  }

  int get daysOverdue {
    final due = dueDateTime;
    if (due == null || !isOverdue) return 0;
    return _dateOnly(DateTime.now()).difference(_dateOnly(due)).inDays;
  }

  int get daysUntilDue {
    final due = dueDateTime;
    if (due == null) return 999999;
    return _dateOnly(due).difference(_dateOnly(DateTime.now())).inDays;
  }

  LoanModel copyWith({
    int? id,
    String? entityName,
    int? loanType,
    double? amount,
    double? interestAmount,
    String? startDate,
    String? dueDate,
    bool clearDueDate = false,
    int? status,
    String? notes,
    String? phone,
    String? address,
    String? category,
    String? referenceNumber,
    String? currencyCode,
    String? installmentFrequency,
    double? installmentAmount,
    bool? reminderEnabled,
    int? reminderDaysBefore,
    String? lastReminderAt,
    bool clearLastReminderAt = false,
    String? createdAt,
    String? updatedAt,
    String? archivedAt,
    bool clearArchivedAt = false,
  }) {
    return LoanModel(
      id: id ?? this.id,
      entityName: entityName ?? this.entityName,
      loanType: loanType ?? this.loanType,
      amount: amount ?? this.amount,
      interestAmount: interestAmount ?? this.interestAmount,
      startDate: startDate ?? this.startDate,
      dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      category: category ?? this.category,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      currencyCode: currencyCode ?? this.currencyCode,
      installmentFrequency:
          installmentFrequency ?? this.installmentFrequency,
      installmentAmount: installmentAmount ?? this.installmentAmount,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      lastReminderAt: clearLastReminderAt
          ? null
          : lastReminderAt ?? this.lastReminderAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt:
          clearArchivedAt ? null : archivedAt ?? this.archivedAt,
    );
  }

  Map<String, dynamic> toMap() {
    final now = DateTime.now().toIso8601String();
    return <String, dynamic>{
      if (id != null) 'id': id,
      'entity_name': entityName.trim(),
      'loan_type': loanType,
      'amount': amount,
      'interest_amount': interestAmount,
      'start_date': startDate,
      'due_date': dueDate,
      'status': status,
      'notes': notes.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
      'category': category.trim().isEmpty ? 'General' : category.trim(),
      'reference_number': referenceNumber.trim(),
      'currency_code': currencyCode.trim().isEmpty ? 'PKR' : currencyCode,
      'installment_frequency': installmentFrequency,
      'installment_amount': installmentAmount,
      'reminder_enabled': reminderEnabled ? 1 : 0,
      'reminder_days_before': reminderDaysBefore,
      'last_reminder_at': lastReminderAt,
      'created_at': createdAt ?? now,
      'updated_at': now,
      'archived_at': archivedAt,
    };
  }

  factory LoanModel.fromMap(Map<String, dynamic> map) {
    return LoanModel(
      id: _asInt(map['id']),
      entityName: _asString(map['entity_name']),
      loanType: _asInt(map['loan_type']) ?? 0,
      amount: _asDouble(map['amount']),
      interestAmount: _asDouble(map['interest_amount']),
      startDate: _asString(map['start_date']).isEmpty
          ? DateTime.now().toIso8601String()
          : _asString(map['start_date']),
      dueDate: _nullableString(map['due_date']),
      status: _asInt(map['status']) ?? 0,
      notes: _asString(map['notes']),
      phone: _asString(map['phone']),
      address: _asString(map['address']),
      category: _asString(map['category']).isEmpty
          ? 'General'
          : _asString(map['category']),
      referenceNumber: _asString(map['reference_number']),
      currencyCode: _asString(map['currency_code']).isEmpty
          ? 'PKR'
          : _asString(map['currency_code']),
      installmentFrequency: _asString(map['installment_frequency']).isEmpty
          ? 'none'
          : _asString(map['installment_frequency']),
      installmentAmount: _asDouble(map['installment_amount']),
      reminderEnabled: (_asInt(map['reminder_enabled']) ?? 1) == 1,
      reminderDaysBefore: _asInt(map['reminder_days_before']) ?? 3,
      lastReminderAt: _nullableString(map['last_reminder_at']),
      createdAt: _nullableString(map['created_at']),
      updatedAt: _nullableString(map['updated_at']),
      archivedAt: _nullableString(map['archived_at']),
    );
  }
}

class LoanTransaction {
  const LoanTransaction({
    this.id,
    required this.loanId,
    required this.amount,
    required this.date,
    String? note,
    this.transactionType = 'payment',
    this.paymentMethod = 'cash',
    this.referenceNumber = '',
    this.createdAt,
  }) : note = note ?? '';

  final int? id;
  final int loanId;
  final double amount;
  final String date;
  final String note;

  /// payment/discount reduce the outstanding amount.
  /// charge/interest increase the outstanding amount.
  final String transactionType;
  final String paymentMethod;
  final String referenceNumber;
  final String? createdAt;

  bool get reducesBalance =>
      transactionType == 'payment' || transactionType == 'discount';
  bool get increasesBalance =>
      transactionType == 'charge' || transactionType == 'interest';

  double get signedOutstandingEffect => increasesBalance ? amount : -amount;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'loan_id': loanId,
      'amount': amount,
      'date': date,
      'note': note.trim(),
      'transaction_type': transactionType,
      'payment_method': paymentMethod,
      'reference_number': referenceNumber.trim(),
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
    };
  }

  factory LoanTransaction.fromMap(Map<String, dynamic> map) {
    return LoanTransaction(
      id: _asInt(map['id']),
      loanId: _asInt(map['loan_id']) ?? 0,
      amount: _asDouble(map['amount']),
      date: _asString(map['date']).isEmpty
          ? DateTime.now().toIso8601String()
          : _asString(map['date']),
      note: _asString(map['note']),
      transactionType: _asString(map['transaction_type']).isEmpty
          ? 'payment'
          : _asString(map['transaction_type']),
      paymentMethod: _asString(map['payment_method']).isEmpty
          ? 'cash'
          : _asString(map['payment_method']),
      referenceNumber: _asString(map['reference_number']),
      createdAt: _nullableString(map['created_at']),
    );
  }
}

class KhataAccountSnapshot {
  const KhataAccountSnapshot({
    required this.openingAmount,
    required this.addedCharges,
    required this.payments,
    required this.discounts,
    required this.outstanding,
    required this.entryCount,
    this.lastTransactionAt,
  });

  final double openingAmount;
  final double addedCharges;
  final double payments;
  final double discounts;
  final double outstanding;
  final int entryCount;
  final String? lastTransactionAt;

  double get totalCredits => payments + discounts;
  double get totalDebit => openingAmount + addedCharges;
  double get progress => totalDebit <= 0
      ? 0
      : (totalCredits / totalDebit).clamp(0.0, 1.0).toDouble();
}

class KhataDashboardSummary {
  const KhataDashboardSummary({
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

class KhataMonthlyActivity {
  const KhataMonthlyActivity({
    required this.monthKey,
    required this.received,
    required this.paid,
    required this.chargesAdded,
  });

  final String monthKey;
  final double received;
  final double paid;
  final double chargesAdded;
}

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

DateTime? _tryDate(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return DateTime.tryParse(value);
}

String _asString(dynamic value) => value?.toString() ?? '';

String? _nullableString(dynamic value) {
  final text = _asString(value).trim();
  return text.isEmpty ? null : text;
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double _asDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}
