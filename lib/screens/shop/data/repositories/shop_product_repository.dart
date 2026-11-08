import '../../../../services/db/drift_database.dart';
import '../models/shop_product.dart';

class ShopProductRepository {
  final Database db;

  ShopProductRepository(this.db);

  Future<int> insert(ShopProduct product) async {
    return db.insert(
      'shop_products',
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> update(ShopProduct product) async {
    return db.update(
      'shop_products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> delete(int id) async {
    return db.delete(
      'shop_products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<ShopProduct>> getAll() async {
    final result = await db.query(
      'shop_products',
      orderBy: 'created_at DESC',
    );
    return result.map((e) => ShopProduct.fromMap(e)).toList();
  }

  Future<List<ShopProduct>> getLowStock() async {
    final result = await db.rawQuery('''
      SELECT * FROM shop_products
      WHERE low_alert_limit IS NOT NULL
      AND available_quantity <= low_alert_limit
    ''');

    return result.map((e) => ShopProduct.fromMap(e)).toList();
  }

  Future<List<ShopProduct>> getByCategory(int categoryId) async {
    final result = await db.query(
      'shop_products',
      where: 'category_id = ?',
      whereArgs: [categoryId],
    );
    return result.map((e) => ShopProduct.fromMap(e)).toList();
  }

  Future<ShopProduct?> getOne(int id) async {
    final result = await db.query(
      'shop_products',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return ShopProduct.fromMap(result.first);
  }
}
