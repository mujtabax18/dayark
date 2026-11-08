part of '../main_navigation_shell.dart';

class _AppNavigationRail extends StatelessWidget {
  const _AppNavigationRail({
    required this.selectedIndex,
    required this.extended,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final bool extended;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return NavigationRail(
      selectedIndex: selectedIndex,
      extended: extended,
      minWidth: 76,
      minExtendedWidth: 224,
      groupAlignment: -.72,
      labelType: extended
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      useIndicator: true,
      indicatorColor: scheme.primaryContainer,
      backgroundColor: scheme.surface,
      selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
      selectedLabelTextStyle: Theme.of(context).textTheme.labelMedium
          ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800),
      unselectedLabelTextStyle: Theme.of(context).textTheme.labelMedium
          ?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
      onDestinationSelected: onDestinationSelected,
      destinations: [
        NavigationRailDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home_rounded),
          label: Text(context.l10n.tr('home')),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: const Icon(Icons.account_balance_wallet_rounded),
          label: Text(context.l10n.tr('finance')),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.event_note_outlined),
          selectedIcon: const Icon(Icons.event_note_rounded),
          label: Text(context.l10n.tr('planner')),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.grid_view_outlined),
          selectedIcon: const Icon(Icons.grid_view_rounded),
          label: Text(context.l10n.tr('more')),
        ),
      ],
    );
  }
}

class _HiddenNavigationHomeActions extends StatelessWidget {
  const _HiddenNavigationHomeActions({
    required this.onSettingsPressed,
    required this.onAddPressed,
  });

  final VoidCallback onSettingsPressed;
  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.small(
          heroTag: 'home_settings_when_navigation_hidden',
          tooltip: context.l10n.tr('settings'),
          elevation: 3,
          highlightElevation: 4,
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          onPressed: onSettingsPressed,
          child: const Icon(Icons.settings_outlined),
        ),
        const SizedBox(width: AppSpacing.sm),
        FloatingActionButton(
          heroTag: 'home_quick_add_when_navigation_hidden',
          tooltip: context.l10n.tr('quickAdd'),
          elevation: 3,
          highlightElevation: 4,
          onPressed: onAddPressed,
          child: const Icon(Icons.add_rounded, size: 30),
        ),
      ],
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;

    return InkResponse(
      onTap: onTap,
      radius: 32,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: 38,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? scheme.primaryContainer.withOpacity(.70)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                selected ? selectedIcon : icon,
                size: 21,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
