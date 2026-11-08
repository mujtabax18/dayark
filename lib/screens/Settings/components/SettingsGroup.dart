import 'package:flutter/material.dart';

import '../../../core/widgets/common/app_surface.dart';

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
