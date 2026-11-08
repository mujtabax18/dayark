import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/design/responsive_layout.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_x.dart';
import '../../../../models/meter.dart';
import '../../../../services/localDatabaseServices/MeterService.dart';
import '../../../../utlis/app_router.dart';
import '../../shared/meter_catalog.dart';
import '../../meterreading/view/meterreading.dart';
import '../controller/meter_provider.dart';
import '../widgets/addMeterPopup.dart';
import '../widgets/deleteMeterDialog.dart';
import '../../../../core/widgets/common/app_empty_state.dart';
part '../widgets/meter_list_widgets.dart';

final Uri _mepcoBillSearchUri = Uri.parse('https://bill.pitc.com.pk/mepcobill');

class MeterListPage extends ConsumerStatefulWidget {
  final VoidCallback? onDesktopDashboard;

  const MeterListPage({super.key, this.onDesktopDashboard});

  @override
  ConsumerState<MeterListPage> createState() => _MeterListPageState();
}

class _MeterListPageState extends ConsumerState<MeterListPage> {
  final _searchController = TextEditingController();
  String _query = '';
  String _typeFilter = 'all';
  String _statusFilter = 'active';
  String _sort = 'usage';
  int? _selectedMeterId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final meters = ref.watch(meterProvider);
    final readingsAsync = ref.watch(meterReadingsOverviewProvider);
    final baselineAnchorsAsync =
        ref.watch(meterBaselineAnchorsOverviewProvider);
    final tariffSlabsAsync = ref.watch(meterTariffSlabsOverviewProvider);
    final readingsMap = readingsAsync.asData?.value ?? <int, List<Reading>>{};
    final baselineAnchorsMap = baselineAnchorsAsync.asData?.value ??
        <int, MeterBaselineAnchor>{};
    final tariffSlabsMap = tariffSlabsAsync.asData?.value ??
        <int, List<MeterTariffSlab>>{};
    final filteredMeters =
        _filterAndSort(meters, readingsMap, baselineAnchorsMap);

    if (MediaQuery.sizeOf(context).width >= 1100) {
      return _buildDesktopWorkspace(
        meters: meters,
        filteredMeters: filteredMeters,
        readingsMap: readingsMap,
        baselineAnchorsMap: baselineAnchorsMap,
        tariffSlabsMap: tariffSlabsMap,
        isLoading: readingsAsync.isLoading ||
            baselineAnchorsAsync.isLoading ||
            tariffSlabsAsync.isLoading,
      );
    }

