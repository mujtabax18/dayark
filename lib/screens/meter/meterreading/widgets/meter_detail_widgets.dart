part of '../view/meterreading.dart';

class _UsageTrendChart extends StatelessWidget {
  final Meter meter;
  final List<Reading> readings;

  const _UsageTrendChart({required this.meter, required this.readings});

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final points = _points();

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: neutral.divider),
      ),
      child: points.isEmpty
          ? Center(
              child: Text(
                'Add at least two readings to see consumption trend.',
                textAlign: TextAlign.center,
                style: TextStyle(color: neutral.textSecondary),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final maxUsage = points
                    .map((point) => point.usage)
                    .fold<double>(0, (max, value) => value > max ? value : max);
                return Column(
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: points.map((point) {
                          final ratio = maxUsage <= 0
                              ? 0.05
                              : (point.usage / maxUsage)
                                  .clamp(0.05, 1.0)
                                  .toDouble();
                          return Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    NumberFormat('#,##0.#').format(point.usage),
                                    maxLines: 1,
                                    overflow: TextOverflow.fade,
                                    style: TextStyle(
                                      color: neutral.textSecondary,
                                      fontSize: 9,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    height:
                                        (constraints.maxHeight - 38) * ratio,
                                    decoration: BoxDecoration(
                                      color: Color(meter.colorValue)
                                          .withOpacity(0.82),
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: points
                          .map(
                            (point) => Expanded(
                              child: Text(
                                DateFormat('dd MMM').format(point.date),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                style: TextStyle(
                                  color: neutral.textSecondary,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                );
              },
            ),
    );
  }

  List<_UsagePoint> _points() {
    if (readings.length < 2) return const [];
    final sorted = [...readings]
      ..sort((a, b) {
        final dateCompare = a.date.compareTo(b.date);
        if (dateCompare != 0) return dateCompare;
        return (a.id ?? 0).compareTo(b.id ?? 0);
      });
    final result = <_UsagePoint>[];
    for (var index = 1; index < sorted.length; index++) {
      final current = sorted[index];
      final previous = sorted[index - 1];
      final difference = current.value - previous.value;
      result.add(
        _UsagePoint(
          date: current.date,
          usage: difference < 0 ? 0 : difference,
        ),
      );
    }
    return result.length <= 7 ? result : result.sublist(result.length - 7);
  }
}

class _UsagePoint {
  final DateTime date;
  final double usage;

  const _UsagePoint({required this.date, required this.usage});
}

class _MeterDetailsCard extends StatelessWidget {
  final Meter meter;
  final List<MeterTariffSlab> tariffSlabs;
  final VoidCallback onEditTariff;

  const _MeterDetailsCard({
    required this.meter,
    required this.tariffSlabs,
    required this.onEditTariff,
  });

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Material(
      color: neutral.card,
      borderRadius: BorderRadius.circular(18),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: neutral.divider),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: neutral.divider),
        ),
        leading: const Icon(Icons.tune_rounded, color: AppColors.primary),
        title: Text(
          'Meter setup',
          style: TextStyle(
            color: neutral.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${MeterCatalog.frequencyLabel(meter.readingFrequency)} • ${MeterCatalog.tariffLabel(meter.tariffCategory)}',
          style: TextStyle(color: neutral.textSecondary, fontSize: 11),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Divider(color: neutral.divider),
          _DetailRow(
              label: 'Type', value: MeterCatalog.typeLabel(meter.meterType)),
          _DetailRow(
            label: 'Provider',
            value: meter.provider.isEmpty ? 'Not set' : meter.provider,
          ),
          _DetailRow(
            label: 'Location',
            value: meter.location.isEmpty ? 'Not set' : meter.location,
          ),
          _DetailRow(
            label: 'Baseline',
            value: meter.baseline == null
                ? 'Not set'
                : '${NumberFormat('#,##0.##').format(meter.baseline)} ${meter.unitLabel}',
          ),
          _DetailRow(
            label: 'Simple rate',
            value:
                'PKR ${NumberFormat('#,##0.##').format(meter.unitRate)} / ${meter.unitLabel}',
          ),
          _DetailRow(
            label: 'Fixed charges',
            value: 'PKR ${NumberFormat('#,##0.##').format(meter.fixedCharges)}',
          ),
          _DetailRow(
            label: 'Tariff slabs',
            value: tariffSlabs.isEmpty
                ? 'Using simple rate'
                : '${tariffSlabs.length} configured',
          ),
          if (meter.notes.isNotEmpty)
            _DetailRow(label: 'Notes', value: meter.notes),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onEditTariff,
              icon: const Icon(Icons.price_change_outlined),
              label: const Text('Configure tariff slabs'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(color: neutral.textSecondary, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: neutral.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingCard extends StatelessWidget {
  final Meter meter;
  final Reading reading;
  final Reading? previousReading;
  final List<MeterTariffSlab> tariffSlabs;
  final bool isBaseline;
  final DateTime? baselineDate;
  final VoidCallback onEdit;
  final VoidCallback onSetBaseline;
  final VoidCallback onDelete;

  const _ReadingCard({
    required this.meter,
    required this.reading,
    required this.previousReading,
    required this.tariffSlabs,
    required this.isBaseline,
    required this.baselineDate,
    required this.onEdit,
    required this.onSetBaseline,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final color = Color(meter.colorValue);
    final isBeforeBaseline =
        baselineDate != null && reading.date.isBefore(baselineDate!);
    final previous = isBaseline
        ? reading.value
        : previousReading?.value ?? (isBeforeBaseline ? null : meter.baseline);
    final difference = previous == null ? 0.0 : reading.value - previous;
    final usage = difference < 0 ? 0.0 : difference;
    final billingUsage = meter.baseline == null || isBeforeBaseline
        ? 0.0
        : (reading.value - meter.baseline!)
            .clamp(0, double.infinity)
            .toDouble();

    // Cost is always recalculated from the active bill baseline and current
    // tariff. This prevents old saved estimates from surviving a new bill.
    final estimate = isBeforeBaseline
        ? 0.0
        : MeterInsights.calculateCost(
            units: billingUsage,
            meter: meter,
            slabs: tariffSlabs,
          );

    return Material(
      color: neutral.card,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          margin: const EdgeInsets.only(bottom: 11),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: neutral.divider),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  reading.readingKind == 'meter_reset'
                      ? Icons.restart_alt_rounded
                      : reading.readingKind == 'estimated'
                          ? Icons.calculate_outlined
                          : MeterCatalog.iconFor(meter.iconKey),
                  color: color,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${NumberFormat('#,##0.##').format(reading.value)} ${meter.unitLabel}',
                            style: TextStyle(
                              color: neutral.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isBaseline)
                          const Icon(
                            Icons.flag_rounded,
                            color: AppColors.warning,
                            size: 18,
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(reading.date),
                      style: TextStyle(
                        color: neutral.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _ReadingBadge(
                          icon: Icons.swap_vert_rounded,
                          text:
                              '${NumberFormat('#,##0.##').format(usage)} ${meter.unitLabel} used',
                          color: color,
                        ),
                        _ReadingBadge(
                          icon: Icons.payments_outlined,
                          text: reading.billAmount != null
                              ? 'Bill PKR ${NumberFormat('#,##0.##').format(reading.billAmount)}'
                              : isBeforeBaseline
                                  ? 'Before current baseline'
                                  : 'Bill est. PKR ${NumberFormat('#,##0.##').format(estimate)}',
                          color: AppColors.success,
                        ),
                        if (reading.readingKind != 'normal')
                          _ReadingBadge(
                            icon: Icons.info_outline_rounded,
                            text: MeterCatalog.readingKindLabel(
                              reading.readingKind,
                            ),
                            color: AppColors.warning,
                          ),
                      ],
                    ),
                    if (reading.note.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        reading.note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: neutral.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon:
                    Icon(Icons.more_vert_rounded, color: neutral.textSecondary),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                      break;
                    case 'baseline':
                      onSetBaseline();
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit reading')),
                  PopupMenuItem(
                    value: 'baseline',
                    child: Text('Set as baseline'),
                  ),
                  PopupMenuItem(value: 'delete', child: Text('Delete reading')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadingBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _ReadingBadge({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: neutral.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: neutral.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}

class _MessageBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _MessageBanner({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: context.themeColors.neutral.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReadings extends StatelessWidget {
  const _EmptyReadings({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.query_stats_rounded,
      title: 'No readings yet',
      message:
          'Add the current meter value. The first reading becomes your baseline automatically.',
      actionLabel: 'Add first reading',
      onAction: onAdd,
      compact: true,
    );
  }
}
