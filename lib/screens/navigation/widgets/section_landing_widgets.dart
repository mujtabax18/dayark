import 'package:flutter/material.dart';

import '../../../core/design/app_tokens.dart';
import '../../../core/widgets/common/app_surface.dart';

class LandingHeader extends StatelessWidget {
  const LandingHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onRefresh,
  });

  final String title;
  final String subtitle;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final desktop = MediaQuery.sizeOf(context).width >= 1100;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: (desktop
                        ? Theme.of(context).textTheme.headlineMedium
                        : Theme.of(context).textTheme.headlineSmall)
                    ?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: (desktop
                        ? Theme.of(context).textTheme.bodyMedium
                        : Theme.of(context).textTheme.bodySmall)
                    ?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        if (desktop)
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 19),
            label: const Text('Refresh'),
          )
        else
          SizedBox.square(
            dimension: 40,
            child: IconButton.filledTonal(
              tooltip: 'Refresh',
              onPressed: onRefresh,
              padding: EdgeInsets.zero,
              iconSize: 19,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
      ],
    );
  }
}

class LandingSectionTitle extends StatelessWidget {
  const LandingSectionTitle({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }
}

class LandingFeature {
  const LandingFeature({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class LandingFeatureGrid extends StatelessWidget {
  const LandingFeatureGrid({super.key, required this.features});

  final List<LandingFeature> features;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1120
            ? 5
            : constraints.maxWidth >= 820
                ? 4
                : constraints.maxWidth >= 560
                    ? 3
                    : 2;
        const spacing = AppSpacing.xs;
        final width =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: features
              .map(
                (feature) => SizedBox(
                  width: width,
                  child: _LandingFeatureCard(feature: feature),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _LandingFeatureCard extends StatelessWidget {
  const _LandingFeatureCard({required this.feature});

  final LandingFeature feature;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final desktop = MediaQuery.sizeOf(context).width >= 1100;
    return AppSurface(
      onTap: feature.onTap,
      padding: EdgeInsets.all(desktop ? AppSpacing.md : AppSpacing.sm),
      borderRadius: AppRadius.medium,
      child: SizedBox(
        height: desktop ? 104 : 94,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: feature.color.withOpacity(isDark ? .22 : .11),
                    borderRadius: AppRadius.small,
                  ),
                  child: Icon(feature.icon, color: feature.color, size: 20),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
            const Spacer(),
            Text(
              feature.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              feature.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class OverviewMetric extends StatelessWidget {
  const OverviewMetric({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 5),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
