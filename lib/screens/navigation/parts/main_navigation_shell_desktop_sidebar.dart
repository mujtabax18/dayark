part of '../main_navigation_shell.dart';

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.selectedIndex,
    required this.features,
    required this.activeRoute,
    required this.expanded,
    required this.onDestinationSelected,
    required this.onDesktopRouteSelected,
    required this.onDashboardSelected,
    required this.onSettings,
  });

  final int selectedIndex;
  final List<HomeFeatureModel> features;
  final String? activeRoute;
  final bool expanded;
  final ValueChanged<int> onDestinationSelected;
  final ValueChanged<String> onDesktopRouteSelected;
  final VoidCallback onDashboardSelected;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const width = 320.0;
    final visibleFeatures = features
        .where((feature) => feature.id != 4 && feature.id != 14)
        .toList(growable: false);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: width,
      color: scheme.surface,
      padding: EdgeInsets.fromLTRB(
        expanded ? 14 : 10,
        16,
        expanded ? 14 : 10,
        14,
      ),
      child: Column(
        crossAxisAlignment: expanded
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          _DesktopBrand(expanded: expanded),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _DesktopSidebarSectionLabel(
                  label: 'DASHBOARD',
                  expanded: expanded,
                ),
                _DesktopNavItem(
                  label: context.l10n.tr('home'),
                  icon: Icons.dashboard_outlined,
                  selectedIcon: Icons.dashboard_rounded,
                  selected: selectedIndex == 0 && activeRoute == null,
                  expanded: expanded,
                  onTap: onDashboardSelected,
                ),
                const SizedBox(height: 12),
                _DesktopSidebarSectionLabel(
                  label: 'FEATURES',
                  expanded: expanded,
                ),
                for (final feature in visibleFeatures)
                  _DesktopNavItem(
                    label: _desktopFeatureTitle(feature),
                    icon: _desktopFeatureIcon(feature),
                    selectedIcon: _desktopFeatureIcon(feature),
                    selected: _routeMatches(activeRoute, feature.route),
                    expanded: expanded,
                    onTap: () => onDesktopRouteSelected(feature.route),
                  ),
                const SizedBox(height: 12),
                _DesktopSidebarSectionLabel(label: 'OTHER', expanded: expanded),
                _DesktopNavItem(
                  label: 'Life Archives',
                  icon: Icons.account_tree_outlined,
                  selectedIcon: Icons.account_tree_rounded,
                  selected: _routeMatches(activeRoute, RoutesStr.familyTrees),
                  expanded: expanded,
                  onTap: () => onDesktopRouteSelected(RoutesStr.familyTrees),
                ),
                _DesktopNavItem(
                  label: 'Local Device Sync',
                  icon: Icons.devices_rounded,
                  selectedIcon: Icons.devices_rounded,
                  selected: _routeMatches(activeRoute, RoutesStr.deviceSync),
                  expanded: expanded,
                  onTap: () => onDesktopRouteSelected(RoutesStr.deviceSync),
                ),
                _DesktopNavItem(
                  label: 'Database Inspector',
                  icon: Icons.storage_outlined,
                  selectedIcon: Icons.storage_rounded,
                  selected: _routeMatches(
                    activeRoute,
                    RoutesStr.dataBaseViewer,
                  ),
                  expanded: expanded,
                  onTap: () => onDesktopRouteSelected(RoutesStr.dataBaseViewer),
                ),
                const SizedBox(height: 12),
                _DesktopSidebarSectionLabel(
                  label: 'APPLICATION',
                  expanded: expanded,
                ),
                _DesktopNavItem(
                  label: 'Dashboard settings',
                  icon: Icons.dashboard_customize_outlined,
                  selectedIcon: Icons.dashboard_customize_rounded,
                  selected: _routeMatches(activeRoute, RoutesStr.homeSetting),
                  expanded: expanded,
                  onTap: () => onDesktopRouteSelected(RoutesStr.homeSetting),
                ),
                _DesktopNavItem(
                  label: context.l10n.tr('settings'),
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings_rounded,
                  selected: _routeMatches(activeRoute, RoutesStr.settings),
                  expanded: expanded,
                  onTap: onSettings,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _routeMatches(String? currentPath, String route) {
    final routePath = route.split('?').first;
    if (routePath.isEmpty || currentPath == null || currentPath.isEmpty) {
      return false;
    }
    return currentPath == routePath || currentPath.startsWith('$routePath/');
  }

  String _desktopFeatureTitle(HomeFeatureModel feature) {
    return switch (feature.id) {
      1 => 'Meters',
      2 => 'Grocery',
      3 => 'Expenses',
      5 => 'Personal Diary',
      6 => 'Habits',
      7 => 'Quotations',
      8 => 'Invoices',
      9 => 'Digital Khata & Loans',
      10 => 'Media Studio',
      11 => 'Pill Reminder',
      12 => 'Document Scanner',
      13 => 'Tutorials',
      _ => feature.title,
    };
  }

  IconData _desktopFeatureIcon(HomeFeatureModel feature) {
    if (feature.iconCode >= 0 && feature.iconCode < homeIconList.length) {
      return homeIconList[feature.iconCode];
    }

    return switch (feature.id) {
      1 => Icons.electric_meter_outlined,
      2 => Icons.shopping_basket_outlined,
      3 => Icons.payments_outlined,
      5 => Icons.menu_book_outlined,
      6 => Icons.track_changes_outlined,
      7 => Icons.format_quote_rounded,
      8 => Icons.receipt_long_outlined,
      9 => Icons.account_balance_wallet_outlined,
      10 => Icons.perm_media_outlined,
      11 => Icons.medication_outlined,
      12 => Icons.document_scanner_outlined,
      13 => Icons.school_outlined,
      _ => Icons.widgets_outlined,
    };
  }
}

class _DesktopSidebarSectionLabel extends StatelessWidget {
  const _DesktopSidebarSectionLabel({
    required this.label,
    required this.expanded,
  });

  final String label;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (!expanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Divider(
          height: 1,
          color: scheme.outlineVariant.withOpacity(.72),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 12, bottom: 7, top: 2),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _DesktopBrand extends StatelessWidget {
  const _DesktopBrand({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: expanded
          ? MainAxisAlignment.start
          : MainAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            Icons.space_dashboard_rounded,
            color: scheme.onPrimary,
            size: 23,
          ),
        ),
        if (expanded) ...[
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DayArk',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.2,
                  ),
                ),
                Text(
                  'Personal workspace',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DesktopNavItem extends StatelessWidget {
  const _DesktopNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? scheme.primary : scheme.onSurfaceVariant;
    final background = selected
        ? scheme.primaryContainer.withOpacity(.62)
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Tooltip(
        message: expanded ? '' : label,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: SizedBox(
              height: 46,
              child: Row(
                mainAxisAlignment: expanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: expanded ? 46 : 44,
                    child: Icon(
                      selected ? selectedIcon : icon,
                      size: 21,
                      color: foreground,
                    ),
                  ),
                  if (expanded)
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: foreground,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({
    required this.selectedIndex,
    required this.activeRoute,
    required this.onQuickAdd,
    required this.onSettings,
  });

  final int selectedIndex;
  final String? activeRoute;
  final VoidCallback onQuickAdd;
  final VoidCallback onSettings;

  String _desktopPageTitle(String? route, int branchIndex) {
    return switch (route) {
      RoutesStr.meterList => 'Meters',
      RoutesStr.grocery => 'Grocery',
      RoutesStr.expense => 'Expenses',
      RoutesStr.moodTracker => 'Personal Diary',
      RoutesStr.habits => 'Habits',
      RoutesStr.quotes => 'Quotations',
      RoutesStr.invoices => 'Invoices',
      '${RoutesStr.invoices}/new' => 'Invoices',
      RoutesStr.loans => 'Digital Khata & Loans',
      RoutesStr.multimedia => 'Media Studio',
      RoutesStr.pillReminder => 'Pill Reminder',
      RoutesStr.scannerGallery => 'Document Scanner',
      RoutesStr.tutorials => 'Tutorials',
      RoutesStr.familyTrees => 'Life Archives',
      RoutesStr.deviceSync => 'Local Device Sync',
      RoutesStr.primaryLocalBackups => 'Primary Local Backups',
      RoutesStr.backupCompatibility => 'Legacy Backup & Compatibility',
      RoutesStr.backup => 'Backup & Restore',
      RoutesStr.dataBaseViewer => 'Database Inspector',
      RoutesStr.homeSetting => 'Dashboard Settings',
      RoutesStr.settings => 'Settings',
      _ => branchIndex == 0 ? 'Dashboard' : 'Workspace',
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = _desktopPageTitle(activeRoute, selectedIndex);
    final subtitle = activeRoute == null
        ? 'Overview of your workspace and direct access to every feature'
        : 'Opened inside your desktop workspace';

    return SizedBox(
      height: 74,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: context.l10n.tr('settings'),
              onPressed: onSettings,
              icon: const Icon(Icons.settings_outlined, size: 20),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: onQuickAdd,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(context.l10n.tr('quickAdd')),
            ),
          ],
        ),
      ),
    );
  }
}

