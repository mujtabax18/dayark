import 'drift_database.dart';

class DbAlterHelpers {
  static Future<void> addMissingColumns(
    Database db,
    String tableName,
    Map<String, String> columns,
  ) async {
    final existingColumns = await getTableColumns(db, tableName);
    for (final entry in columns.entries) {
      if (!existingColumns.contains(entry.key)) {
        await db.execute(
          'ALTER TABLE $tableName ADD COLUMN ${entry.key} ${entry.value}',
        );
      }
    }
  }

  static Future<List<String>> getTableColumns(
      Database db, String tableName) async {
    final result = await db.rawQuery('PRAGMA table_info($tableName)');
    return result.map((row) => row['name'] as String).toList();
  }
}
