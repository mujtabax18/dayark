import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/MediaCollection.dart';
import '../models/MediaEditHistory.dart';
import '../models/MediaFile.dart';

import '../services/database_service.dart';
import '../services/localDatabaseServices/MediaService.dart';
import '../services/media/MediaStorageService.dart';

final mediaStorageServiceProvider = Provider<MediaStorageService>((ref) {
  return MediaStorageService();
});

final mediaServiceProvider = Provider<MediaService>((ref) {
  return MediaService(
    ref.read(databaseServiceProvider),
    storageService: ref.read(mediaStorageServiceProvider),
  );
});

class MediaQuery {
  const MediaQuery({
    this.type = 'all',
    this.search = '',
    this.favoritesOnly = false,
    this.includeDeleted = false,
    this.collectionId,
  });

  final String type;
  final String search;
  final bool favoritesOnly;
  final bool includeDeleted;
  final int? collectionId;

  @override
  bool operator ==(Object other) {
    return other is MediaQuery &&
        other.type == type &&
        other.search == search &&
        other.favoritesOnly == favoritesOnly &&
        other.includeDeleted == includeDeleted &&
        other.collectionId == collectionId;
  }

  @override
  int get hashCode =>
      Object.hash(type, search, favoritesOnly, includeDeleted, collectionId);
}

/// Backward-compatible provider used by existing screens that expect the
/// original no-argument media list API.
final mediaListProvider = FutureProvider.autoDispose<List<MediaFile>>((ref) {
  return ref.read(mediaServiceProvider).getAllMedia();
});

/// Advanced query provider used by the upgraded media studio.
final filteredMediaListProvider = FutureProvider.autoDispose
    .family<List<MediaFile>, MediaQuery>((ref, query) async {
  return ref.read(mediaServiceProvider).getAllMedia(
        includeDeleted: query.includeDeleted,
        mediaType: query.type,
        search: query.search,
        favoritesOnly: query.favoritesOnly,
        collectionId: query.collectionId,
      );
});

final mediaStatsProvider = FutureProvider.autoDispose<MediaLibraryStats>((ref) {
  return ref.read(mediaServiceProvider).getStats();
});

final mediaCollectionsProvider =
    FutureProvider.autoDispose<List<MediaCollection>>((ref) {
  return ref.read(mediaServiceProvider).getCollections();
});

/// Small collection previews used by the gallery-style collections home.
/// Only the first four items are needed for an album cover mosaic.
final mediaCollectionPreviewProvider =
    FutureProvider.autoDispose.family<List<MediaFile>, int>((ref, collectionId) {
  return ref.read(mediaServiceProvider).getCollectionPreview(collectionId);
});

final mediaLibraryPreviewProvider =
    FutureProvider.autoDispose<List<MediaFile>>((ref) {
  return ref.read(mediaServiceProvider).getLibraryPreview();
});

final mediaCollectionIdsProvider =
    FutureProvider.autoDispose.family<Set<int>, int>((ref, mediaId) {
  return ref.read(mediaServiceProvider).getCollectionIdsForMedia(mediaId);
});

final mediaHistoryProvider = FutureProvider.autoDispose
    .family<List<MediaEditHistory>, int>((ref, mediaId) {
  return ref.read(mediaServiceProvider).getHistory(mediaId);
});

void refreshMediaLibrary(WidgetRef ref) {
  ref.invalidate(mediaListProvider);
  ref.invalidate(filteredMediaListProvider);
  ref.invalidate(mediaStatsProvider);
  ref.invalidate(mediaCollectionsProvider);
  ref.invalidate(mediaCollectionPreviewProvider);
  ref.invalidate(mediaLibraryPreviewProvider);
  ref.invalidate(mediaCollectionIdsProvider);
}
