class Filter {
  final int? id;
  final String tableName;
  final String? startDate;
  final String? endDate;

  Filter(
      {this.id,
      required this.tableName,
      required this.startDate,
      required this.endDate});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'table_name': tableName,
      'start_date': startDate,
      'end_date': endDate,
    };
  }

  factory Filter.fromMap(Map<String, dynamic> map) {
    return Filter(
      id: map['id'],
      tableName: map['table_name'],
      startDate: map['start_date'],
      endDate: map['end_date'],
    );
  }
}
