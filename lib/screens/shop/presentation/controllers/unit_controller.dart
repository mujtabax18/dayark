import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/models/shop_unit.dart';
import '../../data/provider/shop_providers.dart';
import '../../data/repositories/shop_unit_repository.dart';

/// -------------------------------------------
/// Controller Provider
/// -------------------------------------------

final shopUnitControllerProvider =
    StateNotifierProvider<ShopUnitController, AsyncValue<List<ShopUnit>>>(
        (ref) {
  return ShopUnitController(ref);
});

/// -------------------------------------------
/// Controller
/// -------------------------------------------

class ShopUnitController extends StateNotifier<AsyncValue<List<ShopUnit>>> {
  final Ref ref;

  ShopUnitController(this.ref) : super(const AsyncLoading()) {
    load();
  }

  Future<ShopUnitRepository> _getRepo() async {
    return await ref.watch(shopUnitRepositoryProvider.future);
  }

  /// Load All Units
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

  /// Add Unit
  Future<void> add(ShopUnit unit) async {
    try {
      final repo = await _getRepo();
      await repo.insert(unit);
      await load();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Update Unit
  Future<void> updateUnit(ShopUnit unit) async {
    try {
      final repo = await _getRepo();
      await repo.update(unit);
      await load();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Delete Unit
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
