import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../navigation/widgets/desktop_navigation_scope.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/widgets/common/app_surface.dart';
import '../../../localization/app_localizations.dart';
import '../../../models/HomeFeatureModel.dart';
import '../../../utlis/constant.dart';

class HomeFeatureCard extends StatelessWidget {
  const HomeFeatureCard({
    super.key,
    required this.feature,
    required this.index,
  });

  final HomeFeatureModel feature;
  final int index;

  @override
  Widget build(BuildContext context) {
    final accent = Color(feature.colorCode);
    final icon = feature.iconCode >= 0 && feature.iconCode < homeIconList.length
        ? homeIconList[feature.iconCode]
        : Icons.widgets_outlined;
    final animationDuration = Duration(
      milliseconds: 280 + (index.clamp(0, 8).toInt() * 25),
    );

    return TweenAnimationBuilder<double>(
      duration: animationDuration,
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - value)),
            child: child,
          ),
        );
      },
      child: AppSurface(
        onTap: () => openResponsiveModule(context, feature.route),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withOpacity(
                  Theme.of(context).brightness == Brightness.dark ? .20 : .11,
                ),
                borderRadius: AppRadius.medium,
              ),
              child: Icon(icon, color: accent, size: 25),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _localizedTitle(context),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }

  String _localizedTitle(BuildContext context) {
    final key = switch (feature.id) {
      1 => 'meters',
      2 => 'grocery',
      3 => 'expenses',
      4 => 'settings',
      5 => 'diary',
      6 => 'habits',
      7 => 'quotes',
      8 => 'invoices',
      9 => 'loans',
      10 => 'photoEditor',
      11 => 'pillReminder',
      12 => 'docScanner',
      13 => 'tutorials',
      _ => '',
    };
    return key.isEmpty ? feature.title : context.l10n.tr(key);
  }
}
