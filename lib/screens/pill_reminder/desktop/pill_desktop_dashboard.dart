import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../navigation/widgets/desktop_navigation_scope.dart';
import '../pill_form/view/pill_form_screen.dart';
import '../pill_home/provider/pill_home_provider.dart';
import '../pill_home/view/pill_home_screen.dart';
import '../pill_list/provider/pill_list_provider.dart';
import '../pill_list/view/pill_inventory_refill_screen.dart';
import '../pill_list/view/pill_list_screen.dart';
import '../pill_settings/view/pill_settings_screen.dart';
import '../profile/view/profile_screen.dart';
import '../shared/pill_desktop_navigation.dart';

/// Desktop-only Pill Reminder workspace.
///
/// It behaves like an admin panel: the module has its own sidebar and every
/// Pill Reminder screen is rendered in the content pane on the right.
class PillDesktopDashboard extends ConsumerStatefulWidget {
  const PillDesktopDashboard({super.key});

  @override
  ConsumerState<PillDesktopDashboard> createState() =>
      _PillDesktopDashboardState();
}

enum _PillDesktopPage {
  overview,
  medicines,
  profiles,
  settings,
  medicineForm,
  refill,
}

class _PillDesktopDashboardState extends ConsumerState<PillDesktopDashboard> {
  _PillDesktopPage _page = _PillDesktopPage.overview;
  _PillDesktopPage _returnPage = _PillDesktopPage.medicines;
  Map<String, dynamic>? _editingPill;
  int? _refillPillId;
  String? _refillPillName;

  bool get _showMedicinesSelected =>
      _page == _PillDesktopPage.medicines ||
      _page == _PillDesktopPage.medicineForm ||
      _page == _PillDesktopPage.refill;

  void _openPrimary(_PillDesktopPage page) {
    if (_page == page) return;
    setState(() {
      _page = page;
      _editingPill = null;
      _refillPillId = null;
      _refillPillName = null;
    });
  }

  void _openMedicineForm(Map<String, dynamic>? pill) {
    final current = _page;
    setState(() {
      _returnPage = switch (current) {
        _PillDesktopPage.overview => _PillDesktopPage.overview,
        _PillDesktopPage.medicines => _PillDesktopPage.medicines,
        _ => _PillDesktopPage.medicines,
      };
      _editingPill = pill;
      _page = _PillDesktopPage.medicineForm;
    });
  }

  void _openRefill(int pillId, String pillName) {
    setState(() {
      _returnPage = _PillDesktopPage.medicines;
      _refillPillId = pillId;
      _refillPillName = pillName;
      _page = _PillDesktopPage.refill;
    });
  }

  void _closeDetail() {
    // Refresh both surfaces because medicine changes affect inventory and the
    // home schedule/summary cards.
    ref.invalidate(pillListControllerProvider);
    ref.invalidate(pillHomeControllerProvider);
    setState(() {
      _page = _returnPage;
      _editingPill = null;
      _refillPillId = null;
      _refillPillName = null;
    });
  }

