part of '../main_navigation_shell.dart';

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  String? _desktopRoute;

  StatefulNavigationShell get navigationShell => widget.navigationShell;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final homeLayout = ref.watch(homeLayoutProvider);
    final loadedFeatures = ref.watch(homeProvider);
    final desktopFeatures = <HomeFeatureModel>[
      ...(loadedFeatures.isEmpty
          ? HomeFeatureModel.defaultFeatures
          : loadedFeatures),
    ]..sort((a, b) => a.position.compareTo(b.position));
    final showNavigation = homeLayout.showNavigationBar;
    final isHome = navigationShell.currentIndex == 0;
    final isDesktopAdmin =
        MediaQuery.sizeOf(context).width >= _desktopAdminBreakpoint;
    final useRail =
        !isDesktopAdmin && showNavigation && context.usesNavigationRail;

    return PopScope(
      canPop:
          navigationShell.currentIndex == 0 &&
          (!isDesktopAdmin || _desktopRoute == null),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (isDesktopAdmin && _desktopRoute != null) {
          setState(() => _desktopRoute = null);
          return;
        }
        if (navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0);
        }
      },
      child: isDesktopAdmin
          ? DesktopNavigationScope(
              onOpenRoute: _openDesktopRoute,
              onDashboard: _openDesktopDashboard,
              child: _DesktopAdminShell(
                navigationShell: navigationShell,
                selectedIndex: navigationShell.currentIndex,
                features: desktopFeatures,
                activeRoute: _desktopRoute,
                expandedNavigation: true,
                desktopContent: _buildDesktopContent(),
                onDestinationSelected: _selectBranch,
                onDesktopRouteSelected: _openDesktopRoute,
                onDashboardSelected: _openDesktopDashboard,
                onQuickAdd: () => showMainQuickCreateSheet(
                  context,
                  ref,
                  onInvoiceCreate: () =>
                      _openDesktopRoute('${RoutesStr.invoices}/new'),
                ),
                onSettings: () => _openDesktopRoute(RoutesStr.settings),
              ),
            )
          : Scaffold(
              extendBody: !useRail,
              body: useRail
                  ? Row(
                      children: [
                        SafeArea(
                          right: false,
                          child: _AppNavigationRail(
                            selectedIndex: navigationShell.currentIndex,
                            extended: context.usesExtendedNavigationRail,
                            onDestinationSelected: _selectBranch,
                          ),
                        ),
                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: scheme.outlineVariant.withOpacity(.75),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1600),
                              child: navigationShell,
                            ),
                          ),
                        ),
                      ],
                    )
                  : navigationShell,
              floatingActionButtonLocation: showNavigation && !useRail
                  ? FloatingActionButtonLocation.centerDocked
                  : FloatingActionButtonLocation.endFloat,
              floatingActionButton: showNavigation
                  ? FloatingActionButton(
                      heroTag: 'main_quick_add',
                      tooltip: context.l10n.tr('quickAdd'),
                      elevation: 3,
                      highlightElevation: 4,
                      onPressed: () => showMainQuickCreateSheet(context, ref),
                      child: const Icon(Icons.add_rounded, size: 30),
                    )
                  : isHome && homeLayout.createStyle == HomeCreateStyle.floating
                  ? _HiddenNavigationHomeActions(
                      onSettingsPressed: () => context.push('/settings'),
                      onAddPressed: () =>
                          showMainQuickCreateSheet(context, ref),
                    )
                  : null,
              bottomNavigationBar: showNavigation && !useRail
                  ? BottomAppBar(
                      shape: const CircularNotchedRectangle(),
                      notchMargin: 8,
                      elevation: 8,
                      shadowColor: Colors.black.withOpacity(.12),
                      color: scheme.surface,
                      padding: EdgeInsets.zero,
                      child: SafeArea(
                        top: false,
                        child: SizedBox(
                          height: 64,
                          child: Row(
                            children: [
                              Expanded(
                                child: _NavigationItem(
                                  label: context.l10n.tr('home'),
                                  icon: Icons.home_outlined,
                                  selectedIcon: Icons.home_rounded,
                                  selected: navigationShell.currentIndex == 0,
                                  onTap: () => _selectBranch(0),
                                ),
                              ),
                              Expanded(
                                child: _NavigationItem(
                                  label: context.l10n.tr('finance'),
                                  icon: Icons.account_balance_wallet_outlined,
                                  selectedIcon:
                                      Icons.account_balance_wallet_rounded,
                                  selected: navigationShell.currentIndex == 1,
                                  onTap: () => _selectBranch(1),
                                ),
                              ),
                              const SizedBox(width: 68),
                              Expanded(
                                child: _NavigationItem(
                                  label: context.l10n.tr('planner'),
                                  icon: Icons.event_note_outlined,
                                  selectedIcon: Icons.event_note_rounded,
                                  selected: navigationShell.currentIndex == 2,
                                  onTap: () => _selectBranch(2),
                                ),
                              ),
                              Expanded(
                                child: _NavigationItem(
                                  label: context.l10n.tr('more'),
                                  icon: Icons.grid_view_outlined,
                                  selectedIcon: Icons.grid_view_rounded,
                                  selected: navigationShell.currentIndex == 3,
                                  onTap: () => _selectBranch(3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : !showNavigation &&
                        isHome &&
                        homeLayout.createStyle == HomeCreateStyle.dock
                  ? HomeCreateDock(
                      actionOrder: homeLayout.quickActionOrder,
                      visibleActionIds: homeLayout.visibleQuickActionIds,
                      onSettingsPressed: () => context.push('/settings'),
                    )
                  : null,
            ),
    );
  }

  void _openDesktopDashboard() {
    if (navigationShell.currentIndex != 0) {
      navigationShell.goBranch(0);
    }
    if (_desktopRoute != null) {
      setState(() => _desktopRoute = null);
    }
  }

  void _openDesktopRoute(String route) {
    final normalizedRoute = route.split('?').first;
    if (_desktopRoute == normalizedRoute) return;
    setState(() => _desktopRoute = normalizedRoute);
  }

  Widget? _buildDesktopContent() {
    final route = _desktopRoute;
    if (route == null) return null;

    final child = switch (route) {
      RoutesStr.meterList => MeterListPage(
          onDesktopDashboard: _openDesktopDashboard,
        ),
      RoutesStr.grocery => GroceryTitlesPage(onDesktopBack: _openDesktopDashboard),
      RoutesStr.expense => ExpensesTitlesPage(onDesktopBack: _openDesktopDashboard),
      RoutesStr.moodTracker => const PersonalDiaryScreen(),
      RoutesStr.habits => const HabitDesktopDashboard(),
      RoutesStr.quotes => const QuotationDesktopDashboard(),
      RoutesStr.invoices => const InvoiceDesktopDashboard(),
      '${RoutesStr.invoices}/new' =>
          const InvoiceDesktopDashboard(openCreateOnStart: true),
      RoutesStr.loans => const DigitalKhataDesktopDashboard(),
      RoutesStr.multimedia => const MultimediaDashboard(),
      RoutesStr.pillReminder => const PillDesktopDashboard(),
      RoutesStr.scannerGallery => const ScannerDesktopDashboard(),
      RoutesStr.tutorials => const TutorialCenterScreen(),
      RoutesStr.familyTrees => const FamilyTreeHomeScreen(),
      RoutesStr.deviceSync => const DeviceSyncScreen(),
      RoutesStr.primaryLocalBackups => const PrimaryLocalBackupsScreen(),
      RoutesStr.backupCompatibility => const LegacyBackupCompatibilityScreen(),
      RoutesStr.backup => const SettingScreen(),
      RoutesStr.settings => const SettingScreen(),
      RoutesStr.dataBaseViewer => const DBInspectorScreen(),
      RoutesStr.homeSetting => const HomePageAlignment(),
      _ => null,
    };

    if (child == null) return null;
    return KeyedSubtree(key: ValueKey(route), child: child);
  }

  void _selectBranch(int index) {
    if (_desktopRoute != null) {
      setState(() => _desktopRoute = null);
    }
    if (index == navigationShell.currentIndex) return;
    navigationShell.goBranch(index);
  }
}

class _DesktopAdminShell extends StatelessWidget {
  const _DesktopAdminShell({
    required this.navigationShell,
    required this.selectedIndex,
    required this.features,
    required this.activeRoute,
    required this.expandedNavigation,
    required this.desktopContent,
    required this.onDestinationSelected,
    required this.onDesktopRouteSelected,
    required this.onDashboardSelected,
    required this.onQuickAdd,
    required this.onSettings,
  });

  final StatefulNavigationShell navigationShell;
  final int selectedIndex;
  final List<HomeFeatureModel> features;
  final String? activeRoute;
  final bool expandedNavigation;
  final Widget? desktopContent;
  final ValueChanged<int> onDestinationSelected;
  final ValueChanged<String> onDesktopRouteSelected;
  final VoidCallback onDashboardSelected;
  final VoidCallback onQuickAdd;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Row(
          children: [
            _DesktopSidebar(
              selectedIndex: selectedIndex,
              features: features,
              activeRoute: activeRoute,
              expanded: expandedNavigation,
              onDestinationSelected: onDestinationSelected,
              onDesktopRouteSelected: onDesktopRouteSelected,
              onDashboardSelected: onDashboardSelected,
              onSettings: onSettings,
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: scheme.outlineVariant.withOpacity(.7),
            ),
            Expanded(
              child: ColoredBox(
                color: scheme.surface.withOpacity(.98),
                child: Column(
                  children: [
                    _DesktopTopBar(
                      selectedIndex: selectedIndex,
                      activeRoute: activeRoute,
                      onQuickAdd: onQuickAdd,
                      onSettings: onSettings,
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: scheme.outlineVariant.withOpacity(.7),
                    ),
                    Expanded(child: desktopContent ?? navigationShell),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

