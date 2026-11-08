import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../models/quotation.dart';
import '../../../services/database_service.dart';
import '../services/quotation_online_service.dart';
import '../services/quotation_service.dart';

class QuotationState {
  const QuotationState({
    required this.quotations,
    required this.categories,
    this.search = '',
    this.category = 'All',
    this.favoritesOnly = false,
    this.onlineOnly = false,
    this.sort = QuotationSort.newest,
    this.isLoading = false,
    this.error,
  });

  final List<Quotation> quotations;
  final List<String> categories;
  final String search;
  final String category;
  final bool favoritesOnly;
  final bool onlineOnly;
  final QuotationSort sort;
  final bool isLoading;
  final String? error;

  factory QuotationState.initial() => const QuotationState(
        quotations: [],
        categories: [],
      );

  QuotationState copyWith({
    List<Quotation>? quotations,
    List<String>? categories,
    String? search,
    String? category,
    bool? favoritesOnly,
    bool? onlineOnly,
    QuotationSort? sort,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return QuotationState(
      quotations: quotations ?? this.quotations,
      categories: categories ?? this.categories,
      search: search ?? this.search,
      category: category ?? this.category,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      onlineOnly: onlineOnly ?? this.onlineOnly,
      sort: sort ?? this.sort,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class QuotationController extends StateNotifier<QuotationState> {
  QuotationController(this._service) : super(QuotationState.initial()) {
    refresh();
  }

  final QuotationService _service;

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await Future.wait<dynamic>([
        _service.getAll(
          search: state.search,
          category: state.category,
          favoritesOnly: state.favoritesOnly,
          onlineOnly: state.onlineOnly,
          sort: state.sort,
        ),
        _service.getCategories(),
      ]);
      state = state.copyWith(
        quotations: results[0] as List<Quotation>,
        categories: results[1] as List<String>,
        isLoading: false,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> setSearch(String value) async {
    state = state.copyWith(search: value);
    await _reloadList();
  }

  Future<void> setCategory(String value) async {
    state = state.copyWith(category: value);
    await _reloadList();
  }

  Future<void> setFavoritesOnly(bool value) async {
    state = state.copyWith(favoritesOnly: value);
    await _reloadList();
  }

  Future<void> setOnlineOnly(bool value) async {
    state = state.copyWith(onlineOnly: value);
    await _reloadList();
  }

  Future<void> setSort(QuotationSort value) async {
    state = state.copyWith(sort: value);
    await _reloadList();
  }

  Future<int?> save(Quotation quotation) async {
    try {
      final id = await _service.save(quotation);
      await refresh();
      return id;
    } catch (error) {
      state = state.copyWith(error: error.toString());
      return null;
    }
  }

  Future<void> saveMany(List<Quotation> quotations) async {
    if (quotations.isEmpty) return;
    try {
      await _service.saveMany(quotations);
      await refresh();
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }

  Future<QuotationImportResult> importMany(List<Quotation> quotations) async {
    if (quotations.isEmpty) return const QuotationImportResult();
    try {
      final result = await _service.importMany(quotations);
      await refresh();
      return result;
    } catch (error) {
      state = state.copyWith(error: error.toString());
      rethrow;
    }
  }

  Future<QuotationImportResult> importOnlineCategory({
    required OnlineQuotationCategory category,
    required String catalogVersion,
    required List<Map<String, dynamic>> quotations,
  }) async {
    try {
      final result = await _service.importOnlineCategory(
        categoryId: category.id,
        categoryName: category.name,
        catalogVersion: catalogVersion,
        quotations: quotations,
      );
      await refresh();
      return result;
    } catch (error) {
      state = state.copyWith(error: error.toString());
      rethrow;
    }
  }

  Future<void> delete(Quotation quotation) async {
    if (quotation.id == null) return;
    try {
      await _service.delete(quotation.id!);
      await refresh();
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }

  Future<void> toggleFavorite(Quotation quotation) async {
    try {
      await _service.toggleFavorite(quotation);
      await _reloadList();
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }

  Future<void> registerUse(Quotation quotation) async {
    try {
      await _service.registerUse(quotation);
      await _reloadList();
    } catch (_) {
      // Copying and sharing should still work if analytics cannot be updated.
    }
  }

  Future<Quotation?> randomQuote() {
    return _service.getRandom(
      category: state.category,
      onlineOnly: state.onlineOnly,
    );
  }

  Future<void> _reloadList() async {
    try {
      final quotations = await _service.getAll(
        search: state.search,
        category: state.category,
        favoritesOnly: state.favoritesOnly,
        onlineOnly: state.onlineOnly,
        sort: state.sort,
      );
      state = state.copyWith(quotations: quotations, clearError: true);
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }
}

final quotationServiceProvider = Provider<QuotationService>((ref) {
  return QuotationService(ref.read(databaseServiceProvider));
});

final quotationOnlineServiceProvider = Provider<QuotationOnlineService>((ref) {
  return const QuotationOnlineService();
});

final quotationControllerProvider =
    StateNotifierProvider<QuotationController, QuotationState>((ref) {
  return QuotationController(ref.read(quotationServiceProvider));
});

final quotationCountProvider = FutureProvider<int>((ref) async {
  final quotations = await ref.watch(quotationServiceProvider).getAll();
  return quotations.length;
});
