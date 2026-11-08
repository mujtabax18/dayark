import '../../../../services/db/drift_database.dart';
import '../models/shop_unit.dart';

class ShopUnitRepository {
  final Database db;

  ShopUnitRepository(this.db);

  Future<int> insert(ShopUnit unit) async {
    return db.insert(
      'shop_units',
      unit.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> update(ShopUnit unit) async {
    return db.update(
      'shop_units',
      unit.toMap(),
      where: 'id = ?',
      whereArgs: [unit.id],
    );
  }

  Future<int> delete(int id) async {
    return db.delete(
      'shop_units',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<ShopUnit>> getAll() async {
    final result = await db.query(
      'shop_units',
      orderBy: 'name ASC',
    );
    return result.map((e) => ShopUnit.fromMap(e)).toList();
  }

  Future<ShopUnit?> getOne(int id) async {
    final result = await db.query(
      'shop_units',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return ShopUnit.fromMap(result.first);
  }
}
