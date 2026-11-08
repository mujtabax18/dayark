import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_x.dart';
import '../../../../models/meter.dart';
import '../../MeterList/controller/meter_provider.dart';
import '../../MeterList/widgets/addMeterPopup.dart';
import '../../shared/meter_catalog.dart';
import '../controller/meter_detail_provider.dart';
import '../widgets/AddReadingWidget.dart';
import '../widgets/TariffSetupSheet.dart';
import '../widgets/deletereading.dart';
import '../../../../core/widgets/common/app_empty_state.dart';
import '../../../navigation/widgets/desktop_content_frame.dart';
part '../widgets/meter_summary_widgets.dart';
part '../widgets/meter_detail_widgets.dart';

class MeterDetailPage extends ConsumerWidget {
  final Meter meter;
  final bool embeddedDesktop;
  final VoidCallback? onBackToMeterList;

  const MeterDetailPage({
    super.key,
    required this.meter,
    this.embeddedDesktop = false,
    this.onBackToMeterList,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(meterDetailProvider(meter));
    final notifier = ref.read(meterDetailProvider(meter).notifier);
    final neutral = context.themeColors.neutral;
    final currentMeter = state.meter;
    final insights = meterInsightsForCurrentBaseline(
      meter: currentMeter,
      readings: state.readings,
      slabs: state.tariffSlabs,
      baselineAnchor: state.baselineAnchor,
    );
    final projectedMonthUsage = meterProjectedMonthUsage(
      meter: currentMeter,
      readings: state.readings,
      baselineAnchor: state.baselineAnchor,
    );
    final currentEstimatedCost = meterCostFromBaseline(
      meter: currentMeter,
      readings: state.readings,
      slabs: state.tariffSlabs,
      baselineAnchor: state.baselineAnchor,
    );
    final baselineDate = meterBaselineDate(
      currentMeter,
      state.readings,
      baselineAnchor: state.baselineAnchor,
    );
    final currentUsage = meterUnitsFromBaseline(
      currentMeter,
      state.readings,
      baselineAnchor: state.baselineAnchor,
    );
    final isOverUnitTarget = currentMeter.targetUnits != null &&
        currentMeter.targetUnits! > 0 &&
        currentUsage > currentMeter.targetUnits!;
    final isOverBudget = currentMeter.targetBudget != null &&
        currentMeter.targetBudget! > 0 &&
        currentEstimatedCost > currentMeter.targetBudget!;
    final desktopEmbedded =
        embeddedDesktop && MediaQuery.sizeOf(context).width >= 1100;

    Widget warningBanner() {
      if (!isOverUnitTarget && !isOverBudget) return const SizedBox.shrink();
      return _MessageBanner(
        icon: Icons.warning_amber_rounded,
        text: _targetWarning(
          currentMeter,
          isOverUnitTarget: isOverUnitTarget,
          isOverBudget: isOverBudget,
        ),
        color: AppColors.warning,
      );
    }

    Widget readingHistory() {
      if (state.readings.isEmpty) {
        return _EmptyReadings(
          onAdd: () => _addReading(context, ref, notifier, state),
        );
      }

      return Column(
        children: List.generate(state.readings.length, (index) {
          final reading = state.readings[index];
          final previous =
              index + 1 < state.readings.length ? state.readings[index + 1] : null;
          return _ReadingCard(
            meter: currentMeter,
            reading: reading,
            previousReading: previous,
            tariffSlabs: state.tariffSlabs,
            isBaseline: isMeterBaselineReading(
              currentMeter,
              state.readings,
              reading,
              baselineAnchor: state.baselineAnchor,
            ),
            baselineDate: baselineDate,
            onEdit: () => _editReading(
              context,
              ref,
              notifier,
              state,
              reading,
            ),
            onSetBaseline: () => _setBaseline(ref, notifier, reading),
            onDelete: () => _deleteReading(
              context,
              ref,
              notifier,
              reading,
            ),
          );
        }),
      );
    }

    Widget statusMessages() {
      return Column(
        children: [
          if (state.isLoading) ...[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 10),
          ],
          if (state.error != null) ...[
            _MessageBanner(
              icon: Icons.error_outline_rounded,
              text: state.error!,
              color: AppColors.danger,
            ),
            const SizedBox(height: 12),
          ],
        ],
      );
    }

    Widget mobileList() {
      return RefreshIndicator(
        onRefresh: notifier.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
          children: [
            statusMessages(),
            _MeterHeroCard(
              meter: currentMeter,
              insights: insights,
              projectedMonthUsage: projectedMonthUsage,
              estimatedCost: currentEstimatedCost,
            ),
            if (isOverUnitTarget || isOverBudget) ...[
              const SizedBox(height: 12),
              warningBanner(),
            ],
            const SizedBox(height: 16),
            _InsightsGrid(meter: currentMeter, insights: insights),
            const SizedBox(height: 20),
            _SectionHeader(
              title: 'Usage trend',
              subtitle: 'Consumption between recent readings',
              trailing: Text(
                '${state.readings.length} readings',
                style: TextStyle(
                  color: neutral.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _UsageTrendChart(
              meter: currentMeter,
              readings: state.readings,
            ),
            const SizedBox(height: 20),
            _MeterDetailsCard(
              meter: currentMeter,
              tariffSlabs: state.tariffSlabs,
              onEditTariff: () => _editTariffs(
                context,
                ref,
                notifier,
                currentMeter,
                state.tariffSlabs,
              ),
            ),
            const SizedBox(height: 22),
            _SectionHeader(
              title: 'Reading history',
              subtitle: 'Tap a reading to edit it',
              trailing: TextButton.icon(
                onPressed: () => _addReading(context, ref, notifier, state),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
              ),
            ),
            const SizedBox(height: 8),
            readingHistory(),
          ],
        ),
      );
    }

    Widget desktopList() {
      return RefreshIndicator(
        onRefresh: notifier.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 40),
          children: [
            statusMessages(),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 820;
                final primary = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MeterHeroCard(
                      meter: currentMeter,
                      insights: insights,
                      projectedMonthUsage: projectedMonthUsage,
                      estimatedCost: currentEstimatedCost,
                    ),
                    if (isOverUnitTarget || isOverBudget) ...[
                      const SizedBox(height: 12),
                      warningBanner(),
                    ],
                    const SizedBox(height: 14),
                    _InsightsGrid(meter: currentMeter, insights: insights),
                  ],
                );
                final secondary = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionHeader(
                      title: 'Usage trend',
                      subtitle: 'Consumption between recent readings',
                      trailing: Text(
                        '${state.readings.length} readings',
                        style: TextStyle(
                          color: neutral.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _UsageTrendChart(
                      meter: currentMeter,
                      readings: state.readings,
                    ),
                    const SizedBox(height: 14),
                    _MeterDetailsCard(
                      meter: currentMeter,
                      tariffSlabs: state.tariffSlabs,
                      onEditTariff: () => _editTariffs(
                        context,
                        ref,
                        notifier,
                        currentMeter,
                        state.tariffSlabs,
                      ),
                    ),
                  ],
                );

                if (!twoColumns) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      primary,
                      const SizedBox(height: 22),
                      secondary,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 11, child: primary),
                    const SizedBox(width: 18),
                    Expanded(flex: 9, child: secondary),
                  ],
                );
              },
            ),
            const SizedBox(height: 28),
            _SectionHeader(
              title: 'Reading history',
              subtitle: 'Review, edit, or change the active bill baseline',
              trailing: FilledButton.icon(
                onPressed: () => _addReading(context, ref, notifier, state),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add reading'),
              ),
            ),
            const SizedBox(height: 10),
            readingHistory(),
          ],
        ),
      );
    }

    if (desktopEmbedded) {
      return ColoredBox(
        color: neutral.background,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              decoration: BoxDecoration(
                color: neutral.card,
                border: Border(bottom: BorderSide(color: neutral.divider)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compactHeader = constraints.maxWidth < 760;

                  Widget compactAction({
                    required String tooltip,
                    required IconData icon,
                    required VoidCallback onPressed,
                  }) {
                    return IconButton(
                      tooltip: tooltip,
                      onPressed: onPressed,
                      icon: Icon(icon),
                    );
                  }

                  return Row(
                    children: [
                      if (onBackToMeterList != null) ...[
                        IconButton(
                          tooltip: 'Back to meter list',
                          onPressed: onBackToMeterList,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        if (!compactHeader) const SizedBox(width: 6),
                      ],
                      if (!compactHeader) ...[
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Color(currentMeter.colorValue).withOpacity(.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            MeterCatalog.iconFor(currentMeter.iconKey),
                            color: Color(currentMeter.colorValue),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentMeter.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: neutral.textPrimary,
                                fontSize: compactHeader ? 16 : 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              [
                                if (currentMeter.provider.isNotEmpty)
                                  currentMeter.provider,
                                MeterCatalog.typeLabel(currentMeter.meterType),
                                if (!compactHeader &&
                                    currentMeter.location.isNotEmpty)
                                  currentMeter.location,
                              ].join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: neutral.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (compactHeader) ...[
                        compactAction(
                          tooltip: 'Edit meter',
                          icon: Icons.edit_outlined,
                          onPressed: () =>
                              _editMeter(context, ref, notifier, currentMeter),
                        ),
                        compactAction(
                          tooltip: 'Tariff slabs',
                          icon: Icons.price_change_outlined,
                          onPressed: () => _editTariffs(
                            context,
                            ref,
                            notifier,
                            currentMeter,
                            state.tariffSlabs,
                          ),
                        ),
                      ] else ...[
                        OutlinedButton.icon(
                          onPressed: () =>
                              _editMeter(context, ref, notifier, currentMeter),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _editTariffs(
                            context,
                            ref,
                            notifier,
                            currentMeter,
                            state.tariffSlabs,
                          ),
                          icon: const Icon(Icons.price_change_outlined, size: 18),
                          label: const Text('Tariff'),
                        ),
                      ],
                      if (insights.latest != null)
                        PopupMenuButton<String>(
                          tooltip: 'More meter actions',
                          onSelected: (value) async {
                            if (value == 'baseline') {
                              await _setBaseline(ref, notifier, insights.latest!);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'baseline',
                              child: Row(
                                children: [
                                  Icon(Icons.flag_outlined),
                                  SizedBox(width: 10),
                                  Text('Use latest as baseline'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(width: 4),
                      if (compactHeader)
                        compactAction(
                          tooltip: 'Add reading',
                          icon: Icons.add_circle_outline_rounded,
                          onPressed: () =>
                              _addReading(context, ref, notifier, state),
                        )
                      else
                        FilledButton.icon(
                          onPressed: () =>
                              _addReading(context, ref, notifier, state),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add reading'),
                        ),
                    ],
                  );
                },
              ),
            ),
            Expanded(child: desktopList()),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: neutral.background,
      appBar: AppBar(
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currentMeter.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: neutral.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              [
                if (currentMeter.provider.isNotEmpty) currentMeter.provider,
                MeterCatalog.typeLabel(currentMeter.meterType),
              ].join(' • '),
              style: TextStyle(
                color: neutral.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        backgroundColor: neutral.background,
        elevation: 0,
        iconTheme: IconThemeData(color: neutral.textPrimary),
        actions: [
          IconButton(
            tooltip: 'Edit meter',
            onPressed: () => _editMeter(context, ref, notifier, currentMeter),
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'tariff':
                  await _editTariffs(
                    context,
                    ref,
                    notifier,
                    currentMeter,
                    state.tariffSlabs,
                  );
                  break;
                case 'baseline':
                  if (insights.latest != null) {
                    await _setBaseline(ref, notifier, insights.latest!);
                  }
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'tariff',
                child: Row(
                  children: [
                    Icon(Icons.price_change_outlined),
                    SizedBox(width: 10),
                    Text('Tariff slabs'),
                  ],
                ),
              ),
              if (insights.latest != null)
                const PopupMenuItem(
                  value: 'baseline',
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined),
                      SizedBox(width: 10),
                      Text('Use latest as baseline'),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: DesktopContentFrame(child: mobileList()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addReading(context, ref, notifier, state),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add reading'),
      ),
    );
  }

  static Future<void> _editMeter(
    BuildContext context,
    WidgetRef ref,
    MeterDetailNotifier notifier,
    Meter meter,
  ) async {
    final updated = await showMeterFormSheet(context: context, meter: meter);
    if (updated == null) return;
    await notifier.updateMeter(updated);
    await ref.read(meterProvider.notifier).loadMeters();
    ref.invalidate(meterReadingsOverviewProvider);
    ref.invalidate(meterBaselineAnchorsOverviewProvider);
    ref.invalidate(meterTariffSlabsOverviewProvider);
  }

  static Future<void> _setBaseline(
    WidgetRef ref,
    MeterDetailNotifier notifier,
    Reading baselineReading,
  ) async {
    await notifier.setBaseline(baselineReading);
    await ref.read(meterProvider.notifier).loadMeters();
    ref.invalidate(meterReadingsOverviewProvider);
    ref.invalidate(meterBaselineAnchorsOverviewProvider);
    ref.invalidate(meterTariffSlabsOverviewProvider);
  }

  static Future<void> _editTariffs(
    BuildContext context,
    WidgetRef ref,
    MeterDetailNotifier notifier,
    Meter meter,
    List<MeterTariffSlab> slabs,
  ) async {
    final result = await showTariffSetupSheet(
      context: context,
      meter: meter,
      slabs: slabs,
    );
    if (result == null) return;
    await notifier.replaceTariffSlabs(result);
    await ref.read(meterProvider.notifier).loadMeters();
    ref.invalidate(meterReadingsOverviewProvider);
    ref.invalidate(meterTariffSlabsOverviewProvider);
  }

  static Future<void> _addReading(
    BuildContext context,
    WidgetRef ref,
    MeterDetailNotifier notifier,
    MeterDetailState state,
  ) async {
    final newReading = await showReadingFormSheet(
      context: context,
      meter: state.meter,
      tariffSlabs: state.tariffSlabs,
      readings: state.readings,
      baselineAnchor: state.baselineAnchor,
    );
    if (newReading == null) return;

    final insertedReading = await notifier.addReading(newReading);
    if (state.meter.baseline == null && state.readings.isEmpty) {
      await notifier.setBaseline(insertedReading);
    }
    await ref.read(meterProvider.notifier).loadMeters();
    ref.invalidate(meterReadingsOverviewProvider);
    ref.invalidate(meterBaselineAnchorsOverviewProvider);
    ref.invalidate(meterTariffSlabsOverviewProvider);
  }

  static Future<void> _editReading(
    BuildContext context,
    WidgetRef ref,
    MeterDetailNotifier notifier,
    MeterDetailState state,
    Reading reading,
  ) async {
    final updated = await showReadingFormSheet(
      context: context,
      meter: state.meter,
      tariffSlabs: state.tariffSlabs,
      readings: state.readings,
      baselineAnchor: state.baselineAnchor,
      reading: reading,
    );
    if (updated == null) return;
    final wasBaseline = isMeterBaselineReading(
      state.meter,
      state.readings,
      reading,
      baselineAnchor: state.baselineAnchor,
    );

    await notifier.updateReading(updated);
    if (wasBaseline) {
      await notifier.setBaseline(updated);
    }
    await ref.read(meterProvider.notifier).loadMeters();
    ref.invalidate(meterReadingsOverviewProvider);
    ref.invalidate(meterBaselineAnchorsOverviewProvider);
  }

  static Future<void> _deleteReading(
    BuildContext context,
    WidgetRef ref,
    MeterDetailNotifier notifier,
    Reading reading,
  ) async {
    final confirmed = await showDeleteReadingDialog(
      context,
      reading.value,
      () {},
    );
    if (!confirmed) return;
    await notifier.deleteReading(reading.id);
    await ref.read(meterProvider.notifier).loadMeters();
    ref.invalidate(meterReadingsOverviewProvider);
    ref.invalidate(meterBaselineAnchorsOverviewProvider);
  }

  static String _targetWarning(
    Meter meter, {
    required bool isOverUnitTarget,
    required bool isOverBudget,
  }) {
    if (isOverUnitTarget && isOverBudget) {
      return 'Current usage and current bill cost are above your monthly targets. Reduce consumption to regain control.';
    }
    if (isOverUnitTarget) {
      return 'Current usage is above your ${_format(meter.targetUnits!)} ${meter.unitLabel} monthly target.';
    }
    return 'Current estimated bill cost is above your PKR ${_format(meter.targetBudget!)} budget.';
  }

  static String _format(double value) => NumberFormat('#,##0.##').format(value);
}
