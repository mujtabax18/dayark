part of '../view/MeterListPage.dart';

class _DashboardSummary extends StatelessWidget {
  final List<Meter> meters;
  final Map<int, List<Reading>> readingsMap;
  final Map<int, MeterBaselineAnchor> baselineAnchorsMap;
  final Map<int, List<MeterTariffSlab>> tariffSlabsMap;

  const _DashboardSummary({
    required this.meters,
    required this.readingsMap,
    required this.baselineAnchorsMap,
    required this.tariffSlabsMap,
  });

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final active = meters.where((meter) => meter.isActive).toList();
    var projectedUnits = 0.0;
    var estimatedCost = 0.0;
    var alerts = 0;

    for (final meter in active) {
      final readings = readingsMap[meter.id] ?? const <Reading>[];
      final baselineAnchor = baselineAnchorsMap[meter.id];
      final tariffSlabs = tariffSlabsMap[meter.id] ?? const <MeterTariffSlab>[];
      final projectedMonthUsage = meterProjectedMonthUsage(
        meter: meter,
        readings: readings,
        baselineAnchor: baselineAnchor,
      );
      final currentUsage = meterUnitsFromBaseline(
        meter,
        readings,
        baselineAnchor: baselineAnchor,
      );
      final currentCost = meterCostFromBaseline(
        meter: meter,
        readings: readings,
        slabs: tariffSlabs,
        baselineAnchor: baselineAnchor,
      );
      final isOverUnits = meter.targetUnits != null &&
          meter.targetUnits! > 0 &&
          currentUsage > meter.targetUnits!;
      final isOverBudget = meter.targetBudget != null &&
          meter.targetBudget! > 0 &&
          currentCost > meter.targetBudget!;

      projectedUnits += projectedMonthUsage;
      estimatedCost += currentCost;
      if (isOverUnits || isOverBudget) alerts++;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.78),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Monthly overview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 16) / 3;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SummaryMetric(
                    width: width,
                    label: 'Active',
                    value: active.length.toString(),
                    icon: Icons.speed_rounded,
                  ),
                  _SummaryMetric(
                    width: width,
                    label: 'Projected',
                    value: _compact(projectedUnits),
                    icon: Icons.trending_up_rounded,
                  ),
                  _SummaryMetric(
                    width: width,
                    label: 'Est. PKR',
                    value: _compact(estimatedCost),
                    icon: Icons.payments_outlined,
                  ),
                ],
              );
            },
          ),
          if (alerts > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$alerts meter${alerts == 1 ? '' : 's'} currently above a usage or budget target',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (meters.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Add your first meter to start tracking.',
                style:
                    TextStyle(color: neutral.textPrimaryNot.withOpacity(0.9)),
              ),
            ),
        ],
      ),
    );
  }

  static String _compact(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(value < 100 ? 1 : 0);
  }
}

