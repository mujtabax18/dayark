import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controller/monthclosingController.dart';

class MonthClosingDropdown extends ConsumerWidget {
  final void Function(String?)? onChanged;  // Changed to String? to handle special values
  final String? initialValue;  // Changed to String?
  final String? hintText;

  const MonthClosingDropdown({
    super.key,
    this.onChanged,
    this.initialValue,
    this.hintText = 'Select Month Closing',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final closingsAsync = ref.watch(monthClosingControllerProvider);

    return closingsAsync.when(
      loading: () => const CircularProgressIndicator.adaptive(),
      error: (error, stack) => Text('Error: ${error.toString()}'),
      data: (closings) {
        return DropdownButtonFormField<String>(  // Changed to String type
          value: initialValue,
          decoration: InputDecoration(
            labelText: hintText,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          items: [
            // Default hint
            DropdownMenuItem<String>(
              value: null,
              child: Text(
                hintText!,
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
            ),
            // Special hardcoded options
            const DropdownMenuItem<String>(
              value: 'latest',
              child: Text('Latest'),
            ),
            const DropdownMenuItem<String>(
              value: 'all',
              child: Text('All'),
            ),
            // Actual closing items
            ...closings.map((closing) {
              return DropdownMenuItem<String>(
                value: closing.id.toString(),  // Convert ID to string
                child: Text(closing.title),
              );
            }),
          ],
          onChanged: onChanged,
          isExpanded: true,
        );
      },
    );
  }
}