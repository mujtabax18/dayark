import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_x.dart';
import '../../../models/ExpenseItem.dart';
import '../../../utlis/constant.dart';

void showItemDetails(BuildContext context, ExpenseItem item) {
  final neutral = context.themeColors.neutral;
  final bool isIncome = item.inOrOut == ConstantTableString.itemIn;

  final Color typeColor = isIncome ? AppColors.success : AppColors.danger;

  final IconData typeIcon = isIncome
      ? Icons.arrow_circle_up_rounded
      : Icons.arrow_circle_down_rounded;

  showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: neutral.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// ───── HEADER ─────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Item Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: neutral.textPrimary,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: neutral.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _detailRow(
              context,
              icon: Icons.label_important_outline,
              label: 'Name',
              value: item.name,
              iconColor: AppColors.expense,
            ),

            _divider(context),

            _detailRow(
              context,
              icon: Icons.calendar_today,
              label: 'Date',
              value: DateFormat('dd MMM yyyy').format(item.date),
              iconColor: AppColors.expense,
            ),

            _divider(context),

            /// ───── AMOUNT + TYPE ─────
            Row(
              children: [
                Expanded(
                  child: _detailRow(
                    context,
                    icon: Icons.attach_money,
                    label: 'Amount',
                    value: '${item.price}',
                    iconColor: typeColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(typeIcon, size: 20, color: typeColor),
                          const SizedBox(width: 8),
                          Text(
                            'Type',
                            style: TextStyle(
                              fontSize: 13,
                              color: neutral.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isIncome ? 'Income' : 'Expense',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: typeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            /// ───── NOTES ─────
            if (item.notes != null && item.notes!.isNotEmpty) ...[
              _divider(context),
              _detailRow(
                context,
                icon: Icons.notes,
                label: 'Notes',
                value: item.notes!,
                iconColor: neutral.textSecondary,
                multiLine: true,
              ),
            ],

            const SizedBox(height: 20),

            /// ───── FOOTER DECOR ─────
            Center(
              child: Container(
                height: 4,
                width: 80,
                decoration: BoxDecoration(
                  color: neutral.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// ─────────────────────────────────────────────

Widget _detailRow(
  BuildContext context, {
  required IconData icon,
  required String label,
  required String value,
  required Color iconColor,
  bool multiLine = false,
}) {
  final neutral = context.themeColors.neutral;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: neutral.textSecondary,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: neutral.textPrimary,
        ),
        maxLines: multiLine ? null : 1,
        overflow: multiLine ? TextOverflow.visible : TextOverflow.ellipsis,
      ),
    ],
  );
}

Widget _divider(BuildContext context) {
  final neutral = context.themeColors.neutral;

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Divider(
      height: 1,
      thickness: 0.8,
      color: neutral.divider,
    ),
  );
}
