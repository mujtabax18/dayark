import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/models/shop_category.dart';
import '../../data/provider/shop_providers.dart';
import '../../data/repositories/shop_category_repository.dart';

/// -------------------------------------------
/// Controller Provider
/// -------------------------------------------

final shopCategoryControllerProvider = StateNotifierProvider<
    ShopCategoryController, AsyncValue<List<ShopCategory>>>((ref) {
  return ShopCategoryController(ref);
});

/// -------------------------------------------
/// Controller
/// -------------------------------------------

class ShopCategoryController
    extends StateNotifier<AsyncValue<List<ShopCategory>>> {
  final Ref ref;

  ShopCategoryController(this.ref) : super(const AsyncLoading()) {
    load();
  }

  Future<ShopCategoryRepository> _getRepo() async {
    return await ref.watch(shopCategoryRepositoryProvider.future);
  }

  /// Load Categories
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

  /// Add Category
  Future<void> add(ShopCategory category) async {
    try {
      final repo = await _getRepo();
      await repo.insert(category);
      await load();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Update Category
  Future<void> updateCategory(ShopCategory category) async {
    try {
      final repo = await _getRepo();
      await repo.update(category);
      await load();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Delete Category
  Future<void> delete(int id) async {
    try {
      final repo = await _getRepo();
      await repo.delete(id);
      await load();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
