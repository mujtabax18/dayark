import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_tokens.dart';
import '../../../localization/app_localizations.dart';
import '../../../models/HomeFeatureModel.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    this.settingsFeature,
    required this.onRefresh,
  });

  final HomeFeatureModel? settingsFeature;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.45,
                  height: 1.06,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                context.l10n.tr('dailyOverview'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _HeaderAction(
          tooltip: context.l10n.tr('refresh'),
          icon: Icons.refresh_rounded,
          onPressed: onRefresh,
        ),
        if (settingsFeature != null) ...[
          const SizedBox(width: AppSpacing.xs),
          _HeaderAction(
            tooltip: context.l10n.tr('settings'),
            icon: Icons.settings_outlined,
            onPressed: () => context.push(settingsFeature!.route),
          ),
        ],
      ],
    );
  }

  String _greeting(BuildContext context) {
    final hour = DateTime.now().hour;
    if (hour < 12) return '${context.l10n.tr('goodMorning')} 👋';
    if (hour < 17) return '${context.l10n.tr('goodAfternoon')}';
    return '${context.l10n.tr('goodEvening')} 🌙';
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 40,
      child: IconButton.filledTonal(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        iconSize: 19,
        icon: Icon(icon),
      ),
    );
  }
}
