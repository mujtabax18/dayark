import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_tokens.dart';
import '../../../core/theme/theme_x.dart';
import '../../../core/widgets/common/app_surface.dart';
import '../../../models/FilterModel.dart';
import 'filterController.dart';

class FilterWidget extends ConsumerWidget {
  const FilterWidget({super.key, required this.tableName});

  final String tableName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(filterProvider(tableName));

    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_list_rounded,
                color: context.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('Filter by date', style: context.textTheme.titleSmall),
            ],
          ),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _DateSelector(
                label: 'Start',
                value: filter?.startDate,
                icon: Icons.calendar_today_outlined,
                onSelected: (date) => ref
                    .read(filterProvider(tableName).notifier)
                    .updateFilter(tableName, date, filter?.endDate),
              ),
              _DateSelector(
                label: 'End',
                value: filter?.endDate,
                icon: Icons.event_available_rounded,
                onSelected: (date) {
                  final start = filter?.startDate;
                  final end = start != null && start.compareTo(date) > 0
                      ? ''
                      : date;
                  ref
                      .read(filterProvider(tableName).notifier)
                      .updateFilter(tableName, start, end);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateSelector extends StatelessWidget {
  const _DateSelector({
    required this.label,
    required this.value,
    required this.icon,
    required this.onSelected,
  });

  final String label;
  final String? value;
  final IconData icon;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          onSelected(DateFormat('yyyy-MM-dd').format(picked));
        }
      },
      icon: Icon(icon, size: 18),
      label: Text(
        value != null && value!.isNotEmpty ? '$label: $value' : label,
      ),
    );
  }
}
