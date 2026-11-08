import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/db/drift_database.dart';

import '../../../../services/database_service.dart';
import '../repositories/shop_category_repository.dart';
import '../repositories/shop_deal_repository.dart';
import '../repositories/shop_details_repository.dart';
import '../repositories/shop_product_repository.dart';
import '../repositories/shop_subcategory_repository.dart';
import '../repositories/shop_unit_repository.dart';

/// -------------------------------------------
/// Database Provider (Future<Database>)
/// -------------------------------------------

final databaseProvider = FutureProvider<Database>((ref) async {
  final service = ref.watch(databaseServiceProvider);
  return service.database;
});

/// -------------------------------------------
/// Repositories (Future Providers)
/// -------------------------------------------

final shopCategoryRepositoryProvider =
    FutureProvider<ShopCategoryRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return ShopCategoryRepository(db);
});

final shopSubCategoryRepositoryProvider =
    FutureProvider<ShopSubCategoryRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return ShopSubCategoryRepository(db);
});

final shopUnitRepositoryProvider =
    FutureProvider<ShopUnitRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return ShopUnitRepository(db);
});

final shopProductRepositoryProvider =
    FutureProvider<ShopProductRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return ShopProductRepository(db);
});

final shopDealRepositoryProvider =
    FutureProvider<ShopDealRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return ShopDealRepository(db);
});
final shopDetailsRepositoryProvider =
    FutureProvider<ShopDetailsRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return ShopDetailsRepository(db);
});
