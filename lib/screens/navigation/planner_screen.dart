import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/design/app_tokens.dart';
import '../../core/design/responsive_layout.dart';
import '../../core/widgets/common/app_surface.dart';
import '../../models/dashboard_summary.dart';
import '../../utlis/app_router.dart';
import '../HomeScreen/controller/dashboard_provider.dart';
import 'widgets/desktop_navigation_scope.dart';
import 'widgets/section_landing_widgets.dart';

class PlannerScreen extends ConsumerWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(homeDashboardProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ResponsivePageFrame(
          maxWidth: 1440,
          child: RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: CustomScrollView(
            key: const PageStorageKey<String>('planner-section-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                sliver: SliverToBoxAdapter(
                  child: LandingHeader(
                    title: 'Planner',
                    subtitle: 'Today’s habits, household tasks and reminders',
                    onRefresh: () => _refresh(ref),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                sliver: SliverToBoxAdapter(
                  child: summary.when(
                    data: (data) => _TodayOverview(summary: data),
                    loading: () => const _LoadingCard(height: 150),
                    error: (_, __) => _ErrorCard(
                      onRetry: () => ref.invalidate(homeDashboardProvider),
                    ),
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
                sliver: SliverToBoxAdapter(
                  child: LandingSectionTitle(
                    title: 'Planner tools',
                    subtitle: 'Open each existing module for full details.',
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                sliver: SliverToBoxAdapter(
                  child: LandingFeatureGrid(
                    features: [
                      LandingFeature(
                        title: 'Habits',
                        subtitle: 'Daily progress',
                        icon: Icons.track_changes_rounded,
                        color: const Color(0xFF8B5CF6),
                        onTap: () => _openModule(context, ref, RoutesStr.habits),
                      ),
                      LandingFeature(
                        title: 'Grocery & chores',
                        subtitle: 'Household tasks',
                        icon: Icons.shopping_basket_outlined,
                        color: const Color(0xFF22C55E),
                        onTap: () => _openModule(context, ref, RoutesStr.grocery),
                      ),
                      LandingFeature(
                        title: 'Diary',
                        subtitle: 'Personal entries',
                        icon: Icons.menu_book_outlined,
                        color: const Color(0xFFEC4899),
                        onTap: () => _openModule(context, ref, RoutesStr.moodTracker),
                      ),
                      LandingFeature(
                        title: 'Meter usage',
                        subtitle: 'Readings and baseline',
                        icon: Icons.electric_meter_outlined,
                        color: const Color(0xFF4F46E5),
                        onTap: () => _openModule(context, ref, RoutesStr.meterList),
                      ),
                      LandingFeature(
                        title: 'Pill reminder',
                        subtitle: 'Medicine schedule',
                        icon: Icons.medication_outlined,
                        color: const Color(0xFF14B8A6),
                        onTap: () => _openModule(context, ref, RoutesStr.pillReminder),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
                sliver: SliverToBoxAdapter(
                  child: LandingSectionTitle(
                    title: 'Today',
                    subtitle: 'Live information from your local records.',
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  context.mainShellBottomPadding,
                ),
                sliver: SliverToBoxAdapter(
                  child: _PlannerStatusList(summary: summary.asData?.value),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openModule(
    BuildContext context,
    WidgetRef ref,
    String route,
  ) async {
    await openResponsiveModule(context, route);
    ref.invalidate(homeDashboardProvider);
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(homeDashboardProvider);
    try {
      await ref.read(homeDashboardProvider.future);
    } catch (_) {
      // The overview card displays its own retry state.
    }
  }
}

class _TodayOverview extends StatelessWidget {
  const _TodayOverview({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalTasks = summary.habits.due + summary.grocery.totalRemaining;
    final completed = summary.habits.completed + summary.pills.taken;

    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: AppRadius.large,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: AppRadius.small,
                ),
                child: Icon(
                  Icons.today_rounded,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, d MMMM').format(DateTime.now()),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(
                      '$totalTasks open task${totalTasks == 1 ? '' : 's'} across habits and home planning',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OverviewMetric(
                  label: 'Habits done',
                  value: '${summary.habits.completed}/${summary.habits.total}',
                  icon: Icons.task_alt_rounded,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OverviewMetric(
                  label: 'Household tasks',
                  value: '${summary.grocery.totalRemaining}',
                  icon: Icons.home_work_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OverviewMetric(
                  label: 'Medicines taken',
                  value: '${summary.pills.taken}',
                  icon: Icons.medication_rounded,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OverviewMetric(
                  label: 'Completed updates',
                  value: '$completed',
                  icon: Icons.done_all_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlannerStatusList extends StatelessWidget {
  const _PlannerStatusList({required this.summary});

  final DashboardSummary? summary;

  @override
  Widget build(BuildContext context) {
    final data = summary;
    final nextHabit = _firstWhereOrNull<HabitHomeItem>(
      data?.habits.items ?? const <HabitHomeItem>[],
      (item) => !item.isCompleted,
    );
    final nextGrocery = _firstWhereOrNull<GroceryHomeEntry>(
      data?.grocery.entries ?? const <GroceryHomeEntry>[],
      (_) => true,
    );
    final nextPill = _firstWhereOrNull<PillHomeOccurrence>(
      data?.pills.occurrences ?? const <PillHomeOccurrence>[],
      (item) => item.status != 'TAKEN',
    );
    final meter = _firstWhereOrNull<MeterHomeItem>(
      data?.meters.items ?? const <MeterHomeItem>[],
      (_) => true,
    );

    final items = <_PlannerStatus>[
      _PlannerStatus(
        title: 'Habits',
        value: data == null
            ? '—'
            : '${(data.habits.completionRate * 100).round()}%',
        subtitle: nextHabit == null
            ? 'No pending habit for today'
            : '${nextHabit.title} • ${nextHabit.currentStreak} day streak',
        icon: Icons.track_changes_rounded,
        color: const Color(0xFF8B5CF6),
      ),
      _PlannerStatus(
        title: 'Grocery & chores',
        value: data == null ? '—' : '${data.grocery.totalRemaining}',
        subtitle: nextGrocery == null
            ? 'Nothing pending'
            : '${nextGrocery.title}${nextGrocery.isOverdue ? ' • overdue' : ''}',
        icon: Icons.shopping_basket_outlined,
        color: const Color(0xFF22C55E),
      ),
      _PlannerStatus(
        title: 'Pill reminders',
        value: data == null ? '—' : '${data.pills.pending}',
        subtitle: nextPill == null
            ? 'No pending dose'
            : '${nextPill.pillName} • ${nextPill.scheduledTime}',
        icon: Icons.medication_outlined,
        color: const Color(0xFF14B8A6),
      ),
      _PlannerStatus(
        title: 'Meter usage',
        value: data == null
            ? '—'
            : NumberFormat.compact().format(data.meters.totalUnitsUsed),
        subtitle: meter == null
            ? 'Add a meter and baseline reading'
            : '${meter.name} • ${NumberFormat.compact().format(meter.unitsUsed)} ${meter.unitLabel}',
        icon: Icons.electric_meter_outlined,
        color: const Color(0xFF4F46E5),
      ),
    ];

    return AppSurface(
      padding: EdgeInsets.zero,
      borderRadius: AppRadius.large,
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _PlannerStatusRow(item: items[index]),
            if (index != items.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _PlannerStatusRow extends StatelessWidget {
  const _PlannerStatusRow({required this.item});

  final _PlannerStatus item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: item.color.withOpacity(.12),
              borderRadius: AppRadius.small,
            ),
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Text(
            item.value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _PlannerStatus {
  const _PlannerStatus({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: SizedBox(
        height: height,
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(child: Text('Planner summary is unavailable.')),
          IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh)),
        ],
      ),
    );
  }
}

T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T value) test) {
  for (final value in values) {
    if (test(value)) return value;
  }
  return null;
}
