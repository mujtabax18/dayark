import 'package:flutter/material.dart';

import '../../../core/theme/theme_x.dart';

Widget buildAmountIndicator(
  BuildContext context,
  IconData icon,
  num amount,
  Color color,
) {
  final neutral = context.themeColors.neutral;

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 4),
        Text(
          amount.toStringAsFixed(2),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
