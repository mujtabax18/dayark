import '../../../../services/db/drift_database.dart';
import '../models/shop_category.dart';

class ShopCategoryRepository {
  final Database db;

  ShopCategoryRepository(this.db);

  Future<int> insert(ShopCategory category) async {
    return db.insert(
      'shop_categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> update(ShopCategory category) async {
    return db.update(
      'shop_categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> delete(int id) async {
    return db.delete(
      'shop_categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<ShopCategory>> getAll() async {
    final result =
        await db.query('shop_categories', orderBy: 'created_at DESC');
    return result.map((e) => ShopCategory.fromMap(e)).toList();
  }

  Future<ShopCategory?> getOne(int id) async {
    final result = await db.query(
      'shop_categories',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return ShopCategory.fromMap(result.first);
  }
}
