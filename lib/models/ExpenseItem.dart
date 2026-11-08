import 'expense_category_data.dart';

class ExpenseItem {
  int? id;
  final String? uuid;
  final String name;
  DateTime date;
  final int expenseId;
  final double? price;
  final String? inOrOut;
  final String? notes;
  final int? closingId;
  final DateTime? creationDate;
  final DateTime? updatationDate;
  final DateTime? deletedAt;

  ExpenseItem({
    this.id,
    this.uuid,
    required this.name,
    required this.date,
    required this.expenseId,
    this.price,
    this.inOrOut,
    this.notes,
    this.closingId,
    this.creationDate,
    this.updatationDate,
    this.deletedAt,
  });

  Map<String, dynamic> toMap({bool forUpdate = false}) {
    final map = <String, dynamic>{
      'name': name.trim(),
      'date': date.toIso8601String(),
      'expense_id': expenseId,
      'price': price ?? 0,
      'in_or_out': inOrOut ?? 'Out',
      'notes': notes?.trim(),
      'closing_id': closingId,
    };

    if (uuid != null) map['uuid'] = uuid;
    if (creationDate != null) {
      map['creation_date'] = creationDate!.toIso8601String();
    }
    if (updatationDate != null) {
      map['updatation_date'] = updatationDate!.toIso8601String();
    }
    if (deletedAt != null) map['deleted_at'] = deletedAt!.toIso8601String();
    if (!forUpdate && id != null) map['id'] = id;

    return map;
  }

  factory ExpenseItem.fromMap(Map<String, dynamic> map) {
    return ExpenseItem(
      id: _asInt(map['id']),
      uuid: map['uuid']?.toString(),
      name: map['name']?.toString() ?? '',
      date: _asDate(map['date']) ?? DateTime.now(),
      expenseId: _asInt(map['expense_id'] ?? map['expenseId']) ?? 0,
      price: _asDouble(map['price']),
      inOrOut: map['in_or_out']?.toString() ??
          map['inOrOut']?.toString() ??
          'Out',
      notes: map['notes']?.toString(),
      closingId: _asInt(map['closing_id'] ?? map['closingId']),
      creationDate: _asDate(map['creation_date']),
      updatationDate: _asDate(map['updatation_date']),
      deletedAt: _asDate(map['deleted_at']),
    );
  }

  factory ExpenseItem.fromExpenseItemData({
    required ExpenseItemData map,
    required int expenseId,
  }) {
    return ExpenseItem(
      id: map.id,
      name: map.name,
      date: DateTime.tryParse(map.date) ?? DateTime.now(),
      expenseId: expenseId,
      price: map.price,
      inOrOut: map.inOrOut,
      notes: map.notes,
      closingId: map.closingId,
    );
  }

  /// Keeps the original camelCase JSON contract used by older app code.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'name': name,
      'date': date,
      'expenseId': expenseId,
      'price': price,
      'inOrOut': inOrOut,
      'notes': notes,
      'closingId': closingId,
      'creationDate': creationDate,
      'updatationDate': updatationDate,
      'deletedAt': deletedAt,
    };
  }

  factory ExpenseItem.fromJson(Map<String, dynamic> map) {
    return ExpenseItem(
      id: _asInt(map['id']),
      uuid: map['uuid']?.toString(),
      name: map['name']?.toString() ?? '',
      date: _asDate(map['date']) ?? DateTime.now(),
      expenseId: _asInt(map['expenseId'] ?? map['expense_id']) ?? 0,
      price: _asDouble(map['price']),
      inOrOut: map['inOrOut']?.toString() ??
          map['in_or_out']?.toString() ??
          'Out',
      notes: map['notes']?.toString(),
      closingId: _asInt(map['closingId'] ?? map['closing_id']),
      creationDate: _asDate(map['creationDate'] ?? map['creation_date']),
      updatationDate:
          _asDate(map['updatationDate'] ?? map['updatation_date']),
      deletedAt: _asDate(map['deletedAt'] ?? map['deleted_at']),
    );
  }

  ExpenseItem copyWith({
    int? id,
    String? uuid,
    String? name,
    DateTime? date,
    int? expenseId,
    double? price,
    String? inOrOut,
    String? notes,
    int? closingId,
    bool clearClosingId = false,
    DateTime? creationDate,
    DateTime? updatationDate,
    DateTime? deletedAt,
  }) {
    return ExpenseItem(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      date: date ?? this.date,
      expenseId: expenseId ?? this.expenseId,
      price: price ?? this.price,
      inOrOut: inOrOut ?? this.inOrOut,
      notes: notes ?? this.notes,
      closingId: clearClosingId ? null : (closingId ?? this.closingId),
      creationDate: creationDate ?? this.creationDate,
      updatationDate: updatationDate ?? this.updatationDate,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static DateTime? _asDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
