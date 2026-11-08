import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/localDatabaseServices/DBInspectorService.dart';
import '../controller/DBInspectorServiceController.dart';
import '../widgets/database_edit_dialogs.dart';
import '../widgets/table_dropdown.dart';
import '../widgets/table_row_card.dart';
import '../../navigation/widgets/desktop_content_frame.dart';

class DBInspectorScreen extends ConsumerStatefulWidget {
  const DBInspectorScreen({super.key});

  @override
  ConsumerState<DBInspectorScreen> createState() => _DBInspectorScreenState();
}

class _DBInspectorScreenState extends ConsumerState<DBInspectorScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _filterValueController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _filterValueController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      ref.read(dbInspectorQueryProvider.notifier).setSearchText(value);
    });
  }

  void _refresh() {
    ref.invalidate(tableDataProvider);
    ref.invalidate(tableRowCountProvider);
    ref.invalidate(tableColumnsProvider);
    ref.read(selectedRowIdsProvider.notifier).clear();
  }

  Future<void> _insertRow(
    String tableName,
    List<DBColumnInfo> columns,
  ) async {
    final values = await showInsertRowDialog(
      context,
      tableName: tableName,
      columns: columns,
    );
    if (values == null || !mounted) return;

    try {
      final service = await ref.read(dbInspectorServiceProvider.future);
      await service.insertRow(tableName: tableName, values: values);
      _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Row inserted.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Insert failed: $error')),
      );
    }
  }

  Future<void> _bulkEdit(
    String tableName,
    List<DBColumnInfo> columns,
    Set<int> selectedIds,
  ) async {
    final draft = await showBulkEditDialog(
      context,
      columns: columns,
      selectedCount: selectedIds.length,
    );
    if (draft == null || !mounted) return;

    try {
      final service = await ref.read(dbInspectorServiceProvider.future);
      final count = await service.updateRowsByRowIds(
        tableName: tableName,
        rowIds: selectedIds,
        values: draft.values,
      );
      ref.read(selectedRowIdsProvider.notifier).clear();
      _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count rows updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bulk update failed: $error')),
      );
    }
  }

  Future<void> _bulkDelete(
    String tableName,
    Set<int> selectedIds,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete selected rows?'),
        content: Text(
          '${selectedIds.length} rows will be permanently deleted from '
          '"$tableName".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete rows'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final service = await ref.read(dbInspectorServiceProvider.future);
      final count = await service.deleteRowsByRowIds(
        tableName: tableName,
        rowIds: selectedIds,
      );
      ref.read(selectedRowIdsProvider.notifier).clear();
      _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count rows deleted.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bulk delete failed: $error')),
      );
    }
  }

  Future<void> _dropTable(String tableName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Drop table?'),
        content: Text(
          'The "$tableName" table and all of its rows will be permanently '
          'deleted. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Drop table'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      final service = await ref.read(dbInspectorServiceProvider.future);
      await service.dropTable(tableName);
      ref.read(selectedTableProvider.notifier).setSelectedTable(null);
      ref.invalidate(tableListProvider);
      ref.invalidate(tableDataProvider);
      ref.invalidate(tableColumnsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Table "$tableName" dropped.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to drop table: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(selectedTableProvider, (previous, next) {
      _searchDebounce?.cancel();
      _searchController.clear();
      _filterValueController.clear();
    });

    final selectedTable = ref.watch(selectedTableProvider);
    final query = ref.watch(dbInspectorQueryProvider);
    final columnsAsync = ref.watch(tableColumnsProvider);
    final rowsAsync = ref.watch(tableDataProvider);
    final countAsync = ref.watch(tableRowCountProvider);
    final selectedIds = ref.watch(selectedRowIdsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DB Inspector'),
        actions: [
          if (selectedTable != null)
            IconButton(
              tooltip: 'Refresh data',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
          if (selectedTable != null)
            columnsAsync.maybeWhen(
              data: (columns) => IconButton(
                tooltip: 'Insert row',
                onPressed: () => _insertRow(selectedTable, columns),
                icon: const Icon(Icons.add_box_outlined),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          if (selectedTable != null)
            IconButton(
              tooltip: 'Drop table',
              onPressed: () => _dropTable(selectedTable),
              icon: const Icon(Icons.delete_forever_outlined),
            ),
        ],
      ),
      body: DesktopContentFrame(
        child: SafeArea(
        child: Column(
          children: [
            _buildQueryPanel(
              selectedTable: selectedTable,
              query: query,
              columnsAsync: columnsAsync,
            ),
            const Divider(height: 1),
            if (selectedTable == null)
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Select a database table to search, filter, sort, edit, '
                      'insert, or delete its rows.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: columnsAsync.when(
                  data: (columns) => rowsAsync.when(
                    data: (rows) => _buildRows(
                      tableName: selectedTable,
                      columns: columns,
                      rows: rows,
                      countAsync: countAsync,
                      selectedIds: selectedIds,
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => _ErrorState(
                      message: 'Unable to load rows: $error',
                      onRetry: _refresh,
                    ),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => _ErrorState(
                    message: 'Unable to read table columns: $error',
                    onRetry: _refresh,
                  ),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildQueryPanel({
    required String? selectedTable,
    required DBInspectorQueryState query,
    required AsyncValue<List<DBColumnInfo>> columnsAsync,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: selectedTable == null ? 90 : 360,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              const TableDropdown(),
              if (selectedTable != null) ...[
                const SizedBox(height: 12),
                TextField(
                controller: _searchController,
                onChanged: (value) {
                  _onSearchChanged(value);
                  setState(() {});
                },
                decoration: InputDecoration(
                  labelText: 'Search all columns',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            ref
                                .read(dbInspectorQueryProvider.notifier)
                                .setSearchText('');
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear),
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              columnsAsync.when(
                data: (columns) => _buildFilterAndSortControls(query, columns),
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text('Column controls unavailable: $error'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterAndSortControls(
    DBInspectorQueryState query,
    List<DBColumnInfo> columns,
  ) {
    const operators = <String, String>{
      'contains': 'Contains',
      'equals': 'Equals',
      'notEquals': 'Not equal',
      'startsWith': 'Starts with',
      'endsWith': 'Ends with',
      'greaterThan': 'Greater than',
      'lessThan': 'Less than',
      'isNull': 'Is NULL',
      'isNotNull': 'Is not NULL',
      'isEmpty': 'Is empty',
      'isNotEmpty': 'Is not empty',
    };

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 210,
          child: DropdownButtonFormField<String>(
            value: query.filterColumn ?? '',
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Filter column',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('No filter'),
              ),
              ...columns.map(
                (column) => DropdownMenuItem<String>(
                  value: column.name,
                  child: Text(column.name, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (value) {
              _filterValueController.clear();
              ref
                  .read(dbInspectorQueryProvider.notifier)
                  .setFilterColumn(
                    value == null || value.isEmpty ? null : value,
                  );
            },
          ),
        ),
        SizedBox(
          width: 165,
          child: DropdownButtonFormField<String>(
            value: query.filterOperator,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Condition',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: operators.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: query.filterColumn == null
                ? null
                : (value) {
                    if (value == null) return;
                    ref
                        .read(dbInspectorQueryProvider.notifier)
                        .setFilterOperator(value);
                  },
          ),
        ),
        SizedBox(
          width: 210,
          child: TextField(
            controller: _filterValueController,
            enabled: query.filterColumn != null && query.filterNeedsValue,
            onChanged: ref
                .read(dbInspectorQueryProvider.notifier)
                .setFilterValue,
            decoration: const InputDecoration(
              labelText: 'Filter value',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          width: 210,
          child: DropdownButtonFormField<String>(
            value: query.sortColumn ?? '',
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Sort by',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('SQLite row order'),
              ),
              ...columns.map(
                (column) => DropdownMenuItem<String>(
                  value: column.name,
                  child: Text(column.name, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (value) => ref
                .read(dbInspectorQueryProvider.notifier)
                .setSortColumn(
                  value == null || value.isEmpty ? null : value,
                ),
          ),
        ),
        IconButton.filledTonal(
          tooltip: query.sortAscending ? 'Ascending' : 'Descending',
          onPressed: ref
              .read(dbInspectorQueryProvider.notifier)
              .toggleSortDirection,
          icon: Icon(
            query.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
          ),
        ),
        SizedBox(
          width: 120,
          child: DropdownButtonFormField<int>(
            value: query.limit,
            decoration: const InputDecoration(
              labelText: 'Row limit',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [50, 100, 250, 500, 1000]
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text('$value'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              ref.read(dbInspectorQueryProvider.notifier).setLimit(value);
            },
          ),
        ),
        TextButton.icon(
          onPressed: () {
            _searchController.clear();
            _filterValueController.clear();
            ref.read(dbInspectorQueryProvider.notifier).reset();
            ref.read(selectedRowIdsProvider.notifier).clear();
            setState(() {});
          },
          icon: const Icon(Icons.filter_alt_off_outlined),
          label: const Text('Reset'),
        ),
      ],
    );
  }

  Widget _buildRows({
    required String tableName,
    required List<DBColumnInfo> columns,
    required List<Map<String, dynamic>> rows,
    required AsyncValue<int> countAsync,
    required Set<int> selectedIds,
  }) {
    final visibleIds = rows
        .map((row) => (row[dbInspectorRowIdKey] as num?)?.toInt())
        .whereType<int>()
        .toSet();
    final allVisibleSelected =
        visibleIds.isNotEmpty && visibleIds.every(selectedIds.contains);
    final someVisibleSelected = visibleIds.any(selectedIds.contains);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              Row(
                children: [
                  Checkbox(
                    tristate: true,
                    value: allVisibleSelected
                        ? true
                        : someVisibleSelected
                            ? null
                            : false,
                    onChanged: (value) {
                      if (value == true) {
                        ref
                            .read(selectedRowIdsProvider.notifier)
                            .selectAll(visibleIds);
                      } else {
                        ref.read(selectedRowIdsProvider.notifier).clear();
                      }
                    },
                  ),
                  Expanded(
                    child: countAsync.when(
                      data: (count) => Text(
                        '${rows.length} shown • $count matching rows',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      loading: () => Text('${rows.length} rows shown'),
                      error: (_, __) => Text('${rows.length} rows shown'),
                    ),
                  ),
                  if (selectedIds.isNotEmpty)
                    Text('${selectedIds.length} selected'),
                ],
              ),
              if (selectedIds.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: ref
                            .read(selectedRowIdsProvider.notifier)
                            .clear,
                        child: const Text('Clear selection'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _bulkEdit(tableName, columns, selectedIds),
                        icon: const Icon(Icons.edit_note),
                        label: const Text('Bulk edit'),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.error,
                        ),
                        onPressed: () =>
                            _bulkDelete(tableName, selectedIds),
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: const Text('Delete'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: rows.isEmpty
              ? const Center(
                  child: Text('No rows match the current search and filters.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 6, bottom: 24),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final rowId =
                        (row[dbInspectorRowIdKey] as num?)?.toInt() ?? -1;
                    return TableRowCard(
                      key: ValueKey('$tableName-$rowId'),
                      row: row,
                      tableName: tableName,
                      columns: columns,
                      selected: selectedIds.contains(rowId),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
