import '../../../../services/db/drift_database.dart';
import '../models/shop_details.dart';

class ShopDetailsRepository {
  final Database db;

  ShopDetailsRepository(this.db);

  /// Insert or Replace (Singleton pattern)
  Future<void> save(ShopDetails details) async {
    await db.insert(
      'shop_details',
      details.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ShopDetails?> get() async {
    final result = await db.query(
      'shop_details',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return ShopDetails.fromMap(result.first);
  }

  Future<void> delete() async {
    await db.delete(
      'shop_details',
      where: 'id = ?',
      whereArgs: [1],
    );
  }
}