    return Scaffold(
      backgroundColor: neutral.background,
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Meter Manager',
              style: TextStyle(
                color: neutral.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Track usage and control monthly cost',
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
        actions: [
          IconButton(
            onPressed: _openOnlineBillSearch,
            icon: const Icon(Icons.open_in_new_rounded),
            color: neutral.textPrimary,
            tooltip: 'Search bill online',
          ),
          IconButton(
            onPressed: () async {
              await ref.read(meterProvider.notifier).loadMeters();
                ref.invalidate(meterReadingsOverviewProvider);
              ref.invalidate(meterBaselineAnchorsOverviewProvider);
              ref.invalidate(meterTariffSlabsOverviewProvider);
            },
            icon: const Icon(Icons.refresh_rounded),
            color: neutral.textPrimary,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ResponsivePageFrame(
        maxWidth: 1280,
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(meterProvider.notifier).loadMeters();
          ref.invalidate(meterReadingsOverviewProvider);
          ref.invalidate(meterBaselineAnchorsOverviewProvider);
          ref.invalidate(meterTariffSlabsOverviewProvider);
          },
          child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _DashboardSummary(
                  meters: meters,
                  readingsMap: readingsMap,
                  baselineAnchorsMap: baselineAnchorsMap,
                  tariffSlabsMap: tariffSlabsMap,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              sliver: SliverToBoxAdapter(child: _buildSearchAndFilters()),
            ),
            if (readingsAsync.isLoading ||
                baselineAnchorsAsync.isLoading ||
                tariffSlabsAsync.isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              ),
            if (filteredMeters.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyMeters(
                  hasAnyMeter: meters.isNotEmpty,
                  onAdd: _addMeter,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                sliver: SliverList.separated(
                  itemCount: filteredMeters.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final meter = filteredMeters[index];
                    final readings = readingsMap[meter.id] ?? const <Reading>[];
                    final baselineAnchor = baselineAnchorsMap[meter.id];
                    final tariffSlabs = tariffSlabsMap[meter.id] ??
                        const <MeterTariffSlab>[];
                    final insights = meterInsightsForCurrentBaseline(
                      meter: meter,
                      readings: readings,
                      slabs: tariffSlabs,
                      baselineAnchor: baselineAnchor,
                    );
                    return _MeterCard(
                      meter: meter,
                      readings: readings,
                      tariffSlabs: tariffSlabs,
                      baselineAnchor: baselineAnchor,
                      insights: insights,
                      onOpen: () => _openMeter(meter),
                      onCopyReference: () => _copyReferenceNumber(meter),
                      onSearchOnline: _openOnlineBillSearch,
                      onEdit: () => _editMeter(meter),
                      onDelete: () => _deleteMeter(meter),
                      onToggleStatus: () async {
                        await ref
                            .read(meterProvider.notifier)
                            .toggleMeterStatus(meter);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMeter,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add meter'),
      ),
    );
  }

  Widget _buildDesktopWorkspace({
    required List<Meter> meters,
    required List<Meter> filteredMeters,
    required Map<int, List<Reading>> readingsMap,
    required Map<int, MeterBaselineAnchor> baselineAnchorsMap,
    required Map<int, List<MeterTariffSlab>> tariffSlabsMap,
    required bool isLoading,
  }) {
    final neutral = context.themeColors.neutral;
    Meter? selectedMeter;
    if (_selectedMeterId != null) {
      for (final meter in meters) {
        if (meter.id == _selectedMeterId) {
          selectedMeter = meter;
          break;
        }
      }
    }

    if (selectedMeter != null) {
      return Scaffold(
        backgroundColor: neutral.background,
        body: Row(
          children: [
            SizedBox(
              width: 286,
              child: _buildDesktopMeterNavigationPane(
                meters: filteredMeters,
                selectedMeter: selectedMeter,
                readingsMap: readingsMap,
                baselineAnchorsMap: baselineAnchorsMap,
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: neutral.divider),
            Expanded(
              child: MeterDetailPage(
                key: ValueKey('desktop-meter-${selectedMeter.id}'),
                meter: selectedMeter,
                embeddedDesktop: true,
                onBackToMeterList: () => setState(() => _selectedMeterId = null),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: neutral.background,
      body: RefreshIndicator(
        onRefresh: _refreshMeterData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(26, 22, 26, 42),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meter dashboard',
                        style: TextStyle(
                          color: neutral.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Monitor current-cycle usage, costs, readings, and billing baselines.',
                        style: TextStyle(
                          color: neutral.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _openOnlineBillSearch,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Online bill'),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Refresh meters',
                  onPressed: _refreshMeterData,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _addMeter,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add meter'),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _DesktopMeterSummary(
              meters: meters,
              readingsMap: readingsMap,
              baselineAnchorsMap: baselineAnchorsMap,
              tariffSlabsMap: tariffSlabsMap,
            ),
            const SizedBox(height: 18),
            _buildDesktopFilters(),
            if (isLoading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(minHeight: 2),
            ],
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: neutral.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: neutral.divider),
              ),
              clipBehavior: Clip.antiAlias,
              child: filteredMeters.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 52),
                      child: _EmptyMeters(
                        hasAnyMeter: meters.isNotEmpty,
                        onAdd: _addMeter,
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final tableWidth = constraints.maxWidth < 900
                            ? 900.0
                            : constraints.maxWidth;
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: tableWidth,
                            child: Column(
                              children: [
                                _DesktopMeterTableHeader(),
                                for (var index = 0;
                                    index < filteredMeters.length;
                                    index++) ...[
                                  if (index > 0)
                                    Divider(height: 1, color: neutral.divider),
                                  Builder(
                                    builder: (context) {
                                      final meter = filteredMeters[index];
                                      final readings = readingsMap[meter.id] ??
                                          const <Reading>[];
                                      final baselineAnchor =
                                          baselineAnchorsMap[meter.id];
                                      final tariffSlabs =
                                          tariffSlabsMap[meter.id] ??
                                              const <MeterTariffSlab>[];
                                      return _DesktopMeterRow(
                                        meter: meter,
                                        readings: readings,
                                        tariffSlabs: tariffSlabs,
                                        baselineAnchor: baselineAnchor,
                                        onOpen: () => _openMeter(meter),
                                        onCopyReference: () =>
                                            _copyReferenceNumber(meter),
                                        onSearchOnline: _openOnlineBillSearch,
                                        onEdit: () => _editMeter(meter),
                                        onDelete: () => _deleteMeter(meter),
                                        onToggleStatus: () async {
                                          await ref
                                              .read(meterProvider.notifier)
                                              .toggleMeterStatus(meter);
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopMeterNavigationPane({
    required List<Meter> meters,
    required Meter selectedMeter,
    required Map<int, List<Reading>> readingsMap,
    required Map<int, MeterBaselineAnchor> baselineAnchorsMap,
  }) {
    final neutral = context.themeColors.neutral;
    return ColoredBox(
      color: neutral.card,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back to meter list',
                      onPressed: () => setState(() => _selectedMeterId = null),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Meters',
                            style: TextStyle(
                              color: neutral.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${meters.length} shown',
                            style: TextStyle(
                              color: neutral.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Dashboard',
                      onPressed: _openDashboardFromDesktop,
                      icon: const Icon(Icons.dashboard_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value.trim()),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search meters',
                    prefixIcon: const Icon(Icons.search_rounded, size: 19),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                    filled: true,
                    fillColor: neutral.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: neutral.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: neutral.divider),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: neutral.divider),
          Expanded(
            child: meters.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'No meters match the current filters.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: neutral.textSecondary),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 18),
                    itemCount: meters.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final meter = meters[index];
                      final readings = readingsMap[meter.id] ?? const <Reading>[];
                      final used = meterUnitsFromBaseline(
                        meter,
                        readings,
                        baselineAnchor: baselineAnchorsMap[meter.id],
                      );
                      final selected = meter.id == selectedMeter.id;
                      return Material(
                        color: selected
                            ? AppColors.primary.withOpacity(.10)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () => _openMeter(meter),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: Color(meter.colorValue).withOpacity(.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    MeterCatalog.iconFor(meter.iconKey),
                                    size: 18,
                                    color: Color(meter.colorValue),
                                  ),
                                ),
                                const SizedBox(width: 9),
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
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${NumberFormat('#,##0.##').format(used)} ${meter.unitLabel} used',
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
                                if (selected)
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.primary,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addMeter,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add meter'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopFilters() {
    final neutral = context.themeColors.neutral;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: neutral.divider),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final filters = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FilterMenu(
                label: _statusFilter == 'all'
                    ? 'All status'
                    : _statusFilter == 'active'
                        ? 'Active'
                        : 'Inactive',
                icon: Icons.toggle_on_outlined,
                value: _statusFilter,
                items: const {
                  'active': 'Active',
                  'inactive': 'Inactive',
                  'all': 'All status',
                },
                onSelected: (value) => setState(() => _statusFilter = value),
              ),
              const SizedBox(width: 8),
              _FilterMenu(
                label: _typeFilter == 'all'
                    ? 'All types'
                    : MeterCatalog.typeLabel(_typeFilter),
                icon: Icons.category_outlined,
                value: _typeFilter,
                items: {
                  'all': 'All types',
                  for (final type in MeterCatalog.types) type.key: type.label,
                },
                onSelected: (value) => setState(() => _typeFilter = value),
              ),
              const SizedBox(width: 8),
              _FilterMenu(
                label: _sort == 'name'
                    ? 'Name'
                    : _sort == 'usage'
                        ? 'Most used'
                        : 'Recently read',
                icon: Icons.sort_rounded,
                value: _sort,
                items: const {
                  'usage': 'Most used',
                  'recent': 'Recently read',
                  'name': 'Name',
                },
                onSelected: (value) => setState(() => _sort = value),
              ),
            ],
          );

          final search = TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value.trim()),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search meter, number, provider or location',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: neutral.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: neutral.divider),
              ),
            ),
          );

          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                search,
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: filters,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 10),
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: filters,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _refreshMeterData() async {
    await ref.read(meterProvider.notifier).loadMeters();
    ref.invalidate(meterReadingsOverviewProvider);
    ref.invalidate(meterBaselineAnchorsOverviewProvider);
    ref.invalidate(meterTariffSlabsOverviewProvider);
  }

  void _openDashboardFromDesktop() {
    final callback = widget.onDesktopDashboard;
    if (callback != null) {
      callback();
      return;
    }
    context.go(RoutesStr.home);
  }

  Widget _buildSearchAndFilters() {
    final neutral = context.themeColors.neutral;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value.trim()),
          decoration: InputDecoration(
            hintText: 'Search meter, number, provider or location',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
            filled: true,
            fillColor: neutral.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: neutral.divider),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterMenu(
                label: _statusFilter == 'all'
                    ? 'All status'
                    : _statusFilter == 'active'
                        ? 'Active'
                        : 'Inactive',
                icon: Icons.toggle_on_outlined,
                value: _statusFilter,
                items: const {
                  'active': 'Active',
                  'inactive': 'Inactive',
                  'all': 'All status',
                },
                onSelected: (value) => setState(() => _statusFilter = value),
              ),
              const SizedBox(width: 8),
              _FilterMenu(
                label: _typeFilter == 'all'
                    ? 'All types'
                    : MeterCatalog.typeLabel(_typeFilter),
                icon: Icons.category_outlined,
                value: _typeFilter,
                items: {
                  'all': 'All types',
                  for (final type in MeterCatalog.types) type.key: type.label,
                },
                onSelected: (value) => setState(() => _typeFilter = value),
              ),
              const SizedBox(width: 8),
              _FilterMenu(
                label: _sort == 'name'
                    ? 'Name'
                    : _sort == 'usage'
                        ? 'Most used'
                        : 'Recently read',
                icon: Icons.sort_rounded,
                value: _sort,
                items: const {
                  'usage': 'Most used',
                  'recent': 'Recently read',
                  'name': 'Name',
                },
                onSelected: (value) => setState(() => _sort = value),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Meter> _filterAndSort(
    List<Meter> meters,
    Map<int, List<Reading>> readingsMap,
    Map<int, MeterBaselineAnchor> baselineAnchorsMap,
  ) {
    final normalizedQuery = _query.toLowerCase();
    final filtered = meters.where((meter) {
      final matchesStatus = _statusFilter == 'all' ||
          (_statusFilter == 'active' && meter.isActive) ||
          (_statusFilter == 'inactive' && !meter.isActive);
      final matchesType =
          _typeFilter == 'all' || meter.meterType == _typeFilter;
      final searchable = [
        meter.name,
        meter.number,
        meter.referenceNumber,
        meter.provider,
        meter.location,
        meter.consumerName,
      ].join(' ').toLowerCase();
      return matchesStatus &&
          matchesType &&
          (normalizedQuery.isEmpty || searchable.contains(normalizedQuery));
    }).toList();

    switch (_sort) {
      case 'usage':
        filtered.sort((a, b) {
          final usageComparison = _usedUnitsFor(
            b,
            readingsMap[b.id] ?? const <Reading>[],
            baselineAnchorsMap[b.id],
          ).compareTo(
            _usedUnitsFor(
              a,
              readingsMap[a.id] ?? const <Reading>[],
              baselineAnchorsMap[a.id],
            ),
          );
          if (usageComparison != 0) return usageComparison;

          final aDate =
              (readingsMap[a.id] ?? const <Reading>[]).firstOrNull?.date;
          final bDate =
              (readingsMap[b.id] ?? const <Reading>[]).firstOrNull?.date;
          if (aDate != null && bDate != null) {
            final dateComparison = bDate.compareTo(aDate);
            if (dateComparison != 0) return dateComparison;
          } else if (aDate == null && bDate != null) {
            return 1;
          } else if (aDate != null && bDate == null) {
            return -1;
          }

          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
      case 'recent':
        filtered.sort((a, b) {
          final aDate =
              (readingsMap[a.id] ?? const <Reading>[]).firstOrNull?.date;
          final bDate =
              (readingsMap[b.id] ?? const <Reading>[]).firstOrNull?.date;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });
        break;
      default:
        filtered.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    }
    return filtered;
  }

  double _usedUnitsFor(
    Meter meter,
    List<Reading> readings,
    MeterBaselineAnchor? baselineAnchor,
  ) {
    return meterUnitsFromBaseline(
      meter,
      readings,
      baselineAnchor: baselineAnchor,
    );
  }

  Future<void> _copyReferenceNumber(Meter meter) async {
    final meterNumber = meter.number.trim();
    if (meterNumber.isEmpty) {
      _showMessage('No reference number is saved for this bill.');
      return;
    }

    await Clipboard.setData(ClipboardData(text: meterNumber));
    if (!mounted) return;
    _showMessage('Reference number copied: $meterNumber');
  }

  Future<void> _openOnlineBillSearch() async {
    try {
      final opened = await launchUrl(
        _mepcoBillSearchUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        _showMessage('Could not open the MEPCO bill website.');
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Could not open the MEPCO bill website.');
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addMeter() async {
    final meter = await showMeterFormSheet(context: context);
    if (meter == null || !mounted) return;
    await ref.read(meterProvider.notifier).addMeter(meter);
    ref.invalidate(meterReadingsOverviewProvider);
    ref.invalidate(meterBaselineAnchorsOverviewProvider);
    ref.invalidate(meterTariffSlabsOverviewProvider);
  }

  Future<void> _editMeter(Meter meter) async {
    final updated = await showMeterFormSheet(context: context, meter: meter);
    if (updated == null || !mounted) return;
    await ref.read(meterProvider.notifier).updateMeter(updated);
    ref.invalidate(meterReadingsOverviewProvider);
    ref.invalidate(meterBaselineAnchorsOverviewProvider);
    ref.invalidate(meterTariffSlabsOverviewProvider);
  }

  Future<void> _deleteMeter(Meter meter) async {
    final confirmed = await showDeleteMeterDialog(
      context,
      meter.name,
      () {},
    );
    if (!confirmed || !mounted) return;
    await ref.read(meterProvider.notifier).deleteMeter(meter.id);
    if (_selectedMeterId == meter.id && mounted) {
      setState(() => _selectedMeterId = null);
    }
    ref.invalidate(meterReadingsOverviewProvider);
    ref.invalidate(meterBaselineAnchorsOverviewProvider);
    ref.invalidate(meterTariffSlabsOverviewProvider);
  }

  Future<void> _openMeter(Meter meter) async {
    if (MediaQuery.sizeOf(context).width >= 1100) {
      setState(() => _selectedMeterId = meter.id);
      return;
    }

    await context.push(RoutesStr.meterReading, extra: meter);
    if (!mounted) return;
    await _refreshMeterData();
  }
}
