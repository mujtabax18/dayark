import 'package:flutter/material.dart';

import '../../../services/localDatabaseServices/DBInspectorService.dart';

class BulkEditDraft {
  final Map<String, dynamic> values;

  const BulkEditDraft({required this.values});
}

Future<BulkEditDraft?> showBulkEditDialog(
  BuildContext context, {
  required List<DBColumnInfo> columns,
  required int selectedCount,
}) async {
  final editableColumns = columns
      .where((column) => !column.isPrimaryKey && !column.isBlob)
      .toList();
  if (editableColumns.isEmpty) return null;

  final controllers = {
    for (final column in editableColumns) column.name: TextEditingController(),
  };
  final selectedColumns = <String>{};
  final nullColumns = <String>{};

  final result = await showDialog<BulkEditDraft>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Edit $selectedCount selected rows'),
            content: SizedBox(
              width: 620,
              height: 520,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select one or more columns. Every selected row will '
                    'receive the same values.',
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: editableColumns.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final column = editableColumns[index];
                        final selected = selectedColumns.contains(column.name);
                        final setNull = nullColumns.contains(column.name);
                        final nullAllowed = !column.notNull;

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: selected,
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    selectedColumns.add(column.name);
                                  } else {
                                    selectedColumns.remove(column.name);
                                    nullColumns.remove(column.name);
                                  }
                                });
                              },
                            ),
                            Expanded(
                              child: TextField(
                                controller: controllers[column.name],
                                enabled: selected && !setNull,
                                keyboardType: column.isInteger || column.isReal
                                    ? const TextInputType.numberWithOptions(
                                        decimal: true,
                                      )
                                    : TextInputType.text,
                                decoration: InputDecoration(
                                  labelText: '${column.name} (${column.type})',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                  suffixIcon: nullAllowed && selected
                                      ? IconButton(
                                          tooltip: setNull
                                              ? 'Use a value'
                                              : 'Set to NULL',
                                          onPressed: () {
                                            setState(() {
                                              if (setNull) {
                                                nullColumns.remove(column.name);
                                              } else {
                                                nullColumns.add(column.name);
                                              }
                                            });
                                          },
                                          icon: Icon(
                                            setNull
                                                ? Icons.data_object
                                                : Icons.remove_circle_outline,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (selectedColumns.isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Select at least one column.'),
                      ),
                    );
                    return;
                  }

                  final values = <String, dynamic>{};
                  for (final column in editableColumns) {
                    if (!selectedColumns.contains(column.name)) continue;

                    if (nullColumns.contains(column.name)) {
                      values[column.name] = null;
                      continue;
                    }

                    final value = controllers[column.name]!.text;
                    if (value.isEmpty &&
                        (column.isInteger || column.isReal)) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${column.name} requires a numeric value.',
                          ),
                        ),
                      );
                      return;
                    }
                    values[column.name] = value;
                  }

                  Navigator.pop(
                    dialogContext,
                    BulkEditDraft(values: values),
                  );
                },
                child: const Text('Update rows'),
              ),
            ],
          );
        },
      );
    },
  );

  for (final controller in controllers.values) {
    controller.dispose();
  }
  return result;
}

Future<Map<String, dynamic>?> showInsertRowDialog(
  BuildContext context, {
  required String tableName,
  required List<DBColumnInfo> columns,
}) async {
  final editableColumns = columns.where((column) {
    final autoIntegerPrimaryKey = column.isPrimaryKey && column.isInteger;
    return !autoIntegerPrimaryKey && !column.isBlob;
  }).toList();

  final controllers = {
    for (final column in editableColumns) column.name: TextEditingController(),
  };
  final includeColumns = <String>{
    for (final column in editableColumns)
      if (column.notNull && column.defaultValue == null) column.name,
  };

  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Add row to $tableName'),
            content: SizedBox(
              width: 560,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 520),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: editableColumns.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final column = editableColumns[index];
                    final required =
                        column.notNull && column.defaultValue == null;
                    final included = includeColumns.contains(column.name);

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: included,
                          onChanged: required
                              ? null
                              : (value) {
                                  setState(() {
                                    if (value == true) {
                                      includeColumns.add(column.name);
                                    } else {
                                      includeColumns.remove(column.name);
                                    }
                                  });
                                },
                        ),
                        Expanded(
                          child: TextField(
                            controller: controllers[column.name],
                            enabled: included,
                            keyboardType: column.isInteger || column.isReal
                                ? const TextInputType.numberWithOptions(
                                    decimal: true,
                                  )
                                : TextInputType.text,
                            decoration: InputDecoration(
                              labelText:
                                  '${column.name}${required ? ' *' : ''}',
                              helperText: column.defaultValue == null
                                  ? column.type
                                  : '${column.type} • default: '
                                      '${column.defaultValue}',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Insert'),
                onPressed: () {
                  final values = <String, dynamic>{};
                  for (final column in editableColumns) {
                    if (!includeColumns.contains(column.name)) continue;

                    final value = controllers[column.name]!.text;
                    if (column.notNull && value.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text('${column.name} cannot be empty.'),
                        ),
                      );
                      return;
                    }
                    values[column.name] = value;
                  }
                  Navigator.pop(dialogContext, values);
                },
              ),
            ],
          );
        },
      );
    },
  );

  for (final controller in controllers.values) {
    controller.dispose();
  }
  return result;
}
