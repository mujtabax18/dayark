import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../theme/theme_x.dart';

class AppActionTile extends StatelessWidget {
  const AppActionTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.accent,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.contentPadding,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? accent;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? context.colorScheme.primary;

    return ListTile(
      enabled: enabled,
      onTap: enabled ? onTap : null,
      contentPadding: contentPadding,
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withOpacity(context.isDarkMode ? .18 : .11),
          borderRadius: AppRadius.small,
        ),
        child: Icon(icon, color: color, size: 21),
      ),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailing ??
          Icon(
            Icons.chevron_right_rounded,
            color: context.themeColors.neutral.textDisabled,
          ),
    );
  }
}
