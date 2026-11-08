import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:metersystem/core/theme/theme_x.dart';
import 'package:metersystem/core/design/responsive_layout.dart';
import 'package:metersystem/models/moodTrackerModel.dart';
import 'package:metersystem/services/diary_lock_service.dart';
import '../controller/moodNotifier.dart';
import '../widget/DiaryEntrySheet.dart';
import '../widget/DiaryListItem.dart';
import '../widget/empty_diary.dart';
import 'diary_lock_screen.dart';
import '../../navigation/widgets/desktop_content_frame.dart';
part '../widget/personal_diary_widgets.dart';

class PersonalDiaryScreen extends ConsumerStatefulWidget {
  const PersonalDiaryScreen({super.key});

  @override
  ConsumerState<PersonalDiaryScreen> createState() =>
      _PersonalDiaryScreenState();
}

class _PersonalDiaryScreenState extends ConsumerState<PersonalDiaryScreen> {
  static const _datePageCenter = 10000;

  final _searchController = TextEditingController();
  final _tagSearchController = TextEditingController();
  final _lockService = DiaryLockService();
  late final PageController _dateController;

  DateTime _selectedDate = _dayOnly(DateTime.now());
  bool _showAllDates = true;
  bool _checkingLock = true;
  bool _unlocked = false;
  String _query = '';
  String _tagQuery = '';
  String? _desktopSelectedEntryKey;
  bool _desktopShowOverview = true;
  MoodEntry? _desktopFullEntry;
  MoodEntry? _desktopEditorEntry;
  bool _desktopCreatingEntry = false;
  bool _desktopSearchExpanded = false;
  bool _desktopTagSearchExpanded = false;
  bool _desktopFiltersExpanded = false;
  final Map<String, GlobalKey> _desktopPageKeys = <String, GlobalKey>{};
  String? _selectedTag;
  bool _favoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _dateController = PageController(
      initialPage: _datePageCenter,
      viewportFraction: .22,
    );
    _checkLock();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tagSearchController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _checkLock() async {
    final enabled = await _lockService.isEnabled();
    if (!mounted) return;
    setState(() {
      _checkingLock = false;
      _unlocked = !enabled;
    });
  }

