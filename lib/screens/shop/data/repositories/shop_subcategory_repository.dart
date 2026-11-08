import '../../../../services/db/drift_database.dart';
import '../models/shop_sub_category.dart';

class ShopSubCategoryRepository {
  final Database db;

  ShopSubCategoryRepository(this.db);

  Future<int> insert(ShopSubCategory sub) async {
    return db.insert(
      'shop_subcategories',
      sub.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> update(ShopSubCategory sub) async {
    return db.update(
      'shop_subcategories',
      sub.toMap(),
      where: 'id = ?',
      whereArgs: [sub.id],
    );
  }

  Future<int> delete(int id) async {
    return db.delete(
      'shop_subcategories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<ShopSubCategory>> getAll() async {
    final result = await db.query(
      'shop_subcategories',
      orderBy: 'created_at DESC',
    );
    return result.map((e) => ShopSubCategory.fromMap(e)).toList();
  }

  Future<List<ShopSubCategory>> getByCategory(int categoryId) async {
    final result = await db.query(
      'shop_subcategories',
      where: 'category_id = ?',
      whereArgs: [categoryId],
    );
    return result.map((e) => ShopSubCategory.fromMap(e)).toList();
  }

  Future<ShopSubCategory?> getOne(int id) async {
    final result = await db.query(
      'shop_subcategories',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return ShopSubCategory.fromMap(result.first);
  }
}
