part of '../view/pill_home_screen.dart';

class _WeekSchedule extends StatelessWidget {
  const _WeekSchedule({required this.state, required this.controller});

  final PillHomeState state;
  final PillHomeController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final weekEnd = state.weekStart.add(const Duration(days: 6));
    final groups = state.groupedVisibleOccurrences;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _SectionTitle(
                title: 'Schedule',
                subtitle:
                    '${state.weekStart.day} ${PillUi.monthName(state.weekStart.month)} – '
                    '${weekEnd.day} ${PillUi.monthName(weekEnd.month)}',
              ),
            ),
            _WeekNavigation(controller: controller),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 7,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final date = state.weekStart.add(Duration(days: index));
              final key = PillUi.dateKey(date);
              final selected = state.selectedDate != null &&
                  PillUi.dateKey(state.selectedDate!) == key;
              final isToday = key == PillUi.dateKey(DateTime.now());
              final count = state.weekOccurrences
                  .where((item) => item['scheduled_date'] == key)
                  .length;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => controller.selectDate(date),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 59,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color:
                          selected ? scheme.primary : PillUi.surface(context),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected
                            ? scheme.primary
                            : isToday
                                ? scheme.primary.withOpacity(.45)
                                : scheme.outlineVariant.withOpacity(.75),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          PillUi.shortWeekday(date),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: selected
                                ? scheme.onPrimary.withOpacity(.78)
                                : scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${date.day}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color:
                                selected ? scheme.onPrimary : scheme.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          constraints: const BoxConstraints(minWidth: 20),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? scheme.onPrimary.withOpacity(.18)
                                : PillUi.tintedSurface(
                                    context,
                                    scheme.primary,
                                    opacity: .09,
                                  ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$count',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color:
                                  selected ? scheme.onPrimary : scheme.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              if (state.selectedDate != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Clear day'),
                    onPressed: controller.clearDateFilter,
                  ),
                ),
              ...['ALL', 'PENDING', 'TAKEN', 'MISSED', 'SKIPPED'].map(
                (status) {
                  final selected = state.statusFilter == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        status == 'ALL' ? 'All' : PillUi.statusLabel(status),
                      ),
                      selected: selected,
                      onSelected: (_) => controller.changeStatusFilter(status),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (groups.isEmpty)
          const _EmptyCard(
            icon: Icons.filter_alt_off_outlined,
            title: 'No doses found',
            subtitle: 'Clear the filters or choose another week.',
          )
        else
          ...groups.entries.expand((entry) {
            final date = DateTime.parse(entry.key);
            return [
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 12, 2, 9),
                child: Text(
                  PillUi.sectionDateLabel(date),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ...entry.value.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OccurrenceCard(
                    occurrence: item,
                    controller: controller,
                  ),
                ),
              ),
            ];
          }),
      ],
    );
  }
}

class _WeekNavigation extends StatelessWidget {
  const _WeekNavigation({required this.controller});

  final PillHomeController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: PillUi.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withOpacity(.75)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CompactIconButton(
            tooltip: 'Previous week',
            icon: Icons.chevron_left_rounded,
            onPressed: () => controller.moveWeek(-1),
          ),
          InkWell(
            onTap: controller.goToCurrentWeek,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Text(
                'Today',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ),
          _CompactIconButton(
            tooltip: 'Next week',
            icon: Icons.chevron_right_rounded,
            onPressed: () => controller.moveWeek(1),
          ),
        ],
      ),
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  const _CompactIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
    );
  }
}

class _OccurrenceCard extends StatelessWidget {
  const _OccurrenceCard({required this.occurrence, required this.controller});

  final Map<String, dynamic> occurrence;
  final PillHomeController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final medicineColor = PillUi.colorFromHex(occurrence['color_hex']);
    final status = occurrence['status']?.toString() ?? 'PENDING';
    final statusColor = PillUi.statusColor(context, status);
    final scheduled = DateTime.parse(
      '${occurrence['scheduled_date']}T${occurrence['scheduled_time']}:00',
    );
    final canAct = !scheduled.isAfter(DateTime.now());
    final strength = PillUi.strengthLabel(occurrence);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: PillUi.cardDecoration(context, radius: 21),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: PillUi.tintedSurface(
                context,
                medicineColor,
                opacity: .12,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              PillUi.iconForType(occurrence['pill_type_name']),
              color: medicineColor,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  occurrence['pill_name'].toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${PillUi.doseLabel(occurrence)}'
                  '${strength.isEmpty ? '' : ' · $strength'}'
                  ' · ${PillUi.prettyTime(context, occurrence['scheduled_time'])}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                _StatusPill(status: status, color: statusColor),
              ],
            ),
          ),
          if (canAct) ...[
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'Update status',
              onSelected: (value) => controller.markOccurrence(
                occurrence['id'] as int,
                value,
              ),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'TAKEN',
                  child: _MenuItem(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Mark as taken',
                  ),
                ),
                PopupMenuItem(
                  value: 'MISSED',
                  child: _MenuItem(
                    icon: Icons.cancel_outlined,
                    label: 'Mark as missed',
                  ),
                ),
                PopupMenuItem(
                  value: 'SKIPPED',
                  child: _MenuItem(
                    icon: Icons.remove_circle_outline_rounded,
                    label: 'Mark as skipped',
                  ),
                ),
              ],
              child: Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PillUi.tintedSurface(
                    context,
                    scheme.primary,
                    opacity: .09,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.more_horiz_rounded,
                  size: 22,
                  color: scheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.color});

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: PillUi.tintedSurface(context, color, opacity: .10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PillUi.statusIcon(status), size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              PillUi.statusLabel(status),
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactOccurrenceSection extends StatelessWidget {
  const _CompactOccurrenceSection({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.controller,
    required this.emptyText,
  });

  final String title;
  final String subtitle;
  final List<Map<String, dynamic>> items;
  final PillHomeController controller;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: title, subtitle: subtitle),
        const SizedBox(height: 12),
        if (items.isEmpty)
          _EmptyCard(
            icon: Icons.event_busy_outlined,
            title: emptyText,
            subtitle: 'Nothing needs attention here.',
          )
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OccurrenceCard(
                occurrence: item,
                controller: controller,
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w800,
            letterSpacing: -.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      decoration: PillUi.cardDecoration(context, radius: 22),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 11),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final error = scheme.error;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: PillUi.cardDecoration(
        context,
        color: PillUi.tintedSurface(context, error, opacity: .09),
        borderColor: error.withOpacity(.24),
        radius: 18,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
