import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/theme/theme_x.dart';
import 'SettingsDivider.dart';
import 'SettingsGroup.dart';

class AppInfoWidget extends StatefulWidget {
  const AppInfoWidget({super.key});

  @override
  State<AppInfoWidget> createState() => _AppInfoWidgetState();
}

class _AppInfoWidgetState extends State<AppInfoWidget> {
  PackageInfo _info = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
  );

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((value) {
      if (mounted) setState(() => _info = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;

    return SettingsGroup(
      children: [
        _row('Version', '${_info.version} (${_info.buildNumber})', neutral),
        const SettingsDivider(),
        _row('Package', _info.packageName, neutral),
      ],
    );
  }

  Widget _row(String label, String value, neutral) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: neutral.textPrimary, fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(color: neutral.textSecondary)),
        ],
      ),
    );
  }
}
