import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../navigation/widgets/desktop_navigation_scope.dart';
import 'khata_account_form_sheet.dart';
import 'loan_controller.dart';
import 'loan_dashboard.dart';

/// Desktop-only Digital Khata workspace.
///
/// The module owns a second-level sidebar and a nested [Navigator]. Because all
/// Khata pages, dialogs and bottom sheets are launched from this navigator,
/// they stay inside the module's right content pane instead of replacing the
/// desktop admin shell.
class DigitalKhataDesktopDashboard extends ConsumerStatefulWidget {
  const DigitalKhataDesktopDashboard({super.key});

  @override
  ConsumerState<DigitalKhataDesktopDashboard> createState() =>
      _DigitalKhataDesktopDashboardState();
}

enum _KhataDesktopView {
  overview,
  allAccounts,
  receivables,
  payables,
  overdue,
  settled,
}

class _DigitalKhataDesktopDashboardState
    extends ConsumerState<DigitalKhataDesktopDashboard> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey _dashboardContentKey = GlobalKey();
  _KhataDesktopView _selectedView = _KhataDesktopView.overview;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _selectView(_KhataDesktopView.overview);
    });
  }

  void _returnToDashboardRoot() {
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  void _selectView(_KhataDesktopView view) {
    _returnToDashboardRoot();

    ref.read(loanSearchProvider.notifier).state = '';
    ref.read(loanSortProvider.notifier).state = 'smart';

    switch (view) {
      case _KhataDesktopView.overview:
        ref.read(loanFilterProvider.notifier).state = 2;
        ref.read(loanStatusFilterProvider.notifier).state = 'active';
        break;
      case _KhataDesktopView.allAccounts:
        ref.read(loanFilterProvider.notifier).state = 2;
        ref.read(loanStatusFilterProvider.notifier).state = 'all';
        break;
      case _KhataDesktopView.receivables:
        ref.read(loanFilterProvider.notifier).state = 0;
        ref.read(loanStatusFilterProvider.notifier).state = 'active';
        break;
      case _KhataDesktopView.payables:
        ref.read(loanFilterProvider.notifier).state = 1;
        ref.read(loanStatusFilterProvider.notifier).state = 'active';
        break;
      case _KhataDesktopView.overdue:
        ref.read(loanFilterProvider.notifier).state = 2;
        ref.read(loanStatusFilterProvider.notifier).state = 'overdue';
        break;
      case _KhataDesktopView.settled:
        ref.read(loanFilterProvider.notifier).state = 2;
        ref.read(loanStatusFilterProvider.notifier).state = 'settled';
        break;
    }

    if (_selectedView != view) {
      setState(() => _selectedView = view);
    }
  }

  Future<void> _addKhata() async {
    _returnToDashboardRoot();

    final navigatorContext = _dashboardContentKey.currentContext;
    if (navigatorContext == null) return;

    final account = await showKhataAccountForm(navigatorContext);
    if (account == null || !mounted) return;

    try {
      final id = await ref.read(loanServiceProvider).addLoan(account);
      refreshKhata(ref, loanId: id);
      if (!mounted) return;

      final messageContext = _dashboardContentKey.currentContext;
      if (messageContext != null) {
        ScaffoldMessenger.of(messageContext).showSnackBar(
          SnackBar(
            content: Text('${account.entityName} added to Digital Khata.'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      final messageContext = _dashboardContentKey.currentContext;
      if (messageContext != null) {
        ScaffoldMessenger.of(messageContext).showSnackBar(
          SnackBar(content: Text('Unable to create khata: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: scheme.surface,
      child: Row(
        children: [
          _KhataModuleSidebar(
            selectedView: _selectedView,
            onSelectView: _selectView,
            onAddKhata: _addKhata,
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
              child: Navigator(
                key: _navigatorKey,
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  settings: const RouteSettings(
                    name: '/digital-khata-desktop-root',
                  ),
                  builder: (_) => KeyedSubtree(
                    key: _dashboardContentKey,
                    child: const LoanDashboard(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KhataModuleSidebar extends StatelessWidget {
  const _KhataModuleSidebar({
    required this.selectedView,
    required this.onSelectView,
    required this.onAddKhata,
    required this.onBackToDashboard,
  });

  final _KhataDesktopView selectedView;
  final ValueChanged<_KhataDesktopView> onSelectView;
  final VoidCallback onAddKhata;
  final VoidCallback onBackToDashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      width: 244,
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
                      color: AppColors.loan.withOpacity(.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: AppColors.loan,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Digital Khata',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Ledger workspace',
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
                onPressed: onAddKhata,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.loan,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
                label: const Text('New Khata'),
              ),
              const SizedBox(height: 20),
              const _KhataSidebarLabel(text: 'WORKSPACE'),
              const SizedBox(height: 6),
              _KhataSidebarItem(
                icon: Icons.dashboard_outlined,
                selectedIcon: Icons.dashboard_rounded,
                label: 'Overview',
                selected: selectedView == _KhataDesktopView.overview,
                onTap: () => onSelectView(_KhataDesktopView.overview),
              ),
              _KhataSidebarItem(
                icon: Icons.people_alt_outlined,
                selectedIcon: Icons.people_alt_rounded,
                label: 'All accounts',
                selected: selectedView == _KhataDesktopView.allAccounts,
                onTap: () => onSelectView(_KhataDesktopView.allAccounts),
              ),
              const SizedBox(height: 12),
              const _KhataSidebarLabel(text: 'BALANCES'),
              const SizedBox(height: 6),
              _KhataSidebarItem(
                icon: Icons.south_west_rounded,
                selectedIcon: Icons.call_received_rounded,
                label: 'To receive',
                selected: selectedView == _KhataDesktopView.receivables,
                onTap: () => onSelectView(_KhataDesktopView.receivables),
              ),
              _KhataSidebarItem(
                icon: Icons.north_east_rounded,
                selectedIcon: Icons.call_made_rounded,
                label: 'To pay',
                selected: selectedView == _KhataDesktopView.payables,
                onTap: () => onSelectView(_KhataDesktopView.payables),
              ),
              _KhataSidebarItem(
                icon: Icons.warning_amber_rounded,
                selectedIcon: Icons.warning_rounded,
                label: 'Overdue',
                selected: selectedView == _KhataDesktopView.overdue,
                onTap: () => onSelectView(_KhataDesktopView.overdue),
              ),
              _KhataSidebarItem(
                icon: Icons.verified_outlined,
                selectedIcon: Icons.verified_rounded,
                label: 'Settled',
                selected: selectedView == _KhataDesktopView.settled,
                onTap: () => onSelectView(_KhataDesktopView.settled),
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

class _KhataSidebarLabel extends StatelessWidget {
  const _KhataSidebarLabel({required this.text});

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
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _KhataSidebarItem extends StatelessWidget {
  const _KhataSidebarItem({
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
    final foreground = selected ? AppColors.loan : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: selected ? AppColors.loan.withOpacity(.10) : Colors.transparent,
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
                  Icon(
                    Icons.chevron_right_rounded,
                    color: foreground,
                    size: 19,
                  ),
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