class _SummaryMetric extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final IconData icon;

  const _SummaryMetric({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}


class _DesktopMeterSummary extends StatelessWidget {
  final List<Meter> meters;
  final Map<int, List<Reading>> readingsMap;
  final Map<int, MeterBaselineAnchor> baselineAnchorsMap;
  final Map<int, List<MeterTariffSlab>> tariffSlabsMap;

  const _DesktopMeterSummary({
    required this.meters,
    required this.readingsMap,
    required this.baselineAnchorsMap,
    required this.tariffSlabsMap,
  });

  @override
  Widget build(BuildContext context) {
    final active = meters.where((meter) => meter.isActive).toList();
    var currentUsage = 0.0;
    var projectedUsage = 0.0;
    var estimatedCost = 0.0;
    var alerts = 0;

    for (final meter in active) {
      final readings = readingsMap[meter.id] ?? const <Reading>[];
      final baselineAnchor = baselineAnchorsMap[meter.id];
      final slabs = tariffSlabsMap[meter.id] ?? const <MeterTariffSlab>[];
      final used = meterUnitsFromBaseline(
        meter,
        readings,
        baselineAnchor: baselineAnchor,
      );
      final cost = meterCostFromBaseline(
        meter: meter,
        readings: readings,
        slabs: slabs,
        baselineAnchor: baselineAnchor,
      );
      currentUsage += used;
      projectedUsage += meterProjectedMonthUsage(
        meter: meter,
        readings: readings,
        baselineAnchor: baselineAnchor,
      );
      estimatedCost += cost;

      final overUnits = meter.targetUnits != null &&
          meter.targetUnits! > 0 &&
          used > meter.targetUnits!;
      final overBudget = meter.targetBudget != null &&
          meter.targetBudget! > 0 &&
          cost > meter.targetBudget!;
      if (overUnits || overBudget) alerts++;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final columns = constraints.maxWidth >= 900 ? 4 : 2;
        final width =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            _DesktopMeterMetric(
              width: width,
              icon: Icons.electric_meter_outlined,
              label: 'Active meters',
              value: '${active.length}',
              detail: '${meters.length} total configured',
            ),
            _DesktopMeterMetric(
              width: width,
              icon: Icons.bolt_outlined,
              label: 'Used from baseline',
              value: NumberFormat('#,##0.##').format(currentUsage),
              detail: 'Current billing cycle',
            ),
            _DesktopMeterMetric(
              width: width,
              icon: Icons.trending_up_rounded,
              label: 'Projected usage',
              value: NumberFormat('#,##0.##').format(projectedUsage),
              detail: 'Projected to cycle end',
            ),
            _DesktopMeterMetric(
              width: width,
              icon: alerts > 0
                  ? Icons.warning_amber_rounded
                  : Icons.payments_outlined,
              label: 'Estimated cost',
              value: 'PKR ${NumberFormat('#,##0.##').format(estimatedCost)}',
              detail: alerts == 0
                  ? 'No active target alerts'
                  : '$alerts target alert${alerts == 1 ? '' : 's'}',
            ),
          ],
        );
      },
    );
  }
}

class _DesktopMeterMetric extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final String value;
  final String detail;

  const _DesktopMeterMetric({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: neutral.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 21),
          ),
          const SizedBox(width: 12),
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
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: neutral.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: neutral.textSecondary,
                    fontSize: 10,
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

class _DesktopMeterTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    Widget label(String text, {int flex = 1, TextAlign align = TextAlign.left}) {
      return Expanded(
        flex: flex,
        child: Text(
          text.toUpperCase(),
          textAlign: align,
          style: TextStyle(
            color: neutral.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: .65,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      color: neutral.background,
      child: Row(
        children: [
          label('Meter', flex: 28),
          label('Current', flex: 13),
          label('Used', flex: 13),
          label('Projected', flex: 13),
          label('Est. cost', flex: 15),
          label('Status', flex: 10),
          const SizedBox(width: 42),
        ],
      ),
    );
  }
}

class _DesktopMeterRow extends StatelessWidget {
  final Meter meter;
  final List<Reading> readings;
  final List<MeterTariffSlab> tariffSlabs;
  final MeterBaselineAnchor? baselineAnchor;
  final VoidCallback onOpen;
  final VoidCallback onCopyReference;
  final VoidCallback onSearchOnline;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Future<void> Function() onToggleStatus;