  Widget _buildPage() {
    return switch (_page) {
      _PillDesktopPage.overview => const PillHomeScreen(
          key: ValueKey('pill-desktop-overview'),
        ),
      _PillDesktopPage.medicines => const PillListScreen(
          key: ValueKey('pill-desktop-medicines'),
        ),
      _PillDesktopPage.profiles => const PillProfileScreen(
          key: ValueKey('pill-desktop-profiles'),
        ),
      _PillDesktopPage.settings => const PillSettingsScreen(
          key: ValueKey('pill-desktop-settings'),
        ),
      _PillDesktopPage.medicineForm => PillFormScreen(
          key: ValueKey(
            'pill-desktop-form-${_editingPill?['id'] ?? 'new'}',
          ),
          pill: _editingPill,
        ),
      _PillDesktopPage.refill => PillInventoryRefillScreen(
          key: ValueKey('pill-desktop-refill-$_refillPillId'),
          pillId: _refillPillId!,
          pillName: _refillPillName!,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PillDesktopNavigationScope(
      onOpenOverview: () => _openPrimary(_PillDesktopPage.overview),
      onOpenMedicines: () => _openPrimary(_PillDesktopPage.medicines),
      onOpenProfiles: () => _openPrimary(_PillDesktopPage.profiles),
      onOpenSettings: () => _openPrimary(_PillDesktopPage.settings),
      onOpenMedicineForm: _openMedicineForm,
      onOpenRefill: _openRefill,
      onCloseDetail: _closeDetail,
      child: ColoredBox(
        color: scheme.surface,
        child: Row(
          children: [
            _PillModuleSidebar(
              selectedOverview: _page == _PillDesktopPage.overview,
              selectedMedicines: _showMedicinesSelected,
              selectedProfiles: _page == _PillDesktopPage.profiles,
              selectedSettings: _page == _PillDesktopPage.settings,
              onOverview: () => _openPrimary(_PillDesktopPage.overview),
              onMedicines: () => _openPrimary(_PillDesktopPage.medicines),
              onProfiles: () => _openPrimary(_PillDesktopPage.profiles),
              onSettings: () => _openPrimary(_PillDesktopPage.settings),
              onAddMedicine: () => _openMedicineForm(null),
              onBackToDashboard: () {
                DesktopNavigationScope.maybeOf(context)?.onDashboard();
              },
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: scheme.outlineVariant.withOpacity(.72),
            ),
            Expanded(
              child: ClipRect(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _buildPage(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillModuleSidebar extends StatelessWidget {
  const _PillModuleSidebar({
    required this.selectedOverview,
    required this.selectedMedicines,
    required this.selectedProfiles,
    required this.selectedSettings,
    required this.onOverview,
    required this.onMedicines,
    required this.onProfiles,
    required this.onSettings,
    required this.onAddMedicine,
    required this.onBackToDashboard,
  });

  final bool selectedOverview;
  final bool selectedMedicines;
  final bool selectedProfiles;
  final bool selectedSettings;
  final VoidCallback onOverview;
  final VoidCallback onMedicines;
  final VoidCallback onProfiles;
  final VoidCallback onSettings;
  final VoidCallback onAddMedicine;
  final VoidCallback onBackToDashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      width: 238,
      child: ColoredBox(
        color: scheme.surfaceContainerLowest,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.medication_rounded,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pill Reminder',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Medicine workspace',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAddMedicine,
                icon: const Icon(Icons.add_rounded, size: 19),
                label: const Text('Add medicine'),
              ),
              const SizedBox(height: 20),
              _SidebarLabel(text: 'MANAGE'),
              const SizedBox(height: 6),
              _PillSidebarItem(
                icon: Icons.dashboard_outlined,
                selectedIcon: Icons.dashboard_rounded,
                label: 'Overview',
                selected: selectedOverview,
                onTap: onOverview,
              ),
              _PillSidebarItem(
                icon: Icons.medication_outlined,
                selectedIcon: Icons.medication_rounded,
                label: 'My medicines',
                selected: selectedMedicines,
                onTap: onMedicines,
              ),
              _PillSidebarItem(
                icon: Icons.people_outline_rounded,
                selectedIcon: Icons.people_rounded,
                label: 'Profiles',
                selected: selectedProfiles,
                onTap: onProfiles,
              ),
              _PillSidebarItem(
                icon: Icons.tune_outlined,
                selectedIcon: Icons.tune_rounded,
                label: 'Pill settings',
                selected: selectedSettings,
                onTap: onSettings,
              ),
              const Spacer(),
              Divider(color: scheme.outlineVariant.withOpacity(.7)),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: onBackToDashboard,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back to dashboard'),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  foregroundColor: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarLabel extends StatelessWidget {
  const _SidebarLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _PillSidebarItem extends StatelessWidget {
  const _PillSidebarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? scheme.primary : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: selected
            ? scheme.primaryContainer.withOpacity(.62)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 46,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(
                  selected ? selectedIcon : icon,
                  size: 20,
                  color: foreground,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (selected) ...[
                  Icon(Icons.chevron_right_rounded, color: foreground, size: 19),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
