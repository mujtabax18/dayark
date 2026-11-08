import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controller/DBInspectorServiceController.dart';

class TableDropdown extends ConsumerWidget {
  const TableDropdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tableListAsync = ref.watch(tableListProvider);
    final selectedTable = ref.watch(selectedTableProvider);

    return tableListAsync.when(
      data: (tables) => DropdownButtonFormField<String>(
        value: selectedTable,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Database table',
          prefixIcon: Icon(Icons.table_chart_outlined),
          border: OutlineInputBorder(),
        ),
        hint: const Text('Select a table'),
        onChanged: ref
            .read(selectedTableProvider.notifier)
            .setSelectedTable,
        items: tables
            .map(
              (table) => DropdownMenuItem(
                value: table,
                child: Text(table, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
      ),
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Text('Unable to load tables: $error'),
    );
  }
}
