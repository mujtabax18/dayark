import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/database_service.dart';
import '../../data/models/ScanGroupPreview.dart';
import '../../data/repo/scan_group_service.dart';
import '../../services/scan_storage_service.dart';

class ScanGroupQuery {
  const ScanGroupQuery({
    this.search = '',
    this.favoritesOnly = false,
    this.sort = 'updated',
  });

  final String search;
  final bool favoritesOnly;
  final String sort;

  @override
  bool operator ==(Object other) {
    return other is ScanGroupQuery &&
        other.search == search &&
        other.favoritesOnly == favoritesOnly &&
        other.sort == sort;
  }

  @override
  int get hashCode => Object.hash(search, favoritesOnly, sort);
}

final scanStorageServiceProvider = Provider<ScanStorageService>((ref) {
  return ScanStorageService();
});

final scanGroupServiceProvider = Provider<ScanGroupService>((ref) {
  final db = ref.watch(databaseServiceProvider);
  final storage = ref.watch(scanStorageServiceProvider);
  return ScanGroupService(db, storageService: storage);
});

final scanGroupPreviewProvider =
    FutureProvider<List<ScanGroupPreview>>((ref) async {
  final service = ref.watch(scanGroupServiceProvider);
  return service.fetchGroupPreviews();
});

final filteredScanGroupPreviewProvider = FutureProvider.family<
    List<ScanGroupPreview>, ScanGroupQuery>((ref, query) async {
  final service = ref.watch(scanGroupServiceProvider);
  return service.fetchGroupPreviews(
    search: query.search,
    favoritesOnly: query.favoritesOnly,
    sort: query.sort,
  );
});
