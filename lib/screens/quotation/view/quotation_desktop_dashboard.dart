import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common/centered_fa_icon.dart';
import '../../navigation/widgets/desktop_navigation_scope.dart';
import '../controller/quotation_controller.dart';
import 'OnlineQuotationLibrarySheet.dart';
import 'QuotationManagementSheet.dart';
import 'QuotesScreen.dart';

/// Desktop-only quotation workspace.
///
/// The module owns a second-level sidebar and a nested Navigator. This keeps
/// quotation screens, editors and module dialogs inside the right content pane
/// of the desktop admin shell instead of replacing the full application UI.
class QuotationDesktopDashboard extends ConsumerStatefulWidget {
  const QuotationDesktopDashboard({
    super.key,
    this.openCreateOnStart = false,
  });

  final bool openCreateOnStart;

  @override
  ConsumerState<QuotationDesktopDashboard> createState() =>
      _QuotationDesktopDashboardState();
}

enum _QuotationDesktopSection {
  library,
  favorites,
  downloaded,
  onlineLibrary,
  promptBuilder,
  manage,
}

class _QuotationDesktopDashboardState
    extends ConsumerState<QuotationDesktopDashboard> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<QuotesScreenState> _quotesKey = GlobalKey<QuotesScreenState>();

  _QuotationDesktopSection _section = _QuotationDesktopSection.library;
  int _navigationToken = 0;

  @override
  void initState() {
    super.initState();
    if (widget.openCreateOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openCreate());
    }
  }

  void _returnToRoot() {
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  Future<void> _selectFilteredLibrary(
    _QuotationDesktopSection section, {
    required bool favoritesOnly,
    required bool onlineOnly,
  }) async {
    _navigationToken++;
    _returnToRoot();
    setState(() => _section = section);

    final controller = ref.read(quotationControllerProvider.notifier);
    final state = ref.read(quotationControllerProvider);
    if (state.category != 'All') await controller.setCategory('All');
    if (state.favoritesOnly != favoritesOnly) {
      await controller.setFavoritesOnly(favoritesOnly);
    }
    if (state.onlineOnly != onlineOnly) {
      await controller.setOnlineOnly(onlineOnly);
    }
  }

  void _openOnlineLibrary() {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    final token = ++_navigationToken;
    setState(() => _section = _QuotationDesktopSection.onlineLibrary);

    // Replace any open quotation tool/page in one Navigator operation. This is
    // safer than popping a prompt/editor route and pushing another route in the
    // same callback while the old route is still tearing down.
    navigator
        .pushAndRemoveUntil<void>(
          MaterialPageRoute<void>(
            settings: const RouteSettings(
              name: '/quotations-desktop/online-library',
            ),
            builder: (_) => const OnlineQuotationLibrarySheet(embedded: true),
          ),
          (route) => route.isFirst,
        )
        .then((_) {
      if (!mounted || token != _navigationToken) return;
      setState(() => _section = _librarySectionFromState());
    });
  }

  _QuotationDesktopSection _librarySectionFromState() {
    final state = ref.read(quotationControllerProvider);
    if (state.onlineOnly) return _QuotationDesktopSection.downloaded;
    if (state.favoritesOnly) return _QuotationDesktopSection.favorites;
    return _QuotationDesktopSection.library;
  }

  void _openManagement() {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    final token = ++_navigationToken;
    setState(() => _section = _QuotationDesktopSection.manage);
    final category = ref.read(quotationControllerProvider).category;
    final surfaceColor = Theme.of(context).colorScheme.surface;

    navigator
        .pushAndRemoveUntil<void>(
          MaterialPageRoute<void>(
            settings: const RouteSettings(
              name: '/quotations-desktop/manage',
            ),
            builder: (_) => ColoredBox(
              color: surfaceColor,
              child: QuotationManagementSheet(
                currentCategory: category,
                embedded: true,
              ),
            ),
          ),
          (route) => route.isFirst,
        )
        .then((_) {
      if (!mounted || token != _navigationToken) return;
      setState(() => _section = _librarySectionFromState());
    });
  }

  void _openCreate() {
    _navigationToken++;
    _returnToRoot();
    setState(() => _section = _QuotationDesktopSection.library);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _quotesKey.currentState?.openCreateForm();
    });
  }

  void _openPromptBuilder() {
    final token = ++_navigationToken;
    _returnToRoot();
    setState(() => _section = _QuotationDesktopSection.promptBuilder);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || token != _navigationToken) return;
      final future = _quotesKey.currentState?.openPromptBuilder();
      future?.then((_) {
        if (!mounted || token != _navigationToken) return;
        setState(() => _section = _librarySectionFromState());
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quotationControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final showingTool = _section == _QuotationDesktopSection.onlineLibrary ||
        _section == _QuotationDesktopSection.promptBuilder ||
        _section == _QuotationDesktopSection.manage;
    final effectiveSection = showingTool
        ? _section
        : state.onlineOnly
            ? _QuotationDesktopSection.downloaded
            : state.favoritesOnly
                ? _QuotationDesktopSection.favorites
                : _QuotationDesktopSection.library;

    return ColoredBox(
      color: scheme.surface,
      child: Row(
        children: [
          _QuotationModuleSidebar(
            state: state,
            section: effectiveSection,
            onLibrary: () => _selectFilteredLibrary(
              _QuotationDesktopSection.library,
              favoritesOnly: false,
              onlineOnly: false,
            ),
            onFavorites: () => _selectFilteredLibrary(
              _QuotationDesktopSection.favorites,
              favoritesOnly: true,
              onlineOnly: false,
            ),
            onDownloaded: () => _selectFilteredLibrary(
              _QuotationDesktopSection.downloaded,
              favoritesOnly: false,
              onlineOnly: true,
            ),
            onOnlineLibrary: _openOnlineLibrary,
            onManage: _openManagement,
            onCreate: _openCreate,
            onPrompt: _openPromptBuilder,
            onBackToDashboard: () {
              final desktopScope = DesktopNavigationScope.maybeOf(context);
              if (desktopScope != null) {
                desktopScope.onDashboard();
              } else if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/');
              }
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
                    name: '/quotations-desktop/library',
                  ),
                  builder: (_) => QuotesScreen(
                    key: _quotesKey,
                    desktopEmbedded: true,
                    onOpenOnlineLibrary: _openOnlineLibrary,
                    onOpenManagement: _openManagement,
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

class _QuotationModuleSidebar extends StatelessWidget {
  const _QuotationModuleSidebar({
    required this.state,
    required this.section,
    required this.onLibrary,
    required this.onFavorites,
    required this.onDownloaded,
    required this.onOnlineLibrary,
    required this.onManage,
    required this.onCreate,
    required this.onPrompt,
    required this.onBackToDashboard,
  });

  final QuotationState state;
  final _QuotationDesktopSection section;
  final VoidCallback onLibrary;
  final VoidCallback onFavorites;
  final VoidCallback onDownloaded;
  final VoidCallback onOnlineLibrary;
  final VoidCallback onManage;
  final VoidCallback onCreate;
  final VoidCallback onPrompt;
  final VoidCallback onBackToDashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      width: 252,
      child: ColoredBox(
        color: scheme.surfaceContainerLowest,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.habit.withOpacity(.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const CenteredFaIcon(
                      FontAwesomeIcons.quoteLeft,
                      color: AppColors.habit,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quotations',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${state.quotations.length} visible quotes',
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
                onPressed: onCreate,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.habit,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                ),
                icon: const CenteredFaIcon(FontAwesomeIcons.plus, size: 15),
                label: const Text('New quotation'),
              ),
              const SizedBox(height: 18),
              const _SidebarLabel(text: 'LIBRARY'),
              const SizedBox(height: 5),
              _SidebarItem(
                icon: FontAwesomeIcons.tableCellsLarge,
                label: 'All quotations',
                selected: section == _QuotationDesktopSection.library,
                onTap: onLibrary,
              ),
              _SidebarItem(
                icon: FontAwesomeIcons.heart,
                label: 'Favorites',
                selected: section == _QuotationDesktopSection.favorites,
                onTap: onFavorites,
              ),
              _SidebarItem(
                icon: FontAwesomeIcons.cloudArrowDown,
                label: 'Downloaded',
                selected: section == _QuotationDesktopSection.downloaded,
                onTap: onDownloaded,
              ),
              const SizedBox(height: 14),
              const _SidebarLabel(text: 'TOOLS'),
              const SizedBox(height: 5),
              _SidebarItem(
                icon: FontAwesomeIcons.globe,
                label: 'Online library',
                selected: section == _QuotationDesktopSection.onlineLibrary,
                onTap: onOnlineLibrary,
              ),
              _SidebarItem(
                icon: FontAwesomeIcons.wandMagicSparkles,
                label: 'Prompt builder',
                selected: section == _QuotationDesktopSection.promptBuilder,
                onTap: onPrompt,
              ),
              _SidebarItem(
                icon: FontAwesomeIcons.sliders,
                label: 'Manage library',
                selected: section == _QuotationDesktopSection.manage,
                onTap: onManage,
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
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final FaIconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? AppColors.habit : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: selected
            ? AppColors.habit.withOpacity(.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                CenteredFaIcon(icon, size: 15, color: foreground),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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
}
