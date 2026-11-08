enum HabitProgressStatus { completed, skipped }

class HabitProgress {
  final int? id;
  final int habitId;
  final DateTime date;
  final bool isCompleted;
  final String? notes;
  final double value;
  final String mood;
  final String status;
  final DateTime? updatedAt;

  const HabitProgress({
    this.id,
    required this.habitId,
    required this.date,
    required this.isCompleted,
    this.notes,
    this.value = 1,
    this.mood = 'neutral',
    String? status,
    this.updatedAt,
  }) : status = status ?? (isCompleted ? 'completed' : 'skipped');

  bool get isSkipped => status == 'skipped';

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'habit_id': habitId,
        'date': _dateKey(date),
        'is_completed': isCompleted ? 1 : 0,
        'notes': notes,
        'value': value,
        'mood': mood,
        'status': status,
        'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
      };

  factory HabitProgress.fromMap(Map<String, dynamic> map) => HabitProgress(
        id: map['id'] as int?,
        habitId: (map['habit_id'] as num).toInt(),
        date: DateTime.parse(map['date'].toString()),
        isCompleted: (map['is_completed'] as num? ?? 0).toInt() == 1,
        notes: map['notes']?.toString(),
        value: (map['value'] as num? ?? 1).toDouble(),
        mood: map['mood']?.toString() ?? 'neutral',
        status: map['status']?.toString(),
        updatedAt: map['updated_at'] == null
            ? null
            : DateTime.tryParse(map['updated_at'].toString()),
      );

  static String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
