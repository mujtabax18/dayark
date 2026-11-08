part of '../HomeScreen.dart';

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showWelcomeOnce());
  }

  Future<void> _showWelcomeOnce() async {
    final controller = ref.read(userSettingsControllerProvider);
    final seen = await controller.hasSeenTutorialWelcome();
    if (seen || !mounted) return;

    final openTutorials = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.auto_awesome_outlined),
        title: Text(context.l10n.tr('welcomeTitle')),
        content: Text(context.l10n.tr('welcomeBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.tr('notNow')),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.school_outlined),
            label: Text(context.l10n.tr('startTutorials')),
          ),
        ],
      ),
    );

    await controller.markTutorialWelcomeSeen();
    if (openTutorials == true && mounted) {
      context.push(RoutesStr.tutorials);
    }
  }

  @override
  Widget build(BuildContext context) {
    final features = [...ref.watch(homeProvider)]
      ..sort((a, b) => a.position.compareTo(b.position));
    final layout = ref.watch(homeLayoutProvider);
    final isDesktop = MediaQuery.sizeOf(context).width >= 1100;
    final AsyncValue<DashboardSummary>? summary =
        isDesktop || layout.style != HomePageStyle.quickLinks
            ? ref.watch(homeDashboardProvider)
            : null;
    final quoteAtTop = layout.showQuote &&
        (layout.style == HomePageStyle.detailed ||
            layout.style == HomePageStyle.quickLinks);

    if (isDesktop) {
      return _buildDesktopDashboard(
        features: features,
        layout: layout,
        summary: summary!,
      );
    }

    // Keep the existing phone/tablet experience unchanged.
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ResponsivePageFrame(
          child: RefreshIndicator(
            onRefresh: () => _refresh(layout.style),
            child: CustomScrollView(
              key: const PageStorageKey<String>('home-dashboard-scroll'),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                  sliver: SliverToBoxAdapter(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ActionChip(
                        avatar: const Icon(Icons.devices_rounded, size: 19),
                        label: const Text('Local Device Sync'),
                        onPressed: () => context.push(RoutesStr.deviceSync),
                      ),
                    ),
                  ),
                ),
                if (quoteAtTop)
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: HomeQuoteCard(compact: true),
                    ),
                  ),
                ...switch (layout.style) {
                  HomePageStyle.detailed => _detailedSlivers(
                      features: features,
                      summary: summary!,
                      layout: layout,
                    ),
                  HomePageStyle.quickLinks => _minimalSlivers(
                      features,
                      layout,
                    ),
                  HomePageStyle.compact => _compactSlivers(
                      features: features,
                      summary: summary!,
                      layout: layout,
                    ),
                  HomePageStyle.glance => _glanceSlivers(
                      features: features,
                      summary: summary!,
                      layout: layout,
                    ),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopDashboard({
    required List<HomeFeatureModel> features,
    required HomeLayoutSettings layout,
    required AsyncValue<DashboardSummary> summary,
  }) {
    final scheme = Theme.of(context).colorScheme;
    // Desktop always exposes every functional module directly. The mobile
    // quick-access preferences remain unchanged and still use _moduleLinks().
    final moduleLinks = features
        .where((feature) => feature.id != 4)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        bottom: false,
        child: ResponsivePageFrame(
          maxWidth: 1480,
          child: RefreshIndicator(
            onRefresh: _refreshDesktop,
            child: CustomScrollView(
              key: const PageStorageKey<String>('home-desktop-dashboard-scroll'),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
                  sliver: SliverToBoxAdapter(
                    child: _DesktopDashboardIntro(
                      onCustomize: () => context.push(RoutesStr.homeSetting),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverToBoxAdapter(
                    child: _SectionTitle(
                      title: 'Workspace overview',
                      action: TextButton.icon(
                        onPressed: () => context.push(RoutesStr.homeSetting),
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        label: const Text('Customize'),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
                  sliver: SliverToBoxAdapter(
                    child: summary.when(
                      data: (data) => _summaryWidget(data, layout),
                      loading: () => _DashboardLoading(
                        height: _summaryLoadingHeight(layout.summaryStyle),
                      ),
                      error: (_, __) => const _DashboardError(),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    0,
                    24,
                    context.mainShellBottomPadding + 24,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final quickAccess = _DesktopDashboardPanel(
                          title: context.l10n.tr('quickAccess'),
                          subtitle:
                              'All app features are available here for direct access.',
                          child: HomeModuleLinks(
                            features: moduleLinks,
                            onModuleReturn: _invalidateHomeData,
                          ),
                        );

                        if (!layout.showQuote || constraints.maxWidth < 1040) {
                          return Column(
                            children: [
                              quickAccess,
                              if (layout.showQuote) ...[
                                const SizedBox(height: 16),
                                const _DesktopDashboardPanel(
                                  title: 'Daily quotation',
                                  subtitle: 'A small note for your day.',
                                  child: HomeQuoteCard(compact: false),
                                ),
                              ],
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 7, child: quickAccess),
                            const SizedBox(width: 16),
                            const Expanded(
                              flex: 3,
                              child: _DesktopDashboardPanel(
                                title: 'Daily quotation',
                                subtitle: 'A small note for your day.',
                                child: HomeQuoteCard(compact: false),
                              ),
                            ),
                          ],
                        );
                      },
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

  Future<void> _refreshDesktop() async {
    ref.invalidate(homeQuoteProvider);
    ref.invalidate(homeDashboardProvider);
    final futures = <Future<void>>[
      ref.read(homeProvider.notifier).loadFeatures(),
      ref.read(homeLayoutProvider.notifier).load(),
      ref.read(homeDashboardProvider.future).then((_) {}),
    ];
    try {
      await Future.wait(futures);
    } catch (_) {
      // Individual dashboard widgets render their own error states.
    }
  }

  Future<void> _refresh(HomePageStyle style) async {
    ref.invalidate(homeQuoteProvider);
    final futures = <Future<void>>[
      ref.read(homeProvider.notifier).loadFeatures(),
      ref.read(homeLayoutProvider.notifier).load(),
    ];
    if (style != HomePageStyle.quickLinks) {
      ref.invalidate(homeDashboardProvider);
      futures.add(ref.read(homeDashboardProvider.future).then((_) {}));
    }
    try {
      await Future.wait(futures);
    } catch (_) {
      // Individual dashboard widgets render their own error states.
    }
  }

  List<Widget> _detailedSlivers({
    required List<HomeFeatureModel> features,
    required AsyncValue<DashboardSummary> summary,
    required HomeLayoutSettings layout,
  }) {
    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          layout.showQuote ? 0 : AppSpacing.md,
          AppSpacing.lg,
          0,
        ),
        sliver: SliverToBoxAdapter(
          child: _SectionTitle(title: context.l10n.tr('summary')),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        sliver: SliverToBoxAdapter(
          child: summary.when(
            data: (data) => _summaryWidget(data, layout),
            loading: () => _DashboardLoading(
              height: _summaryLoadingHeight(layout.summaryStyle),
            ),
            error: (_, __) => const _DashboardError(),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        sliver: SliverToBoxAdapter(
          child: _SectionTitle(title: context.l10n.tr('quickAccess')),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          context.mainShellBottomPadding,
        ),
        sliver: SliverToBoxAdapter(
          child: HomeModuleLinks(
            features: _moduleLinks(features, layout),
            onModuleReturn: _invalidateHomeData,
          ),
        ),
      ),
    ];
  }

  List<Widget> _minimalSlivers(
    List<HomeFeatureModel> features,
    HomeLayoutSettings layout,
  ) {
    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          layout.showQuote ? 0 : AppSpacing.md,
          AppSpacing.lg,
          0,
        ),
        sliver: SliverToBoxAdapter(
          child: _SectionTitle(title: context.l10n.tr('quickAccess')),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          context.mainShellBottomPadding,
        ),
        sliver: SliverToBoxAdapter(
          child: HomeModuleLinks(
            features: _moduleLinks(features, layout),
            minimal: true,
            onModuleReturn: _invalidateHomeData,
          ),
        ),
      ),
    ];
  }

  List<Widget> _compactSlivers({
    required List<HomeFeatureModel> features,
    required AsyncValue<DashboardSummary> summary,
    required HomeLayoutSettings layout,
  }) {
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          0,
        ),
        sliver: SliverToBoxAdapter(
          child: _SectionTitle(title: context.l10n.tr('summary')),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          layout.showQuote ? AppSpacing.sm : AppSpacing.lg,
        ),
        sliver: SliverToBoxAdapter(
          child: summary.when(
            data: (data) => _summaryWidget(data, layout),
            loading: () => _DashboardLoading(
              height: _summaryLoadingHeight(layout.summaryStyle),
            ),
            error: (_, __) => const _DashboardError(),
          ),
        ),
      ),
      if (layout.showQuote)
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          sliver: SliverToBoxAdapter(
            child: HomeQuoteCard(compact: true),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        sliver: SliverToBoxAdapter(
          child: _SectionTitle(title: context.l10n.tr('quickAccess')),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          context.mainShellBottomPadding,
        ),
        sliver: SliverToBoxAdapter(
          child: HomeModuleLinks(
            features: _moduleLinks(features, layout),
            onModuleReturn: _invalidateHomeData,
          ),
        ),
      ),
    ];
  }

  List<Widget> _glanceSlivers({
    required List<HomeFeatureModel> features,
    required AsyncValue<DashboardSummary> summary,
    required HomeLayoutSettings layout,
  }) {
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          0,
        ),
        sliver: SliverToBoxAdapter(
          child: _SectionTitle(
            title: 'Today at a glance',
            action: TextButton(
              onPressed: () => context.push(RoutesStr.homeSetting),
              child: const Text('View all'),
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        sliver: SliverToBoxAdapter(
          child: summary.when(
            data: (data) => _summaryWidget(data, layout),
            loading: () => _DashboardLoading(
              height: _summaryLoadingHeight(layout.summaryStyle),
            ),
            error: (_, __) => const _DashboardError(),
          ),
        ),
      ),
      if (layout.showQuote)
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          sliver: SliverToBoxAdapter(
            child: HomeQuoteCard(compact: false),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        sliver: SliverToBoxAdapter(
          child: _SectionTitle(
            title: context.l10n.tr('quickAccess'),
            action: TextButton(
              onPressed: () => context.push(RoutesStr.homeSetting),
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          context.mainShellBottomPadding,
        ),
        sliver: SliverToBoxAdapter(
          child: HomeModuleLinks(
            features: _moduleLinks(features, layout),
            onModuleReturn: _invalidateHomeData,
          ),
        ),
      ),
    ];
  }

  Widget _summaryWidget(
    DashboardSummary data,
    HomeLayoutSettings layout,
  ) {
    return switch (layout.summaryStyle) {
      HomeSummaryStyle.cards => DashboardSummaryGrid(
          summary: data,
          summaryOrder: layout.summaryOrder,
          visibleSummaryIds: layout.visibleSummaryIds,
        ),
      HomeSummaryStyle.compact => CompactDashboardSummaries(
          summary: data,
          summaryOrder: layout.summaryOrder,
          visibleSummaryIds: layout.visibleSummaryIds,
        ),
      HomeSummaryStyle.glance => GlanceDashboardSummaries(
          summary: data,
          summaryOrder: layout.summaryOrder,
          visibleSummaryIds: layout.visibleSummaryIds,
        ),
    };
  }

  double _summaryLoadingHeight(HomeSummaryStyle style) {
    return switch (style) {
      HomeSummaryStyle.cards => 112,
      HomeSummaryStyle.compact => 96,
      HomeSummaryStyle.glance => 90,
    };
  }

  void _invalidateHomeData() {
    ref.invalidate(homeDashboardProvider);
    ref.invalidate(homeQuoteProvider);
  }

  List<HomeFeatureModel> _moduleLinks(
    List<HomeFeatureModel> features,
    HomeLayoutSettings layout,
  ) {
    return features
        .where((feature) => feature.id != 4)
        .where((feature) => layout.visibleQuickAccessIds.contains(feature.id))
        .toList(growable: false);
  }
}

