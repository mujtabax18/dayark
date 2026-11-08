import 'package:flutter/material.dart';

import '../../../core/widgets/common/app_action_tile.dart';
import '../../../core/widgets/common/app_surface.dart';

Widget buildActionCard({
  required IconData icon,
  required String title,
  required String description,
  required Color color,
  required VoidCallback onTap,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: AppSurface(
      child: AppActionTile(
        icon: icon,
        title: title,
        subtitle: description,
        accent: color,
        onTap: onTap,
      ),
    ),
  );
}
