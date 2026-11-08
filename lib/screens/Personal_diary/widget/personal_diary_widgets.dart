part of '../view/personal_diary_screen.dart';

class _DiaryCoverHeader extends StatelessWidget {
  const _DiaryCoverHeader({
    required this.entries,
    required this.streak,
    required this.onWrite,
  });

  final List<MoodEntry> entries;
  final int streak;
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final thisMonth = entries.where((entry) {
      final now = DateTime.now();
      return entry.entryDateTime.year == now.year &&
          entry.entryDateTime.month == now.month;
    }).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primary.withValues(alpha: .72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: .24),
            blurRadius: 24,
            offset: const Offset(0, 11),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .18),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                    topLeft: Radius.circular(4),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: Colors.white,
                  size: 31,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MY PRIVATE STORY',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        fontSize: 11.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'A page for every day',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: onWrite,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: .2),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.edit_rounded),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _CoverStat(
                  value: '${entries.length}',
                  label: 'Pages',
                  icon: Icons.menu_book_rounded,
                ),
              ),
              Expanded(
                child: _CoverStat(
                  value: '$thisMonth',
                  label: 'This month',
                  icon: Icons.calendar_month_rounded,
                ),
              ),
              Expanded(
                child: _CoverStat(
                  value: '$streak',
                  label: 'Day streak',
                  icon: Icons.local_fire_department_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoverStat extends StatelessWidget {
  const _CoverStat({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11.5),
        ),
      ],
    );
  }
}

class _DateNavigator extends StatelessWidget {
  const _DateNavigator({
    required this.controller,
    required this.selectedDate,
    required this.showAllDates,
    required this.onShowAll,
    required this.onPageChanged,
  });

