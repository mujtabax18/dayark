class MonthClosing {
  final int id;
  final String? uuid;
  final String title;
  final String description;
  final String startDate;
  final String endDate;
  final int itemCount;
  final double totalIn;
  final double totalOut;
  final DateTime? closedAt;
  final bool isLocked;

  const MonthClosing({
    required this.id,
    this.uuid,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    this.itemCount = 0,
    this.totalIn = 0,
    this.totalOut = 0,
    this.closedAt,
    this.isLocked = true,
  });

  double get net => totalIn - totalOut;

  factory MonthClosing.fromMap(Map<String, dynamic> map) {
    return MonthClosing(
      id: _asInt(map['id']) ?? 0,
      uuid: map['uuid']?.toString(),
      title: map['title']?.toString() ?? 'Month closing',
      description: map['description']?.toString() ?? '',
      startDate: map['start_date']?.toString() ?? '',
      endDate: map['end_date']?.toString() ?? '',
      itemCount: _asInt(map['item_count']) ?? 0,
      totalIn: _asDouble(map['total_in']),
      totalOut: _asDouble(map['total_out']),
      closedAt: DateTime.tryParse(
        map['closed_at']?.toString() ??
            map['creation_date']?.toString() ??
            '',
      ),
      isLocked: (_asInt(map['is_locked']) ?? 1) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'title': title,
      'description': description,
      'start_date': startDate,
      'end_date': endDate,
      'item_count': itemCount,
      'total_in': totalIn,
      'total_out': totalOut,
      'closed_at': closedAt?.toIso8601String(),
      'is_locked': isLocked ? 1 : 0,
    };
  }

  @override
  String toString() => title;

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
