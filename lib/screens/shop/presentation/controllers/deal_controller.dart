import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/models/shop_deal.dart';
import '../../data/models/shop_deal_product.dart';
import '../../data/provider/shop_providers.dart';
import '../../data/repositories/shop_deal_repository.dart';

/// -------------------------------------------
/// Controller Provider
/// -------------------------------------------

final shopDealControllerProvider =
    StateNotifierProvider<ShopDealController, AsyncValue<List<ShopDeal>>>(
        (ref) {
  return ShopDealController(ref);
});

/// -------------------------------------------
/// Controller
/// -------------------------------------------

class ShopDealController extends StateNotifier<AsyncValue<List<ShopDeal>>> {
  final Ref ref;

  ShopDealController(this.ref) : super(const AsyncLoading()) {
    load();
  }

  Future<ShopDealRepository> _getRepo() async {
    return await ref.watch(shopDealRepositoryProvider.future);
  }

  /// Load Deals
  Future<void> load() async {
    try {
      state = const AsyncLoading();
      final repo = await _getRepo();
      final data = await repo.getAllDeals();
      state = AsyncData(data);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Create Deal with Products
  Future<void> createDeal(
    ShopDeal deal,
    List<ShopDealProduct> products,
  ) async {
    try {
      final repo = await _getRepo();

      final dealId = await repo.insertDeal(deal);

      final items = products.map((e) => e.copyWith(dealId: dealId)).toList();

      await repo.insertDealProducts(items);

      await load();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Delete Deal
  Future<void> delete(int id) async {
    try {
      final repo = await _getRepo();
      await repo.deleteDeal(id);
      await load();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