  Future<void> _openEditor({MoodEntry? entry, DateTime? initialDate}) async {
    await Navigator.push<MoodEntry>(
      context,
      PageRouteBuilder(
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 360),
        pageBuilder: (_, animation, secondaryAnimation) => DiaryEntrySheet(
          existingEntry: entry,
          initialDate: initialDate,
        ),
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, .08),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Future<void> _openLockSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DiaryLockSettingsSheet(
        onLockStateChanged: (enabled) {
          if (enabled && mounted) {
            setState(() => _unlocked = false);
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  List<MoodEntry> _filteredEntries(List<MoodEntry> entries) {
    final normalizedQuery = _query.trim().toLowerCase();
    return entries.where((entry) {
      if (!_showAllDates && !_sameDay(entry.entryDateTime, _selectedDate)) {
        return false;
      }
      if (_favoritesOnly && !entry.isFavorite) return false;
      if (_selectedTag != null &&
          !entry.tags.any(
            (tag) => tag.toLowerCase() == _selectedTag!.toLowerCase(),
          )) {
        return false;
      }
      if (normalizedQuery.isEmpty) return true;

      final searchable = [
        entry.title,
        entry.notes ?? '',
        entry.gratitude ?? '',
        entry.trigger ?? '',
        entry.moodEmoji,
        ...entry.tags,
      ].join(' ').toLowerCase();
      return searchable.contains(normalizedQuery);
    }).toList(growable: false);
  }

  List<String> _allTags(List<MoodEntry> entries) {
    final tags = <String>{};
    for (final entry in entries) {
      tags.addAll(entry.tags.where((tag) => tag.trim().isNotEmpty));
    }
    final result = tags.toList();
    result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  int _currentStreak(List<MoodEntry> entries) {
    final dates = entries
        .map((entry) => _dayOnly(entry.entryDateTime))
        .toSet();
    if (dates.isEmpty) return 0;

    var cursor = _dayOnly(DateTime.now());
    if (!dates.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!dates.contains(cursor)) return 0;
    }

    var streak = 0;
    while (dates.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;

    if (_checkingLock) {
      return Scaffold(
        backgroundColor: neutral.background,
        body: DesktopContentFrame(
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (!_unlocked) {
      return DiaryUnlockScreen(
        onUnlocked: () => setState(() => _unlocked = true),
      );
    }

    final entries = ref.watch(moodProvider);
    final filtered = _filteredEntries(entries);
    final tags = _allTags(entries);

    if (context.isDesktop) {
      return _buildDesktopDiary(context, entries, filtered, tags);
    }

    return Scaffold(
      backgroundColor: neutral.background,
      appBar: AppBar(
        backgroundColor: neutral.background,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personal Diary',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            Text(
              'Private moments, beautifully kept',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _favoritesOnly ? 'Show all pages' : 'Bookmarks only',
            onPressed: () => setState(() => _favoritesOnly = !_favoritesOnly),
            icon: Icon(
              _favoritesOnly
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Diary lock',
            onPressed: _openLockSettings,
            icon: const Icon(Icons.lock_outline_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(
          initialDate: _showAllDates ? DateTime.now() : _selectedDate,
        ),
        icon: const Icon(Icons.edit_rounded),
        label: const Text('New page'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(moodProvider.notifier).loadMoodHistory(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _DiaryCoverHeader(
                  entries: entries,
                  streak: _currentStreak(entries),
                  onWrite: () => _openEditor(initialDate: DateTime.now()),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Search memories, notes, and tags…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: neutral.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: neutral.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: neutral.divider),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: _DateNavigator(
                  controller: _dateController,
                  selectedDate: _selectedDate,
                  showAllDates: _showAllDates,
                  onShowAll: () => setState(() => _showAllDates = true),
                  onPageChanged: (index) {
                    setState(() {
                      _selectedDate = _dayOnly(
                        DateTime.now().add(
                          Duration(days: index - _datePageCenter),
                        ),
                      );
                      _showAllDates = false;
                    });
                  },
                ),
              ),
            ),
            if (tags.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 58,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    scrollDirection: Axis.horizontal,
                    itemCount: tags.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final tag = index == 0 ? null : tags[index - 1];
                      return FilterChip(
                        selected: _selectedTag == tag,
                        label: Text(tag == null ? 'All tags' : '#$tag'),
                        avatar: tag == null
                            ? const Icon(Icons.sell_outlined, size: 17)
                            : null,
                        onSelected: (_) => setState(() => _selectedTag = tag),
                      );
                    },
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(18, tags.isEmpty ? 18 : 8, 18, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _showAllDates
                            ? (_favoritesOnly ? 'Bookmarked pages' : 'All diary pages')
                            : DateFormat('EEEE, d MMMM').format(_selectedDate),
                        style: TextStyle(
                          color: neutral.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '${filtered.length} ${filtered.length == 1 ? 'entry' : 'entries'}',
                      style: TextStyle(
                        color: neutral.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyDiary(
                  filtered: entries.isNotEmpty,
                  onCreate: entries.isEmpty
                      ? () => _openEditor(initialDate: DateTime.now())
                      : null,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 92),
                sliver: SliverList.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(.04, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: DiaryListItem(
                        key: ValueKey(filtered[index].id),
                        entry: filtered[index],
                        entries: filtered,
                        index: index,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _desktopEntryKey(MoodEntry entry) =>
      entry.id?.toString() ?? '${entry.dateTime}|${entry.title}|${entry.createdAt ?? ''}';

  GlobalKey _desktopPageKey(MoodEntry entry) => _desktopPageKeys.putIfAbsent(
        _desktopEntryKey(entry),
        () => GlobalKey(),
      );

  void _showDesktopEntry(MoodEntry entry) {
    final entryKey = _desktopEntryKey(entry);
    setState(() {
      _desktopShowOverview = false;
      _desktopFullEntry = null;
      _desktopCreatingEntry = false;
      _desktopEditorEntry = null;
      _desktopSelectedEntryKey = entryKey;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = _desktopPageKey(entry).currentContext;
      if (targetContext == null) return;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOutCubic,
        alignment: .035,
      );
    });
  }

  void _openDesktopFullEntry(MoodEntry entry) {
    setState(() {
      _desktopShowOverview = false;
      _desktopFullEntry = entry;
      _desktopCreatingEntry = false;
      _desktopEditorEntry = null;
      _desktopSelectedEntryKey = _desktopEntryKey(entry);
    });
  }

  void _openDesktopEditor({MoodEntry? entry}) {
    setState(() {
      _desktopShowOverview = false;
      _desktopFullEntry = null;
      _desktopEditorEntry = entry;
      _desktopCreatingEntry = entry == null;
      if (entry != null) {
        _desktopSelectedEntryKey = _desktopEntryKey(entry);
      }
    });
  }

  void _closeDesktopEditor() {
    setState(() {
      _desktopCreatingEntry = false;
      _desktopEditorEntry = null;
      if (_desktopSelectedEntryKey == null) {
        _desktopShowOverview = true;
      }
    });
  }

  void _handleDesktopSaved(MoodEntry saved) {
    setState(() {
      _desktopCreatingEntry = false;
      _desktopEditorEntry = null;
      _desktopShowOverview = false;
      _desktopFullEntry = saved;
      _desktopSelectedEntryKey = _desktopEntryKey(saved);
    });
  }

  void _resetDesktopFilters() {
    _searchController.clear();
    _tagSearchController.clear();
    setState(() {
      _query = '';
      _tagQuery = '';
      _selectedTag = null;
      _favoritesOnly = false;
      _showAllDates = true;
    });
  }

  Widget _buildDesktopDiary(
    BuildContext context,
    List<MoodEntry> entries,
    List<MoodEntry> filtered,
    List<String> tags,
  ) {
    final neutral = context.themeColors.neutral;
    final scheme = Theme.of(context).colorScheme;
    final normalizedTagQuery = _tagQuery.trim().toLowerCase();
    final visibleTags = tags
        .where((tag) => tag.toLowerCase().contains(normalizedTagQuery))
        .toList(growable: false);

    final activeFilterCount = <bool>[
      _favoritesOnly,
      !_showAllDates,
      _selectedTag != null,
    ].where((value) => value).length;

    return Scaffold(
      backgroundColor: neutral.background,
      body: SafeArea(
        child: DesktopContentFrame(
          maxWidth: 1540,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 380,
                  child: Container(
                    decoration: BoxDecoration(
                      color: neutral.card,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: neutral.divider),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 12, 12),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.auto_stories_rounded,
                                  color: scheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Personal Diary',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      'Your private pages',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Diary lock',
                                onPressed: _openLockSettings,
                                icon: const Icon(Icons.lock_outline_rounded),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => _openDesktopEditor(),
                              icon: const Icon(Icons.edit_rounded, size: 18),
                              label: const Text('Write a new page'),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                          child: Material(
                            color: _desktopShowOverview
                                ? scheme.primary.withValues(alpha: .09)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: () => setState(() {
                                _desktopShowOverview = true;
                                _desktopSelectedEntryKey = null;
                                _desktopFullEntry = null;
                                _desktopEditorEntry = null;
                                _desktopCreatingEntry = false;
                              }),
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 11,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.dashboard_outlined,
                                      size: 20,
                                      color: _desktopShowOverview
                                          ? scheme.primary
                                          : neutral.textSecondary,
                                    ),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Text(
                                        'Overview',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => setState(() {
                                    _desktopSearchExpanded =
                                        !_desktopSearchExpanded;
                                  }),
                                  icon: Icon(
                                    _desktopSearchExpanded
                                        ? Icons.close_rounded
                                        : Icons.search_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Search'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => setState(() {
                                    _desktopTagSearchExpanded =
                                        !_desktopTagSearchExpanded;
                                  }),
                                  icon: Icon(
                                    _desktopTagSearchExpanded
                                        ? Icons.close_rounded
                                        : Icons.tag_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Tags'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: _desktopSearchExpanded
                              ? Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(14, 10, 14, 0),
                                  child: TextField(
                                    controller: _searchController,
                                    autofocus: true,
                                    onChanged: (value) =>
                                        setState(() => _query = value),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      prefixIcon:
                                          const Icon(Icons.search_rounded),
                                      hintText: 'Search diary pages…',
                                      suffixIcon: _query.isEmpty
                                          ? null
                                          : IconButton(
                                              tooltip: 'Clear search',
                                              onPressed: () {
                                                _searchController.clear();
                                                setState(() => _query = '');
                                              },
                                              icon: const Icon(
                                                Icons.close_rounded,
                                              ),
                                            ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: _desktopTagSearchExpanded
                              ? Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(14, 10, 14, 0),
                                  child: Column(
                                    children: [
                                      TextField(
                                        controller: _tagSearchController,
                                        autofocus: true,
                                        onChanged: (value) =>
                                            setState(() => _tagQuery = value),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          prefixIcon:
                                              const Icon(Icons.tag_rounded),
                                          hintText: 'Search tags…',
                                          suffixIcon: _tagQuery.isEmpty
                                              ? null
                                              : IconButton(
                                                  tooltip: 'Clear tag search',
                                                  onPressed: () {
                                                    _tagSearchController.clear();
                                                    setState(
                                                      () => _tagQuery = '',
                                                    );
                                                  },
                                                  icon: const Icon(
                                                    Icons.close_rounded,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      if (visibleTags.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxHeight: 104,
                                          ),
                                          child: SingleChildScrollView(
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children: visibleTags
                                                    .map(
                                                      (tag) => FilterChip(
                                                        label: Text('#$tag'),
                                                        selected:
                                                            _selectedTag == tag,
                                                        onSelected: (_) =>
                                                            setState(() {
                                                          _selectedTag =
                                                              _selectedTag == tag
                                                                  ? null
                                                                  : tag;
                                                        }),
                                                      ),
                                                    )
                                                    .toList(),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                          child: Material(
                            color: neutral.background,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: () => setState(() {
                                _desktopFiltersExpanded =
                                    !_desktopFiltersExpanded;
                              }),
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.tune_rounded, size: 19),
                                    const SizedBox(width: 9),
                                    const Expanded(
                                      child: Text(
                                        'Page filters',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    if (activeFilterCount > 0)
                                      Container(
                                        margin:
                                            const EdgeInsets.only(right: 7),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: scheme.primary,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          '$activeFilterCount',
                                          style: TextStyle(
                                            color: scheme.onPrimary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    AnimatedRotation(
                                      turns:
                                          _desktopFiltersExpanded ? .5 : 0,
                                      duration:
                                          const Duration(milliseconds: 220),
                                      child: const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: _desktopFiltersExpanded
                              ? Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(14, 8, 14, 2),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: neutral.background,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: neutral.divider),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 7,
                                          runSpacing: 7,
                                          children: [
                                            ChoiceChip(
                                              label: const Text('All pages'),
                                              selected: _showAllDates &&
                                                  !_favoritesOnly,
                                              onSelected: (_) => setState(() {
                                                _showAllDates = true;
                                                _favoritesOnly = false;
                                              }),
                                            ),
                                            ChoiceChip(
                                              avatar: const Icon(
                                                Icons.bookmark_outline_rounded,
                                                size: 16,
                                              ),
                                              label: const Text('Bookmarked'),
                                              selected: _favoritesOnly,
                                              onSelected: (_) => setState(() {
                                                _favoritesOnly =
                                                    !_favoritesOnly;
                                                if (_favoritesOnly) {
                                                  _showAllDates = true;
                                                }
                                              }),
                                            ),
                                            ChoiceChip(
                                              avatar: const Icon(
                                                Icons.today_rounded,
                                                size: 16,
                                              ),
                                              label: const Text('Today'),
                                              selected: !_showAllDates &&
                                                  _sameDay(
                                                    _selectedDate,
                                                    DateTime.now(),
                                                  ),
                                              onSelected: (_) => setState(() {
                                                _selectedDate =
                                                    _dayOnly(DateTime.now());
                                                _showAllDates = false;
                                                _favoritesOnly = false;
                                              }),
                                            ),
                                          ],
                                        ),
                                        if (_selectedTag != null) ...[
                                          const SizedBox(height: 8),
                                          InputChip(
                                            avatar: const Icon(
                                              Icons.tag_rounded,
                                              size: 16,
                                            ),
                                            label: Text('#$_selectedTag'),
                                            onDeleted: () => setState(
                                              () => _selectedTag = null,
                                            ),
                                          ),
                                        ],
                                        if (activeFilterCount > 0) ...[
                                          const SizedBox(height: 6),
                                          TextButton.icon(
                                            onPressed: _resetDesktopFilters,
                                            icon: const Icon(
                                              Icons.restart_alt_rounded,
                                              size: 17,
                                            ),
                                            label:
                                                const Text('Reset filters'),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        const Divider(height: 20),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 12, 8),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'PAGES',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ),
                              Text(
                                '${filtered.length}',
                                style: TextStyle(
                                  color: neutral.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: filtered.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      'No diary pages match these filters.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: neutral.textSecondary,
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding:
                                      const EdgeInsets.fromLTRB(10, 0, 10, 12),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final entry = filtered[index];
                                    final entryKey = _desktopEntryKey(entry);
                                    return _DesktopDiaryPageTile(
                                      entry: entry,
                                      selected: !_desktopShowOverview &&
                                          entryKey ==
                                              _desktopSelectedEntryKey,
                                      onTap: () => _showDesktopEntry(entry),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _desktopCreatingEntry || _desktopEditorEntry != null
                      ? DiaryEntrySheet(
                          key: ValueKey(
                            _desktopEditorEntry == null
                                ? 'desktop-new-diary'
                                : 'desktop-edit-${_desktopEntryKey(_desktopEditorEntry!)}',
                          ),
                          existingEntry: _desktopEditorEntry,
                          initialDate: _showAllDates ? DateTime.now() : _selectedDate,
                          embedded: true,
                          onClose: _closeDesktopEditor,
                          onSaved: _handleDesktopSaved,
                        )
                      : _desktopFullEntry != null
                          ? _DesktopDiaryFullPage(
                              entry: _desktopFullEntry!,
                              onBack: () => setState(() {
                                _desktopFullEntry = null;
                              }),
                              onEdit: () => _openDesktopEditor(
                                entry: _desktopFullEntry!,
                              ),
                            )
                          : _desktopShowOverview
                              ? _DesktopDiaryOverview(
                                  entries: entries,
                                  filteredEntries: filtered,
                                  tags: tags,
                                  streak: _currentStreak(entries),
                                  onWrite: () => _openDesktopEditor(),
                                  onOpenEntry: _showDesktopEntry,
                                )
                              : filtered.isEmpty
                                  ? _DesktopDiaryEmpty(
                                      onCreate: () => _openDesktopEditor(),
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        color: neutral.background,
                                        borderRadius: BorderRadius.circular(22),
                                      ),
                                      child: ListView.separated(
                                        padding: const EdgeInsets.fromLTRB(
                                          2,
                                          2,
                                          8,
                                          44,
                                        ),
                                        physics: const BouncingScrollPhysics(),
                                        itemCount: filtered.length,
                                        separatorBuilder: (_, __) => Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Divider(
                                                  color: neutral.divider,
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                ),
                                                child: Icon(
                                                  Icons.auto_stories_outlined,
                                                  size: 18,
                                                  color: neutral.textSecondary,
                                                ),
                                              ),
                                              Expanded(
                                                child: Divider(
                                                  color: neutral.divider,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        itemBuilder: (context, index) {
                                          final entry = filtered[index];
                                          return KeyedSubtree(
                                            key: _desktopPageKey(entry),
                                            child: _DesktopDiaryPaper(
                                              entry: entry,
                                              preview: true,
                                              onViewFull: () =>
                                                  _openDesktopFullEntry(entry),
                                              onEdit: () =>
                                                  _openDesktopEditor(entry: entry),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  static DateTime _dayOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool _sameDay(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

