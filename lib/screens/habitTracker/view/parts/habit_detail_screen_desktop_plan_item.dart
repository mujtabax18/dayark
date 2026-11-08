part of '../HabitDetailScreen.dart';

class _DesktopPlanItem extends StatelessWidget {
  const _DesktopPlanItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.last = false,
  });

  final FaIconData icon;
  final String label;
  final String value;
  final Color color;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(.09),
              borderRadius: BorderRadius.circular(9),
            ),
            child: CenteredFaIcon(icon, size: 12, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: neutral.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: neutral.textPrimary,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: habit.color,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(18),
              ),
              child: CenteredFaIcon(
                HabitIconCatalog.fromCode(
                  habit.iconCode,
                  category: habit.category,
                  title: habit.title,
                ),
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.category,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    habit.description?.isNotEmpty == true
                        ? habit.description!
                        : 'Keep showing up, one day at a time.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Deadline ${TimeOfDay(hour: habit.deadlineHour, minute: habit.deadlineMinute).format(context)} · ${habit.repeatDays.length == 7 ? 'Every day' : '${habit.repeatDays.length} days/week'}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.suffix,
    required this.icon,
  });

  final String label;
  final String value;
  final String suffix;
  final FaIconData icon;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: neutral.divider),
      ),
      child: Column(
        children: [
          CenteredFaIcon(icon, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: neutral.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            suffix,
            style: TextStyle(color: neutral.textSecondary, fontSize: 10),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: neutral.textSecondary, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: neutral.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: neutral.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final FaIconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CenteredFaIcon(icon, size: 20),
            const SizedBox(width: 10),
            SizedBox(
              width: 54,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      );
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({required this.values, required this.lineColor});

  final List<double> values;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.grey.withOpacity(.18)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (values.isEmpty) return;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? 0.0
          : size.width * i / (values.length - 1);
      final y = size.height - (values[i].clamp(0, 1) * (size.height - 14)) - 7;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final x = values.length == 1
          ? 0.0
          : size.width * i / (values.length - 1);
      final y = size.height - (values[i] * (size.height - 14)) - 7;
      canvas.drawCircle(
        Offset(x, y),
        math.min(3.5, size.width / 50),
        Paint()..color = lineColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.lineColor != lineColor;
}

class _MonthStats {
  const _MonthStats({
    required this.completed,
    required this.skipped,
    required this.missed,
    required this.dailyRates,
  });

  final int completed;
  final int skipped;
  final int missed;
  final List<double> dailyRates;
}
