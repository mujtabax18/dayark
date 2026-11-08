import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/models/shop_sub_category.dart';
import '../../data/provider/shop_providers.dart';
import '../../data/repositories/shop_subcategory_repository.dart';

/// -------------------------------------------
/// Controller Provider
/// -------------------------------------------

final shopSubCategoryControllerProvider = StateNotifierProvider<
    ShopSubCategoryController, AsyncValue<List<ShopSubCategory>>>((ref) {
  return ShopSubCategoryController(ref);
});

/// -------------------------------------------
/// Controller
/// -------------------------------------------

class ShopSubCategoryController
    extends StateNotifier<AsyncValue<List<ShopSubCategory>>> {
  final Ref ref;

  ShopSubCategoryController(this.ref) : super(const AsyncLoading()) {
    load();
  }

  Future<ShopSubCategoryRepository> _getRepo() async {
    return await ref.watch(shopSubCategoryRepositoryProvider.future);
  }

  /// Load All Subcategories
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

  /// Load Subcategories By Category
  Future<void> loadByCategory(int categoryId) async {
    try {
      state = const AsyncLoading();
      final repo = await _getRepo();
      final data = await repo.getByCategory(categoryId);
      state = AsyncData(data);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Add Subcategory
  Future<void> add(ShopSubCategory sub) async {
    try {
      final repo = await _getRepo();
      await repo.insert(sub);
      await load();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Update Subcategory
  Future<void> updateSubCategory(ShopSubCategory sub) async {
    try {
      final repo = await _getRepo();
      await repo.update(sub);
      await load();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Delete Subcategory
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
