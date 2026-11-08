part of '../view/pill_home_screen.dart';

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}

class _ProfileSelector extends StatelessWidget {
  const _ProfileSelector({required this.state, required this.controller});

  final PillHomeState state;
  final PillHomeController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      decoration: PillUi.cardDecoration(context, radius: 18),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: PillUi.tintedSurface(
                context,
                scheme.primary,
                opacity: .12,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.person_outline_rounded,
              color: scheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: state.activeProfileId,
                isExpanded: true,
                borderRadius: BorderRadius.circular(16),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
                items: state.profiles
                    .map(
                      (profile) => DropdownMenuItem<int>(
                        value: profile['id'] as int,
                        child: Text('For ${profile['name']}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) controller.changeProfile(value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.state});

  final PillHomeState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final taken = state.todayStats['TAKEN'] ?? 0;
    final missed = state.todayStats['MISSED'] ?? 0;
    final pending = state.todayStats['PENDING'] ?? 0;
    final skipped = state.todayStats['SKIPPED'] ?? 0;
    final total = state.todayStats.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final progress = total == 0 ? 0.0 : taken / total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PillUi.tintedSurface(context, scheme.primary, opacity: .07),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.primary.withOpacity(.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today’s progress',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      total == 0 ? 'No doses today' : '$taken of $total taken',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      missed > 0
                          ? '$missed missed dose${missed == 1 ? '' : 's'} need attention'
                          : pending > 0
                              ? '$pending dose${pending == 1 ? '' : 's'} remaining'
                              : skipped > 0
                                  ? '$skipped dose${skipped == 1 ? '' : 's'} skipped'
                                  : 'Everything is completed',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 68,
                height: 68,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 7,
                      strokeCap: StrokeCap.round,
                      backgroundColor: scheme.outlineVariant,
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Pending',
                  value: pending,
                  color: PillUi.statusColor(context, 'PENDING'),
                  icon: Icons.schedule_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  label: 'Taken',
                  value: taken,
                  color: PillUi.statusColor(context, 'TAKEN'),
                  icon: Icons.check_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  label: 'Missed',
                  value: missed,
                  color: PillUi.statusColor(context, 'MISSED'),
                  icon: Icons.close_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
      decoration: BoxDecoration(
        color: PillUi.tintedSurface(context, color, opacity: .08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
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
    );
  }
}

class _NextDoseCard extends StatelessWidget {
  const _NextDoseCard({required this.state});

  final PillHomeState state;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final pendingToday = state.todayOccurrences.where((item) {
      if (item['status'] != 'PENDING') return false;
      return _dateTime(item).isAfter(now);
    }).toList();

    Map<String, dynamic>? next;
    if (pendingToday.isNotEmpty) {
      next = pendingToday.first;
    } else {
      for (final item in state.upcomingOccurrences) {
        if (item['status'] == 'PENDING') {
          next = item;
          break;
        }
      }
    }

    if (next == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final medicineColor = PillUi.colorFromHex(next['color_hex']);
    final date = DateTime.parse(next['scheduled_date'] as String);
    final isToday = PillUi.dateKey(date) == PillUi.dateKey(now);
    final onMedicine = PillUi.readableOn(medicineColor);

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: PillUi.cardDecoration(
        context,
        color: PillUi.tintedSurface(context, medicineColor, opacity: .08),
        borderColor: medicineColor.withOpacity(.24),
        radius: 24,
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: medicineColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              PillUi.iconForType(next['pill_type_name']),
              color: onMedicine,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.notifications_active_outlined,
                      size: 14,
                      color: medicineColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'NEXT DOSE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: medicineColor,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .7,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  next['pill_name'].toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${PillUi.doseLabel(next)} · '
                  '${isToday ? 'Today' : PillUi.sectionDateLabel(date)} at '
                  '${PillUi.prettyTime(context, next['scheduled_time'])}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DateTime _dateTime(Map<String, dynamic> item) {
    final date = item['scheduled_date'].toString();
    final time = item['scheduled_time'].toString();
    return DateTime.parse('${date}T$time:00');
  }
}

class _LowStockCard extends StatelessWidget {
  const _LowStockCard({required this.pills, required this.onTap});

  final List<Map<String, dynamic>> pills;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final warning =
        PillUi.isDark(context) ? const Color(0xFFFFC65A) : AppColors.warning;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: PillUi.cardDecoration(
            context,
            color: PillUi.tintedSurface(context, warning, opacity: .10),
            borderColor: warning.withOpacity(.26),
            radius: 22,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: PillUi.tintedSurface(context, warning, opacity: .14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: warning,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stock running low',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${pills.length} medicine${pills.length == 1 ? '' : 's'} need a refill',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
