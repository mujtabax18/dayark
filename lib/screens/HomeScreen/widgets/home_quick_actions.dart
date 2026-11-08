import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../navigation/widgets/desktop_navigation_scope.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/widgets/common/app_surface.dart';
import '../../../models/HomeFeatureModel.dart';
import '../../../models/dashboard_summary.dart';
import '../../../utlis/app_router.dart';
import '../../../utlis/platform_capabilities.dart';
import '../controller/dashboard_provider.dart';
import 'dashboard_quick_actions.dart';

class HomeQuickActions extends ConsumerWidget {
  const HomeQuickActions({
    super.key,
    required this.features,
    this.summary,
  });

  final List<HomeFeatureModel> features;
  final DashboardSummary? summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = <_QuickAction>[
      _QuickAction(
        title: 'New invoice',
        subtitle: summary == null || summary!.invoiceCount == 0
            ? 'Create an invoice'
            : '${summary!.invoiceCount} saved invoice(s)',
        icon: Icons.post_add_rounded,
        color: const Color(0xFF6366F1),
        onTap: () async {
          await openResponsiveModule(context, '${RoutesStr.invoices}/new');
          ref.invalidate(homeDashboardProvider);
        },
      ),
      _QuickAction(
        title: 'Media Studio',
        subtitle: summary == null || summary!.mediaFileCount == 0
            ? 'Image, PDF and video'
            : '${summary!.mediaFileCount} local file(s)',
        icon: Icons.auto_fix_high_rounded,
        color: const Color(0xFFE11D48),
        onTap: () => showMediaQuickActions(context, ref),
      ),
      _QuickAction(
        title: 'Write diary',
        subtitle: summary == null || summary!.diaryEntryCount == 0
            ? 'Add a private entry'
            : '${summary!.diaryEntryCount} saved page(s)',
        icon: Icons.edit_note_rounded,
        color: const Color(0xFFEC4899),
        onTap: () => openQuickDiary(context, ref),
      ),
      _QuickAction(
        title: documentScannerCaptureSupported ? 'Quick scan' : 'Documents',
        subtitle: documentScannerCaptureSupported
            ? (summary == null || summary!.scannedPageCount == 0
                ? 'Open camera scanner'
                : '${summary!.scannedPageCount} scanned page(s)')
            : (summary == null || summary!.scannedPageCount == 0
                ? 'View and manage saved scans'
                : '${summary!.scannedPageCount} saved page(s)'),
        icon: Icons.document_scanner_rounded,
        color: const Color(0xFF0EA5E9),
        onTap: () => openQuickScanner(context, ref),
      ),
      ...features.map((feature) {
        final icon = feature.iconCode >= 0 && feature.iconCode < homeIconList.length
            ? homeIconList[feature.iconCode]
            : Icons.widgets_outlined;
        return _QuickAction(
          title: _featureTitle(feature),
          subtitle: _featureSubtitle(feature.id),
          icon: icon,
          color: Color(feature.colorCode),
          onTap: () => openResponsiveModule(context, feature.route),
        );
      }),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 600
                ? 3
                : 2;
        final width =
            (constraints.maxWidth - ((columns - 1) * AppSpacing.sm)) / columns;

        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: actions
              .map(
                (action) => SizedBox(
                  width: width,
                  child: _QuickActionCard(action: action),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  String _featureTitle(HomeFeatureModel feature) {
    return switch (feature.id) {
      1 => 'Meters',
      2 => 'Grocery',
      3 => 'Expenses',
      6 => 'Habits',
      7 => 'Quotes',
      9 => 'Loans',
      11 => 'Pill reminder',
      13 => 'Tutorials',
      _ => feature.title,
    };
  }

  String _featureSubtitle(int id) {
    return switch (id) {
      1 => 'Add a meter or first reading',
      2 => 'Create a grocery plan',
      3 => 'Create category and transaction',
      6 => 'Create your first habit',
      7 => 'Open saved quotations',
      9 => 'Create a Digital Khata account',
      11 => 'Add medicine and schedule',
      13 => 'Learn every module',
      _ => 'Open module',
    };
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppSurface(
      onTap: action.onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SizedBox(
        height: 124,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: action.color.withOpacity(
                      Theme.of(context).brightness == Brightness.dark
                          ? .20
                          : .11,
                    ),
                    borderRadius: AppRadius.medium,
                  ),
                  child: Icon(action.icon, color: action.color, size: 23),
                ),
                const Spacer(),
                Icon(
                  Icons.north_east_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
            const Spacer(),
            Text(
              action.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 3),
            Text(
              action.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction({
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
