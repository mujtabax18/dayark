import '../db/drift_database.dart';

import 'package:metersystem/models/moodTrackerModel.dart';
import 'package:metersystem/services/database_service.dart';

class MoodtrackerSerive {
  MoodtrackerSerive(this.databaseService);

  final DatabaseService databaseService;

  Future<List<MoodEntry>> fetchMoodHistory() async {
    final db = await databaseService.database;
    final rows = await db.query(
      'mood_entries',
      orderBy: 'dateTime DESC, id DESC',
    );
    return rows.map(MoodEntry.fromMap).toList(growable: false);
  }

  Future<MoodEntry> insertOrUpdateMood(MoodEntry entry) async {
    final db = await databaseService.database;
    final now = DateTime.now().toIso8601String();

    if (entry.id == null) {
      final data = entry.copyWith(
        createdAt: entry.createdAt ?? now,
        updatedAt: now,
      ).toMap()
        ..remove('id');

      final id = await db.insert(
        'mood_entries',
        data,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      return entry.copyWith(
        id: id,
        createdAt: data['createdAt']?.toString(),
        updatedAt: now,
      );
    }

    final updated = entry.copyWith(updatedAt: now);
    final data = updated.toMap()..remove('id');
    await db.update(
      'mood_entries',
      data,
      where: 'id = ?',
      whereArgs: [entry.id],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return updated;
  }

  Future<void> deleteMood(int id) async {
    final db = await databaseService.database;
    await db.delete('mood_entries', where: 'id = ?', whereArgs: [id]);
  }
}
