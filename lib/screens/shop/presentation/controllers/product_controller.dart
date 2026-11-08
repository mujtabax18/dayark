import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/models/shop_product.dart';
import '../../data/provider/shop_providers.dart';
import '../../data/repositories/shop_product_repository.dart';

/// -------------------------------------------
/// Controller Provider
/// -------------------------------------------

final shopProductControllerProvider =
    StateNotifierProvider<ShopProductController, AsyncValue<List<ShopProduct>>>(
        (ref) {
  return ShopProductController(ref);
});

/// -------------------------------------------
/// Controller
/// -------------------------------------------

class ShopProductController
    extends StateNotifier<AsyncValue<List<ShopProduct>>> {
  final Ref ref;

  ShopProductController(this.ref) : super(const AsyncLoading()) {
    load();
  }

  Future<ShopProductRepository> _getRepo() async {
    return await ref.watch(shopProductRepositoryProvider.future);
  }

  /// Load All Products
  Future<void> load() async {
    try {
      state = const AsyncLoading();
      final repo = await _getRepo();
      final data = await repo.getAll();
      state = AsyncData(data);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Add Product
  Future<void> add(ShopProduct product) async {
    try {
      final repo = await _getRepo();
      await repo.insert(product);
      await load();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Update Product
  Future<void> updateProduct(ShopProduct product) async {
    try {
      final repo = await _getRepo();
      await repo.update(product);
      await load();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Delete Product
  Future<void> delete(int id) async {
    try {
      final repo = await _getRepo();
      await repo.delete(id);
      await load();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Load Low Stock Products
  Future<void> loadLowStock() async {
    try {
      state = const AsyncLoading();
      final repo = await _getRepo();
      final data = await repo.getLowStock();
      state = AsyncData(data);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
