import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/db/drift_database.dart';

import '../../../services/database_service.dart';
import '../../../services/localDatabaseServices/DBInspectorService.dart';

final databaseProvider = FutureProvider<Database>((ref) async {
  return ref.watch(databaseServiceProvider).database;
});

final dbInspectorServiceProvider = FutureProvider<DBInspectorService>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return DBInspectorService(db);
});

final tableListProvider = FutureProvider<List<String>>((ref) async {
  final service = await ref.watch(dbInspectorServiceProvider.future);
  return service.getAllTables();
});

final tableColumnsProvider = FutureProvider<List<DBColumnInfo>>((ref) async {
  final service = await ref.watch(dbInspectorServiceProvider.future);
  final table = ref.watch(selectedTableProvider);
  if (table == null) return const [];
  return service.getColumns(table);
});

final tableDataProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = await ref.watch(dbInspectorServiceProvider.future);
  final table = ref.watch(selectedTableProvider);
  final query = ref.watch(dbInspectorQueryProvider);
  if (table == null) return const [];

  return service.getTableData(
    table,
    searchText: query.searchText,
    filterColumn: query.filterColumn,
    filterOperator: query.filterOperator,
    filterValue: query.filterValue,
    sortColumn: query.sortColumn,
    sortAscending: query.sortAscending,
    limit: query.limit,
  );
});

final tableRowCountProvider = FutureProvider<int>((ref) async {
  final service = await ref.watch(dbInspectorServiceProvider.future);
  final table = ref.watch(selectedTableProvider);
  final query = ref.watch(dbInspectorQueryProvider);
  if (table == null) return 0;

  return service.countTableRows(
    table,
    searchText: query.searchText,
    filterColumn: query.filterColumn,
    filterOperator: query.filterOperator,
    filterValue: query.filterValue,
  );
});

// Kept for compatibility with older DB inspector widgets.
final tablePrimaryKeyProvider = FutureProvider<String>((ref) async {
  final service = await ref.watch(dbInspectorServiceProvider.future);
  final table = ref.watch(selectedTableProvider);
  if (table == null) return 'id';
  return service.getPrimaryKey(table);
});

class SelectedTableNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setSelectedTable(String? newTableName) {
    if (state == newTableName) return;
    state = newTableName;
    ref.read(dbInspectorQueryProvider.notifier).reset();
    ref.read(selectedRowIdsProvider.notifier).clear();
  }
}

final selectedTableProvider =
    NotifierProvider<SelectedTableNotifier, String?>(SelectedTableNotifier.new);

class DBInspectorQueryState {
  static const Object _unset = Object();

  final String searchText;
  final String? filterColumn;
  final String filterOperator;
  final String filterValue;
  final String? sortColumn;
  final bool sortAscending;
  final int limit;

  const DBInspectorQueryState({
    this.searchText = '',
    this.filterColumn,
    this.filterOperator = 'contains',
    this.filterValue = '',
    this.sortColumn,
    this.sortAscending = true,
    this.limit = 100,
  });

  bool get filterNeedsValue => !const {
        'isNull',
        'isNotNull',
        'isEmpty',
        'isNotEmpty',
      }.contains(filterOperator);

  bool get hasActiveFilter =>
      filterColumn != null && (!filterNeedsValue || filterValue.isNotEmpty);

  DBInspectorQueryState copyWith({
    String? searchText,
    Object? filterColumn = _unset,
    String? filterOperator,
    String? filterValue,
    Object? sortColumn = _unset,
    bool? sortAscending,
    int? limit,
  }) {
    return DBInspectorQueryState(
      searchText: searchText ?? this.searchText,
      filterColumn: identical(filterColumn, _unset)
          ? this.filterColumn
          : filterColumn as String?,
      filterOperator: filterOperator ?? this.filterOperator,
      filterValue: filterValue ?? this.filterValue,
      sortColumn: identical(sortColumn, _unset)
          ? this.sortColumn
          : sortColumn as String?,
      sortAscending: sortAscending ?? this.sortAscending,
      limit: limit ?? this.limit,
    );
  }
}

class DBInspectorQueryNotifier extends Notifier<DBInspectorQueryState> {
  @override
  DBInspectorQueryState build() => const DBInspectorQueryState();

  void setSearchText(String value) {
    state = state.copyWith(searchText: value);
    ref.read(selectedRowIdsProvider.notifier).clear();
  }

  void setFilterColumn(String? value) {
    state = state.copyWith(filterColumn: value, filterValue: '');
    ref.read(selectedRowIdsProvider.notifier).clear();
  }

  void setFilterOperator(String value) {
    state = state.copyWith(filterOperator: value);
    ref.read(selectedRowIdsProvider.notifier).clear();
  }

  void setFilterValue(String value) {
    state = state.copyWith(filterValue: value);
    ref.read(selectedRowIdsProvider.notifier).clear();
  }

  void setSortColumn(String? value) {
    state = state.copyWith(sortColumn: value);
    ref.read(selectedRowIdsProvider.notifier).clear();
  }

  void toggleSortDirection() {
    state = state.copyWith(sortAscending: !state.sortAscending);
    ref.read(selectedRowIdsProvider.notifier).clear();
  }

  void setLimit(int value) {
    state = state.copyWith(limit: value);
    ref.read(selectedRowIdsProvider.notifier).clear();
  }

  void clearFilter() {
    state = state.copyWith(
      filterColumn: null,
      filterOperator: 'contains',
      filterValue: '',
    );
    ref.read(selectedRowIdsProvider.notifier).clear();
  }

  void reset() {
    state = const DBInspectorQueryState();
  }
}

final dbInspectorQueryProvider =
    NotifierProvider<DBInspectorQueryNotifier, DBInspectorQueryState>(
  DBInspectorQueryNotifier.new,
);

class SelectedRowIdsNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => <int>{};

  void toggle(int rowId, bool selected) {
    final updated = Set<int>.from(state);
    selected ? updated.add(rowId) : updated.remove(rowId);
    state = updated;
  }

  void selectAll(Iterable<int> rowIds) {
    state = {...rowIds};
  }

  void clear() {
    if (state.isNotEmpty) state = <int>{};
  }
}

final selectedRowIdsProvider =
    NotifierProvider<SelectedRowIdsNotifier, Set<int>>(
  SelectedRowIdsNotifier.new,
);
