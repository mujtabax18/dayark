import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/localDatabaseServices/DBInspectorService.dart';
import '../controller/DBInspectorServiceController.dart';
import 'confirm_delete_dialog.dart';

class TableRowCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> row;
  final String tableName;
  final List<DBColumnInfo> columns;
  final bool selected;

  const TableRowCard({
    super.key,
    required this.row,
    required this.tableName,
    required this.columns,
    required this.selected,
  });

  @override
  ConsumerState<TableRowCard> createState() => _TableRowCardState();
}

class _TableRowCardState extends ConsumerState<TableRowCard> {
  final Map<String, TextEditingController> _controllers = {};
  final Set<String> _nullColumns = <String>{};
  bool _saving = false;

  int get _rowId =>
      (widget.row[dbInspectorRowIdKey] as num?)?.toInt() ?? -1;

  @override
  void initState() {
    super.initState();
    _resetEditors();
  }

  @override
  void didUpdateWidget(covariant TableRowCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.row, widget.row)) {
      _disposeEditors();
      _resetEditors();
    }
  }

  void _resetEditors() {
    for (final column in widget.columns) {
      if (!widget.row.containsKey(column.name)) continue;
      final value = widget.row[column.name];
      if (value == null) _nullColumns.add(column.name);
      _controllers[column.name] = TextEditingController(
        text: _displayValue(value),
      );
    }
  }

  String _displayValue(Object? value) {
    if (value == null) return '';
    if (value is Uint8List) return '<BLOB: ${value.length} bytes>';
    return value.toString();
  }

  void _disposeEditors() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _nullColumns.clear();
  }

  @override
  void dispose() {
    _disposeEditors();
    super.dispose();
  }

  Map<String, dynamic> _buildChanges() {
    final changes = <String, dynamic>{};
    for (final column in widget.columns) {
      if (column.isPrimaryKey || column.isBlob) continue;
      final controller = _controllers[column.name];
      if (controller == null) continue;

      final original = widget.row[column.name];
      final isNull = _nullColumns.contains(column.name);
      if (isNull) {
        if (original != null) changes[column.name] = null;
        continue;
      }

      final value = controller.text;
      if (original == null || value != original.toString()) {
        changes[column.name] = value;
      }
    }
    return changes;
  }

  Future<void> _save() async {
    final changes = _buildChanges();
    if (changes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes to save.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final service = await ref.read(dbInspectorServiceProvider.future);
      await service.updateRowByRowId(
        tableName: widget.tableName,
        rowId: _rowId,
        values: changes,
      );
      ref.invalidate(tableDataProvider);
      ref.invalidate(tableRowCountProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Row updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showConfirmDeleteDialog(context);
    if (confirm != true || !mounted) return;

    try {
      final service = await ref.read(dbInspectorServiceProvider.future);
      await service.deleteRowByRowId(
        tableName: widget.tableName,
        rowId: _rowId,
      );
      ref.read(selectedRowIdsProvider.notifier).toggle(_rowId, false);
      ref.invalidate(tableDataProvider);
      ref.invalidate(tableRowCountProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Row deleted.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $error')),
      );
    }
  }

  Future<void> _copyAsJson() async {
    final safeRow = <String, dynamic>{};
    for (final entry in widget.row.entries) {
      if (entry.key == dbInspectorRowIdKey) continue;
      safeRow[entry.key] = entry.value is Uint8List
          ? '<BLOB: ${(entry.value as Uint8List).length} bytes>'
          : entry.value;
    }
    const encoder = JsonEncoder.withIndent('  ');
    await Clipboard.setData(ClipboardData(text: encoder.convert(safeRow)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Row copied as JSON.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleColumns = widget.columns
        .where((column) => widget.row.containsKey(column.name))
        .toList();
    final primaryValues = visibleColumns
        .where((column) => column.isPrimaryKey)
        .map((column) => '${column.name}: ${widget.row[column.name]}')
        .join(' • ');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: widget.selected,
                  onChanged: (value) => ref
                      .read(selectedRowIdsProvider.notifier)
                      .toggle(_rowId, value ?? false),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        primaryValues.isEmpty
                            ? 'SQLite rowid: $_rowId'
                            : primaryValues,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${visibleColumns.length} columns • rowid $_rowId',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Copy row as JSON',
                  onPressed: _copyAsJson,
                  icon: const Icon(Icons.copy_all_outlined),
                ),
                IconButton(
                  tooltip: 'Delete row',
                  onPressed: _delete,
                  color: theme.colorScheme.error,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const Divider(),
            ...visibleColumns.map((column) {
              final isNull = _nullColumns.contains(column.name);
              final canSetNull = !column.notNull && !column.isPrimaryKey;
              final readOnly = column.isPrimaryKey || column.isBlob;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12, right: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              column.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              column.type.isEmpty ? 'TEXT' : column.type,
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controllers[column.name],
                        enabled: !readOnly && !isNull,
                        minLines: 1,
                        maxLines: 3,
                        keyboardType: column.isInteger || column.isReal
                            ? const TextInputType.numberWithOptions(decimal: true)
                            : TextInputType.text,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: isNull ? 'NULL' : null,
                          border: const OutlineInputBorder(),
                          suffixIcon: canSetNull
                              ? IconButton(
                                  tooltip: isNull
                                      ? 'Use a value'
                                      : 'Set value to NULL',
                                  icon: Icon(
                                    isNull
                                        ? Icons.data_object
                                        : Icons.remove_circle_outline,
                                  ),
                                  onPressed: () => setState(() {
                                    if (isNull) {
                                      _nullColumns.remove(column.name);
                                    } else {
                                      _nullColumns.add(column.name);
                                    }
                                  }),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Save row'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
