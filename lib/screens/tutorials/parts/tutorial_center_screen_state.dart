part of '../tutorial_center_screen.dart';

class _TutorialCenterScreenState extends State<TutorialCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _selectedGuideTitle;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final allGuides = _guides(language);
    final guides = _filteredGuides(allGuides);
    final isDesktop = MediaQuery.sizeOf(context).width >= 1100;

    if (isDesktop) {
      return _buildDesktop(context, language, guides);
    }
    return _buildMobile(context, language, guides);
  }

  List<_TutorialGuide> _filteredGuides(List<_TutorialGuide> guides) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return guides;
    return guides
        .where(
          (guide) =>
              guide.title.toLowerCase().contains(query) ||
              guide.description.toLowerCase().contains(query) ||
              guide.steps.any((step) => step.toLowerCase().contains(query)),
        )
        .toList(growable: false);
  }

  String _searchHint(String language) {
    return language == 'ur'
        ? 'رہنمائی تلاش کریں'
        : language == 'ar'
            ? 'ابحث في الشروحات'
            : 'Search tutorials';
  }

  void _updateQuery(String value) {
    setState(() => _query = value);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  Widget _buildMobile(
    BuildContext context,
    String language,
    List<_TutorialGuide> guides,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.tr('tutorialCenter')),
      ),
      body: DesktopContentFrame(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.tr('gettingStarted'),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        context.l10n.tr('tutorialSubtitle'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _searchController,
                        onChanged: _updateQuery,
                        decoration: InputDecoration(
                          hintText: _searchHint(language),
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: _clearSearch,
                                  icon: const Icon(Icons.clear_rounded),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (guides.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _TutorialEmptyState(onClearSearch: _clearSearch),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.xxl,
                  ),
                  sliver: SliverList.separated(
                    itemCount: guides.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      return _TutorialCard(guide: guides[index]);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktop(
    BuildContext context,
    String language,
    List<_TutorialGuide> guides,
  ) {
    final scheme = Theme.of(context).colorScheme;
    _TutorialGuide? selectedGuide;
    if (guides.isNotEmpty) {
      selectedGuide = guides.firstWhere(
        (guide) => guide.title == _selectedGuideTitle,
        orElse: () => guides.first,
      );
    }

    return ColoredBox(
      color: scheme.surface,
      child: Row(
        children: [
          _TutorialDesktopSidebar(
            language: language,
            guides: guides,
            selectedGuide: selectedGuide,
            searchController: _searchController,
            query: _query,
            onQueryChanged: _updateQuery,
            onClearSearch: _clearSearch,
            onGuideSelected: (guide) {
              setState(() => _selectedGuideTitle = guide.title);
            },
            onBackToDashboard: () {
              final desktopScope = DesktopNavigationScope.maybeOf(context);
              if (desktopScope != null) {
                desktopScope.onDashboard();
              } else {
                context.go(RoutesStr.home);
              }
            },
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: scheme.outlineVariant.withOpacity(.72),
          ),
          Expanded(
            child: selectedGuide == null
                ? _TutorialEmptyState(onClearSearch: _clearSearch)
                : _TutorialDesktopDetail(guide: selectedGuide),
          ),
        ],
      ),
    );
  }
}

class _TutorialDesktopSidebar extends StatelessWidget {
  const _TutorialDesktopSidebar({
    required this.language,
    required this.guides,
    required this.selectedGuide,
    required this.searchController,
    required this.query,
    required this.onQueryChanged,
    required this.onClearSearch,
    required this.onGuideSelected,
    required this.onBackToDashboard,
  });

  final String language;
  final List<_TutorialGuide> guides;
  final _TutorialGuide? selectedGuide;
  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<_TutorialGuide> onGuideSelected;
  final VoidCallback onBackToDashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final searchHint = language == 'ur'
        ? 'رہنمائی تلاش کریں'
        : language == 'ar'
            ? 'ابحث في الشروحات'
            : 'Search tutorials';

    return SizedBox(
      width: 292,
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
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.school_rounded,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.tr('tutorialCenter'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          context.l10n.tr('gettingStarted'),
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
              TextField(
                controller: searchController,
                onChanged: onQueryChanged,
                decoration: InputDecoration(
                  hintText: searchHint,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: onClearSearch,
                          icon: const Icon(Icons.clear_rounded, size: 19),
                        ),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'GUIDES',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .9,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: guides.isEmpty
                    ? Center(
                        child: Text(
                          'No matching tutorials',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: guides.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final guide = guides[index];
                          final selected = guide.title == selectedGuide?.title;
                          return _TutorialSidebarItem(
                            guide: guide,
                            selected: selected,
                            onTap: () => onGuideSelected(guide),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onBackToDashboard,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialSidebarItem extends StatelessWidget {
  const _TutorialSidebarItem({
    required this.guide,
    required this.selected,
    required this.onTap,
  });

  final _TutorialGuide guide;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: selected ? scheme.primaryContainer.withOpacity(.72) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Icon(
                guide.icon,
                size: 20,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  guide.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? scheme.onPrimaryContainer : null,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 19,
                  color: scheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

