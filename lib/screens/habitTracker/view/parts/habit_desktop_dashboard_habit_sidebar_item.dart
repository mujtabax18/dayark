part of '../habit_desktop_dashboard.dart';

class _HabitSidebarItem extends StatelessWidget {
  const _HabitSidebarItem({
    required this.habit,
    required this.selected,
    required this.onTap,
  });

  final Habit habit;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? habit.color.withOpacity(.11) : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: habit.color.withOpacity(.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CenteredFaIcon(
                  HabitIconCatalog.fromCode(
                    habit.iconCode,
                    category: habit.category,
                    title: habit.title,
                  ),
                  size: 12,
                  color: habit.color,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  habit.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? habit.color : scheme.onSurface,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${habit.currentStreak}',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
