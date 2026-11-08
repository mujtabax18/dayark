import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_tokens.dart';
import '../../../core/design/responsive_layout.dart';
import '../../../core/theme/theme_x.dart';
import '../../../models/HomeFeatureModel.dart';
import '../../../models/HomeLayoutSettings.dart';
import '../controller/home_layout_provider.dart';
import '../controller/home_provider.dart';

part 'parts/home_screen_alignment_style_selector.dart';
part 'parts/home_screen_alignment_toggle_reorder_card.dart';

class HomePageAlignment extends ConsumerWidget {
  const HomePageAlignment({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features = [...ref.watch(homeProvider)]
      ..sort((a, b) => a.position.compareTo(b.position));
    final layout = ref.watch(homeLayoutProvider);
    final neutral = context.themeColors.neutral;
    final notifier = ref.read(homeLayoutProvider.notifier);

    return Scaffold(
      backgroundColor: neutral.background,
      appBar: AppBar(
        backgroundColor: neutral.background,
        elevation: 0,
        centerTitle: MediaQuery.sizeOf(context).width < 1100,
        title: Text(
          'Home & navigation',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: neutral.textPrimary,
          ),
        ),
        iconTheme: IconThemeData(color: neutral.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        child: ResponsiveContent(
          maxWidth: 1100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              title: 'Home layout',
              subtitle: 'Choose the amount of information shown on Home.',
            ),
            const SizedBox(height: AppSpacing.sm),
            _StyleSelector(
              selected: layout.style,
              onChanged: notifier.setStyle,
            ),
            const SizedBox(height: AppSpacing.xl),
            const _SectionHeader(
              title: 'Summary UI',
              subtitle: 'Choose how the selected Home summaries are presented.',
            ),
            const SizedBox(height: AppSpacing.sm),
            _SummaryStyleSelector(
              selected: layout.summaryStyle,
              onChanged: notifier.setSummaryStyle,
            ),
            const SizedBox(height: AppSpacing.xl),
            const _SectionHeader(
              title: 'Create new UI',
              subtitle: 'Choose how quick creation is shown when the navigation bar is hidden.',
            ),
            const SizedBox(height: AppSpacing.sm),
            _CreateStyleSelector(
              selected: layout.createStyle,
              onChanged: notifier.setCreateStyle,
            ),
            const SizedBox(height: AppSpacing.lg),
            _SettingsSwitchCard(
              icon: layout.showNavigationBar
                  ? Icons.dock_rounded
                  : Icons.space_bar_rounded,
              title: 'Navigation layout',
              subtitle: layout.showNavigationBar
                  ? 'Phone: bottom navigation • Desktop: expanded admin sidebar.'
                  : 'Phone: hidden navigation • Desktop: compact admin sidebar.',
              value: layout.showNavigationBar,
              onChanged: notifier.setNavigationBarVisible,
            ),
            const SizedBox(height: AppSpacing.sm),
            _SettingsSwitchCard(
              icon: Icons.format_quote_rounded,
              title: 'Quotation card',
              subtitle: 'Use a random quotation from the offline quote library.',
              value: layout.showQuote,
              onChanged: notifier.setQuoteVisible,
            ),
            const SizedBox(height: AppSpacing.xl),
            const _SectionHeader(
              title: 'Home summaries',
              subtitle:
                  'Choose which summaries appear on Home and set the position of each card.',
            ),
            const SizedBox(height: AppSpacing.sm),
            _SummarySettingsList(
              order: layout.summaryOrder,
              visibleIds: layout.visibleSummaryIds,
              onVisibilityChanged: notifier.setSummaryVisible,
              onReorder: notifier.updateSummaryOrder,
            ),
            const SizedBox(height: AppSpacing.xl),
            const _SectionHeader(
              title: 'Create new shortcuts',
              subtitle:
                  'Choose and reorder the shortcuts used by the Create new dock.',
            ),
            const SizedBox(height: AppSpacing.sm),
            _QuickActionSettingsList(
              order: layout.quickActionOrder,
              visibleIds: layout.visibleQuickActionIds,
              onVisibilityChanged: notifier.setQuickActionVisible,
              onReorder: notifier.updateQuickActionOrder,
            ),
            const SizedBox(height: AppSpacing.xl),
            const _SectionHeader(
              title: 'Quick access',
              subtitle:
                  'Choose module shortcuts and drag them into the preferred order.',
            ),
            const SizedBox(height: AppSpacing.sm),
            _QuickAccessSettingsList(
              features: features
                  .where((feature) => feature.id != 4)
                  .toList(growable: false),
              visibleIds: layout.visibleQuickAccessIds,
              onVisibilityChanged: notifier.setQuickAccessVisible,
              onReorder: (updated) => _saveQuickAccessOrder(
                ref,
                features,
                updated,
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveQuickAccessOrder(
    WidgetRef ref,
    List<HomeFeatureModel> allFeatures,
    List<HomeFeatureModel> quickLinks,
  ) async {
    final settings = allFeatures.where((feature) => feature.id == 4);
    await ref.read(homeProvider.notifier).updateFeaturePositions([
      ...quickLinks,
      ...settings,
    ]);
  }
}

