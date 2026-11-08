import '../../../../services/db/drift_database.dart';
import '../models/shop_deal.dart';
import '../models/shop_deal_product.dart';
import '../models/shop_product.dart';

class ShopDealRepository {
  final Database db;

  ShopDealRepository(this.db);

  Future<int> insertDeal(ShopDeal deal) async {
    return db.insert(
      'shop_deals',
      deal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateDeal(ShopDeal deal) async {
    return db.update(
      'shop_deals',
      deal.toMap(),
      where: 'id = ?',
      whereArgs: [deal.id],
    );
  }

  Future<int> deleteDeal(int id) async {
    return db.delete(
      'shop_deals',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> insertDealProducts(List<ShopDealProduct> items) async {
    final batch = db.batch();
    for (final item in items) {
      batch.insert('shop_deal_products', item.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteDealProducts(int dealId) async {
    await db.delete(
      'shop_deal_products',
      where: 'deal_id = ?',
      whereArgs: [dealId],
    );
  }

  Future<List<ShopDeal>> getAllDeals() async {
    final result = await db.query('shop_deals', orderBy: 'created_at DESC');
    return result.map((e) => ShopDeal.fromMap(e)).toList();
  }

  Future<ShopDeal?> getDeal(int id) async {
    final result = await db.query(
      'shop_deals',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return ShopDeal.fromMap(result.first);
  }

  /// Fetch deal with its products
  Future<List<Map<String, dynamic>>> getDealWithProducts(int dealId) async {
    return db.rawQuery('''
      SELECT 
        dp.id as deal_product_id,
        dp.quantity,
        p.*
      FROM shop_deal_products dp
      JOIN shop_products p ON p.id = dp.product_id
      WHERE dp.deal_id = ?
    ''', [dealId]);
  }
}
