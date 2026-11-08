import '../../models/habit.dart';
import '../../models/habit_progress.dart';
import '../database_service.dart';

class HabitTrackerService {
  final DatabaseService _databaseService;

  HabitTrackerService(this._databaseService);

  Future<int> createHabit(Habit habit) async {
    final db = await _databaseService.database;
    return db.insert('habits', habit.toMap());
  }

  Future<List<Habit>> getAllHabits() async {
    final db = await _databaseService.database;
    final rows = await db.query('habits', orderBy: 'is_active DESC, created_at DESC');
    final result = <Habit>[];
    for (final row in rows) {
      final id = (row['id'] as num).toInt();
      final progress = await getProgressForHabit(id);
      result.add(Habit.fromMap(row, progressList: progress));
    }
    return result;
  }

  Future<Habit?> getHabitById(int id) async {
    final db = await _databaseService.database;
    final rows = await db.query('habits', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Habit.fromMap(rows.first, progressList: await getProgressForHabit(id));
  }

  Future<int> updateHabit(Habit habit) async {
    final db = await _databaseService.database;
    return db.update('habits', habit.toMap(), where: 'id = ?', whereArgs: [habit.id]);
  }

  Future<int> updateHabitDetails({
    required int habitId,
    required String title,
    String? description,
    String? notificationTime,
    required String category,
    required String reason,
    required String cue,
    required String reward,
    required String difficulty,
    required int deadlineHour,
    required int deadlineMinute,
    required List<int> repeatDays,
    required int iconCode,
  }) async {
    final db = await _databaseService.database;
    return db.update(
      'habits',
      {
        'title': title.trim(),
        'description': description?.trim().isEmpty == true
            ? null
            : description?.trim(),
        'notification_time': notificationTime,
        'category': category,
        'reason': reason.trim(),
        'cue': cue.trim(),
        'reward': reward.trim(),
        'difficulty': difficulty,
        'deadline_hour': deadlineHour,
        'deadline_minute': deadlineMinute,
        'repeat_days': (repeatDays.toList()..sort()).join(','),
        'icon_code': iconCode,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [habitId],
    );
  }

  Future<int> deleteHabit(int id) async {
    final db = await _databaseService.database;
    return db.transaction((txn) async {
      await txn.delete('habit_progress', where: 'habit_id = ?', whereArgs: [id]);
      return txn.delete('habits', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> recordProgress(HabitProgress progress) async {
    final db = await _databaseService.database;
    return db.transaction((txn) async {
      await txn.delete(
        'habit_progress',
        where: 'habit_id = ? AND date = ?',
        whereArgs: [progress.habitId, _dateKey(progress.date)],
      );
      return txn.insert('habit_progress', progress.toMap());
    });
  }

  Future<int> removeProgress(int habitId, DateTime date) async {
    final db = await _databaseService.database;
    return db.delete(
      'habit_progress',
      where: 'habit_id = ? AND date = ?',
      whereArgs: [habitId, _dateKey(date)],
    );
  }

  Future<List<HabitProgress>> getProgressForHabit(int habitId) async {
    final db = await _databaseService.database;
    final rows = await db.query(
      'habit_progress',
      where: 'habit_id = ?',
      whereArgs: [habitId],
      orderBy: 'date DESC',
    );
    return rows.map(HabitProgress.fromMap).toList();
  }

  Future<HabitProgress?> getProgressForDate(int habitId, String date) async {
    final db = await _databaseService.database;
    final rows = await db.query(
      'habit_progress',
      where: 'habit_id = ? AND date = ?',
      whereArgs: [habitId, date],
      limit: 1,
    );
    return rows.isEmpty ? null : HabitProgress.fromMap(rows.first);
  }

  Future<void> clearAllHabitData() async {
    final db = await _databaseService.database;
    await db.transaction((txn) async {
      await txn.delete('habit_progress');
      await txn.delete('habits');
    });
  }

  static String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
