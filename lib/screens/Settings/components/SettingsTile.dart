import 'package:flutter/material.dart';

import '../../../core/widgets/common/app_action_tile.dart';

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.color,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppActionTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      accent: color,
      trailing: trailing,
      onTap: onTap,
    );
  }
}
