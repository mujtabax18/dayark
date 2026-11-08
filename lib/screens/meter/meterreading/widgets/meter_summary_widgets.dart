part of '../view/meterreading.dart';

class _MeterHeroCard extends StatelessWidget {
  final Meter meter;
  final MeterInsights insights;
  final double projectedMonthUsage;
  final double estimatedCost;

  const _MeterHeroCard({
    required this.meter,
    required this.insights,
    required this.projectedMonthUsage,
    required this.estimatedCost,
  });

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final color = Color(meter.colorValue);
    final latest = insights.latest;
    final baseline = meter.baseline;
    final usageFromBaseline = latest == null || baseline == null
        ? null
        : (latest.value - baseline).clamp(0, double.infinity).toDouble();
    final currentUsage = usageFromBaseline ?? 0.0;
    final progress = meter.targetUnits == null || meter.targetUnits! <= 0
        ? 0.0
        : currentUsage / meter.targetUnits!;
    final overUnitTarget = meter.targetUnits != null &&
        meter.targetUnits! > 0 &&
        currentUsage > meter.targetUnits!;
    final overBudget = meter.targetBudget != null &&
        meter.targetBudget! > 0 &&
        estimatedCost > meter.targetBudget!;
    final overTarget = overUnitTarget || overBudget;
    final formatter = NumberFormat('#,##0.##');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  MeterCatalog.iconFor(meter.iconKey),
                  color: Colors.white,
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      latest == null
                          ? 'No reading yet'
                          : 'Current reading  ${formatter.format(latest.value)} ${meter.unitLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      latest == null
                          ? 'Add the first reading to establish a baseline'
                          : 'Updated ${DateFormat('dd MMM yyyy, hh:mm a').format(latest.date)}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  meter.isActive ? 'ACTIVE' : 'INACTIVE',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      color: Colors.white.withOpacity(0.88),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'UNITS USED FROM BASELINE',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.84),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  usageFromBaseline == null
                      ? '-- ${meter.unitLabel}'
                      : '${formatter.format(usageFromBaseline)} ${meter.unitLabel}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  baseline == null
                      ? 'Set a baseline reading to calculate total usage.'
                      : latest == null
                          ? 'Baseline: ${formatter.format(baseline)} ${meter.unitLabel}'
                          : 'Baseline ${formatter.format(baseline)}  →  Current ${formatter.format(latest.value)}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  label: 'Projected month',
                  value:
                      '${formatter.format(projectedMonthUsage)} ${meter.unitLabel}',
                ),
              ),
              Expanded(
                child: _HeroMetric(
                  label: 'Estimated cost',
                  value: 'PKR ${formatter.format(estimatedCost)}',
                ),
              ),
            ],
          ),
          if (meter.targetUnits != null && meter.targetUnits! > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    usageFromBaseline == null
                        ? 'Monthly target: ${formatter.format(meter.targetUnits)} ${meter.unitLabel}'
                        : 'Used ${formatter.format(currentUsage)} / ${formatter.format(meter.targetUnits)} ${meter.unitLabel}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 11,
                    ),
                  ),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: progress.clamp(0, 1).toDouble(),
                minHeight: 8,
                backgroundColor: Colors.white.withOpacity(0.20),
                valueColor: AlwaysStoppedAnimation<Color>(
                  overUnitTarget ? AppColors.warning : Colors.white,
                ),
              ),
            ),
          ],
          if (meter.number.isNotEmpty || meter.referenceNumber.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              [
                if (meter.number.isNotEmpty) 'Meter #${meter.number}',
                if (meter.referenceNumber.isNotEmpty)
                  'Ref ${meter.referenceNumber}',
              ].join(' • '),
              style: TextStyle(
                color: neutral.textPrimaryNot.withOpacity(0.82),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.72),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _InsightsGrid extends StatelessWidget {
  final Meter meter;
  final MeterInsights insights;

  const _InsightsGrid({required this.meter, required this.insights});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = MediaQuery.sizeOf(context).width >= 1100;
        final columns = desktop ? 4 : 2;
        final gap = 10.0;
        final width =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: 10,
          children: [
            _InsightCard(
              width: width,
              icon: Icons.trending_up_rounded,
              label: 'Used from baseline',
              value: insights.latest == null || meter.baseline == null
                  ? '-- ${meter.unitLabel}'
                  : '${_format((insights.latest!.value - meter.baseline!).clamp(0, double.infinity).toDouble())} ${meter.unitLabel}',
              color: Colors.red,
              valueColor: Colors.red,
            ),
            _InsightCard(
              width: width,
              icon: Icons.today_outlined,
              label: 'Average per day',
              value:
                  '${_format(insights.averageDailyUsage)} ${meter.unitLabel}',
              color: AppColors.success,
            ),
            _InsightCard(
              width: width,
              icon: Icons.functions_rounded,
              label: 'Tracked usage',
              value: '${_format(insights.totalUsage)} ${meter.unitLabel}',
              color: AppColors.warning,
            ),
            _InsightCard(
              width: width,
              icon: Icons.event_available_outlined,
              label: 'Next reading due',
              value: insights.nextReadingDue == null
                  ? 'Not available'
                  : DateFormat('dd MMM yyyy').format(insights.nextReadingDue!),
              color: AppColors.primary,
            ),
          ],
        );
      },
    );
  }

  static String _format(double value) => NumberFormat('#,##0.##').format(value);
}

class _InsightCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color? valueColor;

  const _InsightCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: neutral.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: neutral.textSecondary,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: valueColor ?? neutral.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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
