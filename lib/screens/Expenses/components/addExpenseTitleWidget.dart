import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_x.dart';
import 'expense_category_form_sheet.dart';

class AddExpenseTitleWidget extends ConsumerWidget {
  const AddExpenseTitleWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neutral = context.themeColors.neutral;
    return SafeArea(
      top: false,
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: () => showExpenseCategoryFormSheet(context, ref),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.expense,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Add category',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
