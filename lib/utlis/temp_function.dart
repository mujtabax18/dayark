import '../services/db/drift_database.dart';
import 'package:uuid/uuid.dart';

Future<void> backfillExpenseSchema(Database db) async {
  final uuidGen = const Uuid();
  final now = DateTime.now().toIso8601String();

  // EXPENSE ITEMS
  final items = await db.query(
    'expense_items',
    where: 'uuid IS NULL',
  );

  for (final row in items) {
    final id = row['id'] as int;
    final date = row['date'] as String?;

    await db.update(
      'expense_items',
      {
        'uuid': uuidGen.v4(),
        'creation_date': date ?? now,
        'updatation_date': date ?? now,
        'deleted_at': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // EXPENSE TITLES
  final titles = await db.query(
    'expense_titles',
    where: 'uuid IS NULL',
  );

  for (final row in titles) {
    final id = row['id'] as int;
    final creation = row['creation_date'] as String?;

    await db.update(
      'expense_titles',
      {
        'uuid': uuidGen.v4(),
        'deleted_at': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // MONTH CLOSING
  final closings = await db.query(
    'month_closing',
    where: 'uuid IS NULL',
  );

  for (final row in closings) {
    final id = row['id'] as int;

    await db.update(
      'month_closing',
      {
        'uuid': uuidGen.v4(),
        'creation_date': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
