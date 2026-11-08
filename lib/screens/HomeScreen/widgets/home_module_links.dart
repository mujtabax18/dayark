import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../navigation/widgets/desktop_navigation_scope.dart';
import '../../../core/design/app_tokens.dart';
import '../../../models/HomeFeatureModel.dart';
import '../../../utlis/app_router.dart';

class HomeModuleLinks extends StatelessWidget {
  const HomeModuleLinks({
    super.key,
    required this.features,
    this.minimal = false,
    this.onModuleReturn,
  });

  final List<HomeFeatureModel> features;
  final bool minimal;
  final VoidCallback? onModuleReturn;

  @override
  Widget build(BuildContext context) {
    if (features.isEmpty) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton.icon(
          onPressed: () => openResponsiveModule(context, RoutesStr.homeSetting),
          icon: const Icon(Icons.tune_rounded),
          label: const Text('Choose quick access shortcuts'),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1160
            ? 8
            : constraints.maxWidth >= 940
                ? 7
                : constraints.maxWidth >= 720
                    ? 6
                    : constraints.maxWidth >= 520
                        ? 5
                        : constraints.maxWidth < 340
                            ? 3
                            : 4;
        const spacing = AppSpacing.xs;
        final width =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: features
              .map(
                (feature) => SizedBox.square(
                  dimension: width,
                  child: _ModuleLinkCard(
                    feature: feature,
                    minimal: minimal,
                    onReturn: onModuleReturn,
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _ModuleLinkCard extends StatelessWidget {
  const _ModuleLinkCard({
    required this.feature,
    required this.minimal,
    this.onReturn,
  });

  final HomeFeatureModel feature;
  final bool minimal;
  final VoidCallback? onReturn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = Color(feature.colorCode);
    final icon = feature.iconCode >= 0 && feature.iconCode < homeIconList.length
        ? homeIconList[feature.iconCode]
        : Icons.widgets_outlined;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.medium,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await openResponsiveModule(context, feature.route);
          onReturn?.call();
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: minimal ? 38 : 36,
                height: minimal ? 38 : 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withOpacity(isDark ? .22 : .11),
                  borderRadius: AppRadius.small,
                ),
                child: Icon(icon, color: color, size: minimal ? 21 : 20),
              ),
              const SizedBox(height: 6),
              Text(
                _title(feature),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _title(HomeFeatureModel feature) {
    return switch (feature.id) {
      10 => 'Media Studio',
      12 => 'Doc Scanner',
      _ => feature.title,
    };
  }
}
