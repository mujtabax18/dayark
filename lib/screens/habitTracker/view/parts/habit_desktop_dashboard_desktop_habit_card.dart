part of '../habit_desktop_dashboard.dart';

class _DesktopHabitCard extends StatelessWidget {
  const _DesktopHabitCard({
    required this.habit,
    required this.onOpen,
    required this.onEdit,
    required this.onComplete,
    required this.onSkip,
    required this.onUndo,
    required this.onToggleActive,
  });

  final Habit habit;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final VoidCallback onUndo;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final now = DateTime.now();
    final progress = habit.progressFor(now);
    final scheduled = habit.isScheduledOn(now);
    final expired = scheduled && !habit.canUpdate(now) && progress == null;
    final status = !habit.isActive
        ? 'Paused'
        : !scheduled
            ? 'Rest day'
            : progress?.isCompleted == true
                ? 'Completed today'
                : progress?.isSkipped == true
                    ? 'Skipped today'
                    : expired
                        ? 'Missed today'
                        : 'Due ${TimeOfDay(hour: habit.deadlineHour, minute: habit.deadlineMinute).format(context)}';
    final statusColor = !habit.isActive
        ? neutral.textSecondary
        : progress?.isCompleted == true
            ? AppColors.habit
            : expired
                ? AppColors.danger
                : progress?.isSkipped == true
                    ? Colors.orange
                    : neutral.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: neutral.divider),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: habit.color.withOpacity(.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: CenteredFaIcon(
                      HabitIconCatalog.fromCode(
                        habit.iconCode,
                        category: habit.category,
                        title: habit.title,
                      ),
                      color: habit.color,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: neutral.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          status,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Habit actions',
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'toggle') onToggleActive();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit habit'),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(habit.isActive ? 'Pause habit' : 'Resume habit'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _TinyMetric(
                    label: 'Streak',
                    value: '${habit.currentStreak}d',
                  ),
                  const SizedBox(width: 8),
                  _TinyMetric(
                    label: 'Best',
                    value: '${habit.bestStreak}d',
                  ),
                  const SizedBox(width: 8),
                  _TinyMetric(
                    label: '30 days',
                    value: '${(habit.completionRate() * 100).round()}%',
                  ),
                ],
              ),
              if (habit.isActive && scheduled) ...[
                const SizedBox(height: 12),
                if (progress != null)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onUndo,
                      icon: const CenteredFaIcon(
                        FontAwesomeIcons.rotateLeft,
                        size: 13,
                      ),
                      label: const Text('Undo today'),
                    ),
                  )
                else if (!expired)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onSkip,
                          child: const Text('Skip'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: habit.color,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: onComplete,
                          icon: const CenteredFaIcon(
                            FontAwesomeIcons.check,
                            size: 12,
                          ),
                          label: const Text('Complete'),
                        ),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TinyMetric extends StatelessWidget {
  const _TinyMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: neutral.background.withOpacity(.52),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: neutral.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: neutral.textSecondary, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopInfoBanner extends StatelessWidget {
  const _DesktopInfoBanner({
    required this.text,
    required this.color,
    required this.icon,
  });

  final String text;
  final Color color;
  final FaIconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: color.withOpacity(.09),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            CenteredFaIcon(icon, color: color, size: 15),
            const SizedBox(width: 9),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

class _DesktopEmptyState extends StatelessWidget {
  const _DesktopEmptyState({required this.paused, required this.onAdd});
  final bool paused;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 54, horizontal: 24),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: neutral.divider),
      ),
      child: Column(
        children: [
          CenteredFaIcon(
            paused ? FontAwesomeIcons.pause : FontAwesomeIcons.bullseye,
            size: 42,
            color: AppColors.habit,
          ),
          const SizedBox(height: 12),
          Text(
            paused ? 'No paused habits' : 'No habits yet',
            style: TextStyle(
              color: neutral.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            paused
                ? 'Habits you pause will be kept here without losing their history.'
                : 'Create your first habit to start tracking progress.',
            textAlign: TextAlign.center,
            style: TextStyle(color: neutral.textSecondary),
          ),
          if (!paused) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const CenteredFaIcon(FontAwesomeIcons.plus, size: 13),
              label: const Text('Create habit'),
            ),
          ],
        ],
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
      padding: const EdgeInsets.only(left: 11),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: .9,
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
    this.badge,
  });

  final FaIconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: selected ? AppColors.habit.withOpacity(.11) : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            child: Row(
              children: [
                CenteredFaIcon(
                  icon,
                  size: 15,
                  color: selected ? AppColors.habit : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? AppColors.habit : scheme.onSurface,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (badge != null)
                  Text(
                    badge!,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
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

