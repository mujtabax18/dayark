import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/models/shop_details.dart';
import '../../data/provider/shop_providers.dart';
import '../../data/repositories/shop_details_repository.dart';

/// -------------------------------------------
/// Controller Provider
/// -------------------------------------------

final shopDetailsControllerProvider =
    StateNotifierProvider<ShopDetailsController, AsyncValue<ShopDetails?>>(
        (ref) {
  return ShopDetailsController(ref);
});

/// -------------------------------------------
/// Controller
/// -------------------------------------------

class ShopDetailsController extends StateNotifier<AsyncValue<ShopDetails?>> {
  final Ref ref;

  ShopDetailsController(this.ref) : super(const AsyncLoading()) {
    load();
  }

  Future<ShopDetailsRepository> _getRepo() async {
    return await ref.watch(shopDetailsRepositoryProvider.future);
  }

  /// Load Details
  Future<void> load() async {
    try {
      state = const AsyncLoading();
      final repo = await _getRepo();
      final data = await repo.get();
      state = AsyncData(data);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Save / Update Details
  Future<void> save({
    required String name,
    String? description,
    String? logoPath,
    String? imagePath,
    String? address,
  }) async {
    try {
      final repo = await _getRepo();
      final now = DateTime.now();

      final existing = await repo.get();

      final details = ShopDetails(
        id: 1,
        name: name,
        description: description,
        logoPath: logoPath,
        imagePath: imagePath,
        address: address,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );

      await repo.save(details);
      state = AsyncData(details);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Clear Details
  Future<void> clear() async {
    try {
      final repo = await _getRepo();
      await repo.delete();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