  final PageController controller;
  final DateTime selectedDate;
  final bool showAllDates;
  final VoidCallback onShowAll;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.calendar_view_week_rounded, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Turn through dates',
                  style: TextStyle(
                    color: neutral.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: onShowAll,
                child: Text(
                  'All dates',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: showAllDates ? scheme.primary : neutral.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 86,
          child: PageView.builder(
            controller: controller,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final date = _PersonalDiaryScreenState._dayOnly(
                DateTime.now().add(
                  Duration(days: index - _PersonalDiaryScreenState._datePageCenter),
                ),
              );
              final selected = !showAllDates &&
                  _PersonalDiaryScreenState._sameDay(date, selectedDate);
              return AnimatedBuilder(
                animation: controller,
                builder: (context, child) {
                  var page = index.toDouble();
                  if (controller.hasClients && controller.position.haveDimensions) {
                    page = controller.page ?? page;
                  }
                  final distance = (index - page).abs().clamp(0.0, 1.0).toDouble();
                  final scale = 1 - distance * .12;
                  return Transform.scale(scale: scale, child: child);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected ? scheme.primary : neutral.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected ? scheme.primary : neutral.divider,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: .25),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('EEE').format(date).toUpperCase(),
                        style: TextStyle(
                          color: selected ? Colors.white70 : neutral.textSecondary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          color: selected ? Colors.white : neutral.textPrimary,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        DateFormat('MMM').format(date),
                        style: TextStyle(
                          color: selected ? Colors.white70 : neutral.textSecondary,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DesktopDiaryPageTile extends StatelessWidget {
  const _DesktopDiaryPageTile({required this.entry, required this.selected, required this.onTap});
  final MoodEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: selected ? scheme.primary.withValues(alpha: .09) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? scheme.primary.withValues(alpha: .35) : Colors.transparent),
            ),
            child: Row(children: [
              Container(
                width: 42, height: 50, alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Color(entry.accentColorValue).withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(entry.moodEmoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(entry.effectiveTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
                  if (entry.isFavorite) Icon(Icons.bookmark_rounded, size: 16, color: scheme.primary),
                ]),
                const SizedBox(height: 3),
                Text(DateFormat('EEE, d MMM yyyy').format(entry.entryDateTime), style: TextStyle(fontSize: 11.5, color: neutral.textSecondary)),
                if (entry.tags.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(entry.tags.take(3).map((e) => '#$e').join('  '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: neutral.textSecondary)),
                ],
              ])),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DesktopDiaryPaper extends StatelessWidget {
  const _DesktopDiaryPaper({
    required this.entry,
    required this.onEdit,
    this.preview = true,
    this.onViewFull,
  });

  final MoodEntry entry;
  final VoidCallback onEdit;
  final bool preview;
  final VoidCallback? onViewFull;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final scheme = Theme.of(context).colorScheme;
    final accent = Color(entry.accentColorValue);
    final notes = (entry.notes ?? '').trim();
    final gratitude = (entry.gratitude ?? '').trim();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(22),
        // BorderRadius requires a uniform Border. The colored diary spine is
        // painted separately below so Flutter can safely paint rounded corners.
        border: Border.all(color: neutral.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 12,
            child: ColoredBox(
              color: accent.withValues(alpha: .75),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 28, 38, 34),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('EEEE')
                                  .format(entry.entryDateTime)
                                  .toUpperCase(),
                              style: TextStyle(
                                color: accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('d MMMM yyyy')
                                  .format(entry.entryDateTime),
                              style: TextStyle(
                                color: neutral.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        entry.moodEmoji,
                        style: const TextStyle(fontSize: 34),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 17),
                        label: const Text('Edit page'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    entry.effectiveTitle,
                    style: TextStyle(
                      color: neutral.textPrimary,
                      fontSize: 32,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (entry.tags.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: entry.tags
                          .map(
                            (tag) => Chip(
                              label: Text('#$tag'),
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Divider(color: neutral.divider),
                  const SizedBox(height: 20),
                  if (notes.isNotEmpty)
                    Text(
                      notes,
                      maxLines: preview ? 10 : null,
                      overflow:
                          preview ? TextOverflow.ellipsis : TextOverflow.visible,
                      style: TextStyle(
                        color: neutral.textPrimary,
                        fontSize: 17,
                        height: 1.85,
                        letterSpacing: .1,
                      ),
                    )
                  else
                    Text(
                      'This page has no written notes.',
                      style: TextStyle(
                        color: neutral.textSecondary,
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  if (gratitude.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: .06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: .12),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GRATITUDE',
                            style: TextStyle(
                              color: scheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            gratitude,
                            maxLines: preview ? 3 : null,
                            overflow: preview
                                ? TextOverflow.ellipsis
                                : TextOverflow.visible,
                            style:
                                const TextStyle(fontSize: 15.5, height: 1.55),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (entry.trigger != null && entry.trigger!.trim().isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            size: 18,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Prompt: ${entry.trigger}',
                            maxLines: preview ? 2 : null,
                            overflow: preview
                                ? TextOverflow.ellipsis
                                : TextOverflow.visible,
                            style: TextStyle(
                              color: neutral.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (preview && onViewFull != null) ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: onViewFull,
                          icon: const Icon(
                            Icons.open_in_full_rounded,
                            size: 17,
                          ),
                          label: const Text('View full page'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    '${entry.wordCount} words  •  '
                    '${DateFormat('h:mm a').format(entry.entryDateTime)}',
                    style: TextStyle(
                      color: neutral.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopDiaryFullPage extends StatelessWidget {
  const _DesktopDiaryFullPage({
    required this.entry,
    required this.onBack,
    required this.onEdit,
  });

  final MoodEntry entry;
  final VoidCallback onBack;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: neutral.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: neutral.divider),
          ),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back to pages'),
              ),
              const Spacer(),
              Text(
                'Full diary page',
                style: TextStyle(
                  color: neutral.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(right: 8, bottom: 40),
            child: _DesktopDiaryPaper(
              entry: entry,
              preview: false,
              onEdit: onEdit,
            ),
          ),
        ),
      ],
    );
  }
}

class _DesktopDiaryOverview extends StatelessWidget {
  const _DesktopDiaryOverview({
    required this.entries,
    required this.filteredEntries,
    required this.tags,
    required this.streak,
    required this.onWrite,
    required this.onOpenEntry,
  });

  final List<MoodEntry> entries;
  final List<MoodEntry> filteredEntries;
  final List<String> tags;
  final int streak;
  final VoidCallback onWrite;
  final ValueChanged<MoodEntry> onOpenEntry;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final thisMonth = entries
        .where(
          (entry) => entry.entryDateTime.year == now.year &&
              entry.entryDateTime.month == now.month,
        )
        .length;
    final bookmarked = entries.where((entry) => entry.isFavorite).length;
    final totalWords = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.wordCount,
    );
    final recent = filteredEntries.take(6).toList(growable: false);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(2, 2, 8, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  scheme.primary,
                  scheme.primary.withValues(alpha: .72),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Container(
                  width: 68,
                  height: 82,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .18),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                      topLeft: Radius.circular(5),
                      bottomLeft: Radius.circular(5),
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(width: 20),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MY PRIVATE STORY',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 1.4,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Diary Overview',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 30,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Your pages, writing rhythm and recent memories at a glance.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: onWrite,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: scheme.primary,
                  ),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Write page'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              // The overview cards contain a vertical stack (icon, value and
              // label). A fixed childAspectRatio can make the cards too short
              // when the diary is rendered inside the desktop right pane,
              // causing a RenderFlex overflow. Give each tile a predictable
              // vertical extent and reduce the column count on narrower panes.
              final columnCount = constraints.maxWidth >= 760
                  ? 4
                  : constraints.maxWidth >= 420
                      ? 2
                      : 1;

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: columnCount,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 126,
                children: [
                  _DiaryOverviewStat(
                    icon: Icons.menu_book_rounded,
                    value: '${entries.length}',
                    label: 'Total pages',
                  ),
                  _DiaryOverviewStat(
                    icon: Icons.calendar_month_rounded,
                    value: '$thisMonth',
                    label: 'This month',
                  ),
                  _DiaryOverviewStat(
                    icon: Icons.local_fire_department_rounded,
                    value: '$streak',
                    label: 'Day streak',
                  ),
                  _DiaryOverviewStat(
                    icon: Icons.bookmark_rounded,
                    value: '$bookmarked',
                    label: 'Bookmarked',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _DiaryOverviewSummaryCard(
                  icon: Icons.notes_rounded,
                  title: 'Words written',
                  value: NumberFormat.decimalPattern().format(totalWords),
                  subtitle: 'Across all diary pages',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DiaryOverviewSummaryCard(
                  icon: Icons.sell_outlined,
                  title: 'Tags used',
                  value: '${tags.length}',
                  subtitle: 'Organizing your memories',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent pages',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '${filteredEntries.length} visible',
                style: TextStyle(
                  color: neutral.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (recent.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: neutral.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: neutral.divider),
              ),
              child: Text(
                'No pages match the current filters.',
                textAlign: TextAlign.center,
                style: TextStyle(color: neutral.textSecondary),
              ),
            )
          else
            ...recent.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: neutral.card,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () => onOpenEntry(entry),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: neutral.divider),
                      ),
                      child: Row(
                        children: [
                          Text(
                            entry.moodEmoji,
                            style: const TextStyle(fontSize: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.effectiveTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  DateFormat('EEEE, d MMMM yyyy')
                                      .format(entry.entryDateTime),
                                  style: TextStyle(
                                    color: neutral.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
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

class _DiaryOverviewStat extends StatelessWidget {
  const _DiaryOverviewStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: neutral.divider),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: scheme.primary, size: 22),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: neutral.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DiaryOverviewSummaryCard extends StatelessWidget {
  const _DiaryOverviewSummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: neutral.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: scheme.primary),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: neutral.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: neutral.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopDiaryEmpty extends StatelessWidget {
  const _DesktopDiaryEmpty({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Container(
      decoration: BoxDecoration(color: neutral.card, borderRadius: BorderRadius.circular(22), border: Border.all(color: neutral.divider)),
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.menu_book_outlined, size: 64, color: neutral.textSecondary),
        const SizedBox(height: 16),
        const Text('Your diary is ready for a new page', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.edit_rounded), label: const Text('Write first page')),
      ])),
    );
  }
}
