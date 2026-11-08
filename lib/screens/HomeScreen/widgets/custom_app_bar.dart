import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../models/HomeFeatureModel.dart';
import '../../../utlis/constant.dart';

PreferredSizeWidget buildCustomAppBar(
  BuildContext context,
  HomeFeatureModel? settingsFeature,
) {
  final scheme = Theme.of(context).colorScheme;

  return AppBar(
    title: Text(
      kAppName,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w800,
          ),
    ),
    actions: [
      if (settingsFeature != null)
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton.filledTonal(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push(settingsFeature.route),
          ),
        ),
    ],
  );
}