  const _DesktopMeterRow({
    required this.meter,
    required this.readings,
    required this.tariffSlabs,
    required this.baselineAnchor,
    required this.onOpen,
    required this.onCopyReference,
    required this.onSearchOnline,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final currentReadings = readingsForCurrentBaseline(
      meter,
      readings,
      baselineAnchor: baselineAnchor,
    );
    final latest = currentReadings.isEmpty ? null : currentReadings.first;
    final used = meterUnitsFromBaseline(
      meter,
      readings,
      baselineAnchor: baselineAnchor,
    );
    final projected = meterProjectedMonthUsage(
      meter: meter,
      readings: readings,
      baselineAnchor: baselineAnchor,
    );
    final cost = meterCostFromBaseline(
      meter: meter,
      readings: readings,
      slabs: tariffSlabs,
      baselineAnchor: baselineAnchor,
    );
    final formatter = NumberFormat('#,##0.##');

    Widget valueCell(String value, {int flex = 1}) {
      return Expanded(
        flex: flex,
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: neutral.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Expanded(
                flex: 28,
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Color(meter.colorValue).withOpacity(.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        MeterCatalog.iconFor(meter.iconKey),
                        color: Color(meter.colorValue),
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meter.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: neutral.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (meter.provider.isNotEmpty) meter.provider,
                              if (meter.location.isNotEmpty) meter.location,
                            ].join(' • ').isEmpty
                                ? MeterCatalog.typeLabel(meter.meterType)
                                : [
                                    if (meter.provider.isNotEmpty)
                                      meter.provider,
                                    if (meter.location.isNotEmpty)
                                      meter.location,
                                  ].join(' • '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: neutral.textSecondary,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              valueCell(
                latest == null
                    ? '--'
                    : '${formatter.format(latest.value)} ${meter.unitLabel}',
                flex: 13,
              ),
              valueCell('${formatter.format(used)} ${meter.unitLabel}', flex: 13),
              valueCell(
                '${formatter.format(projected)} ${meter.unitLabel}',
                flex: 13,
              ),
              valueCell('PKR ${formatter.format(cost)}', flex: 15),
              Expanded(
                flex: 10,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (meter.isActive ? AppColors.success : neutral.divider)
                          .withOpacity(.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      meter.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        color: meter.isActive
                            ? AppColors.success
                            : neutral.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 42,
                child: PopupMenuButton<String>(
                  tooltip: 'Meter actions',
                  onSelected: (value) {
                    switch (value) {
                      case 'copy_reference':
                        onCopyReference();
                        break;
                      case 'search_online':
                        onSearchOnline();
                        break;
                      case 'edit':
                        onEdit();
                        break;
                      case 'status':
                        onToggleStatus();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'copy_reference',
                      child: Text('Copy reference'),
                    ),
                    const PopupMenuItem(
                      value: 'search_online',
                      child: Text('Search bill online'),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(
                      value: 'status',
                      child: Text(meter.isActive ? 'Deactivate' : 'Activate'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeterCard extends StatelessWidget {
  final Meter meter;
  final List<Reading> readings;
  final List<MeterTariffSlab> tariffSlabs;
  final MeterBaselineAnchor? baselineAnchor;
  final MeterInsights insights;
  final VoidCallback onOpen;
  final VoidCallback onCopyReference;
  final VoidCallback onSearchOnline;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleStatus;

  const _MeterCard({
    required this.meter,
    required this.readings,
    required this.tariffSlabs,
    required this.baselineAnchor,
    required this.insights,
    required this.onOpen,
    required this.onCopyReference,
    required this.onSearchOnline,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final color = Color(meter.colorValue);
    final projectedMonthUsage = meterProjectedMonthUsage(
      meter: meter,
      readings: readings,
      baselineAnchor: baselineAnchor,
    );
    final currentUsage = meterUnitsFromBaseline(
      meter,
      readings,
      baselineAnchor: baselineAnchor,
    );
    final progress = meter.targetUnits == null || meter.targetUnits! <= 0
        ? 0.0
        : currentUsage / meter.targetUnits!;
    final currentCost = meterCostFromBaseline(
      meter: meter,
      readings: readings,
      slabs: tariffSlabs,
      baselineAnchor: baselineAnchor,
    );
    final overUnitTarget = meter.targetUnits != null &&
        meter.targetUnits! > 0 &&
        currentUsage > meter.targetUnits!;
    final overBudget = meter.targetBudget != null &&
        meter.targetBudget! > 0 &&
        currentCost > meter.targetBudget!;
    final overTarget = overUnitTarget || overBudget;
    final latest = insights.latest;

    return Material(
      color: neutral.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: overTarget
                  ? AppColors.warning.withOpacity(0.7)
                  : neutral.divider,
            ),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      MeterCatalog.iconFor(meter.iconKey),
                      color: color,
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
                                meter.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: neutral.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (!meter.isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: neutral.divider,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Inactive',
                                  style: TextStyle(
                                    color: neutral.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                            if (meter.provider.isNotEmpty) meter.provider,
                            if (meter.location.isNotEmpty) meter.location,
                            if (meter.number.isNotEmpty) '#${meter.number}',
                          ].join(' • ').isEmpty
                              ? MeterCatalog.typeLabel(meter.meterType)
                              : [
                                  if (meter.provider.isNotEmpty) meter.provider,
                                  if (meter.location.isNotEmpty) meter.location,
                                  if (meter.number.isNotEmpty)
                                    '#${meter.number}',
                                ].join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: neutral.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if (meter.number.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onCopyReference,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 3,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Ref: ${meter.number}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: neutral.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Icon(
                                      Icons.copy_rounded,
                                      size: 15,
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded,
                        color: neutral.textSecondary),
                    onSelected: (value) {
                      switch (value) {
                        case 'copy_reference':
                          onCopyReference();
                          break;
                        case 'search_online':
                          onSearchOnline();
                          break;
                        case 'edit':
                          onEdit();
                          break;
                        case 'status':
                          onToggleStatus();
                          break;
                        case 'delete':
                          onDelete();
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      if (meter.number.trim().isNotEmpty)
                        const PopupMenuItem(
                          value: 'copy_reference',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.copy_rounded),
                            title: Text('Copy bill no'),
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit meter'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'status',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            meter.isActive
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline,
                          ),
                          title: Text(
                            meter.isActive ? 'Mark inactive' : 'Mark active',
                          ),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.delete_outline),
                          title: Text('Delete meter'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _CardMetric(
                      label: 'Latest',
                      value: latest == null
                          ? 'No reading'
                          : '${_format(latest.value)} ${meter.unitLabel}',
                    ),
                  ),
                  Expanded(
                    child: _CardMetric(
                      label: 'Used from baseline',
                      value: latest == null || meter.baseline == null
                          ? '-- ${meter.unitLabel}'
                          : '${_format(currentUsage)} ${meter.unitLabel}',
                      valueColor: Colors.red,
                    ),
                  ),
                  Expanded(
                    child: _CardMetric(
                      label: 'Est. cost',
                      value: 'PKR ${_format(currentCost)}',
                    ),
                  ),
                ],
              ),
              if (meter.targetUnits != null && meter.targetUnits! > 0) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Used ${_format(currentUsage)} / ${_format(meter.targetUnits!)} ${meter.unitLabel}',
                        style: TextStyle(
                          color: overUnitTarget
                              ? AppColors.warning
                              : neutral.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: TextStyle(
                        color: overTarget
                            ? AppColors.warning
                            : neutral.textSecondary,
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
                    minHeight: 7,
                    backgroundColor: neutral.divider,
                    valueColor: AlwaysStoppedAnimation(
                      overUnitTarget ? AppColors.warning : color,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Projected month: ${_format(projectedMonthUsage)} ${meter.unitLabel}',
                    style: TextStyle(
                      color: neutral.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.event_repeat_rounded,
                    size: 15,
                    color: neutral.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    MeterCatalog.frequencyLabel(meter.readingFrequency),
                    style: TextStyle(
                      color: neutral.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  if (latest != null)
                    Text(
                      DateFormat('dd MMM yyyy').format(latest.date),
                      style: TextStyle(
                        color: neutral.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: neutral.textDisabled,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _format(double value) {
    return NumberFormat('#,##0.##').format(value);
  }
}

class _CardMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _CardMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Column(
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
    );
  }
}

class _FilterMenu extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onSelected;

  const _FilterMenu({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onSelected,
      itemBuilder: (_) => items.entries
          .map(
            (entry) => PopupMenuItem(
              value: entry.key,
              child: Row(
                children: [
                  if (entry.key == value) ...[
                    const Icon(Icons.check_rounded, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(entry.value),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: neutral.card,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: neutral.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: neutral.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: neutral.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.arrow_drop_down_rounded,
                size: 18, color: neutral.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _EmptyMeters extends StatelessWidget {
  const _EmptyMeters({required this.hasAnyMeter, required this.onAdd});

  final bool hasAnyMeter;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.speed_rounded,
      title: hasAnyMeter ? 'No matching meters' : 'No meters added yet',
      message: hasAnyMeter
          ? 'Change your search or filters.'
          : 'Add an electricity, gas, water, solar, or sub meter to start tracking usage.',
      actionLabel: hasAnyMeter ? null : 'Add first meter',
      onAction: hasAnyMeter ? null : onAdd,
      accent: AppColors.primary,
    );
  }
}

extension _FirstOrNullExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
