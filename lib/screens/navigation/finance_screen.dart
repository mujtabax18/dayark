import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/app_tokens.dart';
import '../../core/design/responsive_layout.dart';
import '../../core/widgets/common/app_surface.dart';
import '../../controller/currency_notifier.dart';
import '../../models/currency_setting.dart';
import '../../models/dashboard_summary.dart';
import '../../utlis/app_router.dart';
import '../HomeScreen/controller/dashboard_provider.dart';
import '../quotation/controller/quotation_controller.dart';
import 'widgets/desktop_navigation_scope.dart';
import 'widgets/section_landing_widgets.dart';

part 'parts/finance_screen_finance_overview_cards.dart';
part 'parts/finance_screen_loading_card.dart';

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(homeDashboardProvider);
    final quotationCount = ref.watch(quotationCountProvider);
    final currency = ref.watch(currencyProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ResponsivePageFrame(
          maxWidth: 1440,
          child: RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: CustomScrollView(
            key: const PageStorageKey<String>('finance-section-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                sliver: SliverToBoxAdapter(
                  child: LandingHeader(
                    title: 'Finance',
                    subtitle: 'Money, accounts and financial documents',
                    onRefresh: () => _refresh(ref),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                sliver: SliverToBoxAdapter(
                  child: summary.when(
                    data: (data) => _FinanceOverviewCards(
                      summary: data,
                      currency: currency,
                    ),
                    loading: () => const _LoadingCard(height: 166),
                    error: (_, __) => _ErrorCard(
                      onRetry: () => ref.invalidate(homeDashboardProvider),
                    ),
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
                sliver: SliverToBoxAdapter(
                  child: LandingSectionTitle(
                    title: 'Finance tools',
                    subtitle: 'Open the existing modules without duplicating their logic.',
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                sliver: SliverToBoxAdapter(
                  child: LandingFeatureGrid(
                    features: [
                      LandingFeature(
                        title: 'Expenses',
                        subtitle: 'Income and spending',
                        icon: Icons.account_balance_wallet_outlined,
                        color: const Color(0xFFF43F5E),
                        onTap: () => _openModule(context, ref, RoutesStr.expense),
                      ),
                      LandingFeature(
                        title: 'Digital Khata & Loans',
                        subtitle: 'Accounts and repayments',
                        icon: Icons.account_balance_outlined,
                        color: const Color(0xFF0891B2),
                        onTap: () => _openModule(context, ref, RoutesStr.loans),
                      ),
                      LandingFeature(
                        title: 'Invoices',
                        subtitle: 'Create and manage',
                        icon: Icons.receipt_long_outlined,
                        color: const Color(0xFF6366F1),
                        onTap: () => _openModule(context, ref, RoutesStr.invoices),
                      ),
                      LandingFeature(
                        title: 'Quotations',
                        subtitle: 'Financial documents',
                        icon: Icons.request_quote_outlined,
                        color: const Color(0xFF7C3AED),
                        onTap: () => _openModule(
                          context,
                          ref,
                          RoutesStr.quotes,
                          refreshQuotations: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
                sliver: SliverToBoxAdapter(
                  child: LandingSectionTitle(
                    title: 'Current activity',
                    subtitle: 'Live counts from the existing local data.',
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  context.mainShellBottomPadding,
                ),
                sliver: SliverToBoxAdapter(
                  child: _CurrentFinanceActivity(
                    summary: summary.asData?.value,
                    quotationCount: quotationCount.asData?.value,
                  ),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openModule(
    BuildContext context,
    WidgetRef ref,
    String route, {
    bool refreshQuotations = false,
  }) async {
    await openResponsiveModule(context, route);
    ref.invalidate(homeDashboardProvider);
    if (refreshQuotations) ref.invalidate(quotationCountProvider);
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(homeDashboardProvider);
    ref.invalidate(quotationCountProvider);
    try {
      await Future.wait([
        ref.read(homeDashboardProvider.future),
        ref.read(quotationCountProvider.future),
      ]);
    } catch (_) {
      // The overview cards display provider-specific retry states.
    }
  }
}

