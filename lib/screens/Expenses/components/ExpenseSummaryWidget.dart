import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_x.dart';
import '../../../controller/commonController.dart';
import '../../../utlis/helper_functions.dart';
import '../../../utlis/widgets/EyeIconButton.dart';

class ExpenseSummaryWidget extends ConsumerWidget {
  const ExpenseSummaryWidget({super.key, required this.data});

  final List<Map<String, dynamic>> data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVisible = ref.watch(sensitiveValueVisibilityProvider);
    final neutral = context.themeColors.neutral;
    final totalIn = sumTotalInOut(data, 'total_in');
    final totalOut = sumTotalInOut(data, 'total_out');
    final isDesktop = MediaQuery.sizeOf(context).width >= 1100;

    if (isDesktop) {
      final activeCategories = data
          .where((row) => ((row['hidden'] as num?)?.toInt() ?? 0) == 0)
          .length;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            children: [
              Expanded(
                child: _desktopCard(
                  context,
                  label: 'Total income',
                  value: totalIn,
                  icon: Icons.south_west_rounded,
                  color: AppColors.success,
                  visible: isVisible,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _desktopCard(
                  context,
                  label: 'Total expense',
                  value: totalOut,
                  icon: Icons.north_east_rounded,
                  color: AppColors.danger,
                  visible: isVisible,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _desktopCard(
                  context,
                  label: 'Net balance',
                  value: totalIn - totalOut,
                  icon: Icons.account_balance_wallet_outlined,
                  color: AppColors.expense,
                  visible: isVisible,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _desktopCard(
                  context,
                  label: 'Active categories',
                  valueText: activeCategories.toString(),
                  icon: Icons.category_outlined,
                  color: AppColors.warning,
                  visible: true,
                ),
              ),
            ],
          ),
          const Positioned(top: -10, right: -8, child: EyeIconButton()),
        ],
      );
    }

    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
          decoration: BoxDecoration(
            color: AppColors.expense.withOpacity(0.1),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
                child: _card(
                  context,
                  'Income',
                  totalIn,
                  Icons.arrow_upward_rounded,
                  AppColors.success,
                  isVisible,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _card(
                  context,
                  'Expense',
                  totalOut,
                  Icons.arrow_downward_rounded,
                  AppColors.danger,
                  isVisible,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _card(
                  context,
                  'Balance',
                  totalIn - totalOut,
                  Icons.account_balance_wallet_outlined,
                  AppColors.expense,
                  isVisible,
                ),
              ),
            ],
          ),
        ),
        const Positioned(top: -5, right: -5, child: EyeIconButton()),
      ],
    );
  }

  Widget _desktopCard(
    BuildContext context, {
    required String label,
    num? value,
    String? valueText,
    required IconData icon,
    required Color color,
    required bool visible,
  }) {
    final neutral = context.themeColors.neutral;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: neutral.divider.withOpacity(0.75)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: neutral.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  valueText ??
                      (visible ? (value ?? 0).toStringAsFixed(2) : '•••••'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: neutral.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(
    BuildContext context,
    String label,
    num value,
    IconData icon,
    Color color,
    bool visible,
  ) {
    final neutral = context.themeColors.neutral;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: neutral.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              visible ? value.toStringAsFixed(2) : '•••••',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
