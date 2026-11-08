import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../utlis/app_router.dart';
import '../../pill_form/view/pill_form_screen.dart';
import '../../shared/pill_ui_helpers.dart';
import '../../shared/pill_desktop_navigation.dart';
import '../controller/pill_home_controller.dart';
import '../controller/pill_home_state.dart';
import '../provider/pill_home_provider.dart';
import '../../../navigation/widgets/desktop_content_frame.dart';
part '../widgets/pill_home_summary_widgets.dart';
part '../widgets/pill_home_schedule_widgets.dart';

class PillHomeScreen extends ConsumerWidget {
  const PillHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = ref.watch(pillHomeControllerProvider);
    final controller = ref.read(pillHomeControllerProvider.notifier);
    final desktopNav = PillDesktopNavigationScope.maybeOf(context);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Medicine reminder',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Stay on track with every dose',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton.filled(
            tooltip: 'Add medicine',
            onPressed: () async {
              if (desktopNav != null) {
                desktopNav.onOpenMedicineForm(null);
                return;
              }
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PillFormScreen()),
              );
              await controller.loadHome();
            },
            icon: const Icon(
              Icons.add_rounded,
              color: Colors.white,
            ),
          ),
          if (desktopNav == null) ...[
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              tooltip: 'More options',
              onSelected: (value) async {
                if (value == 'medicines') {
                  await context.push(RoutesStr.pillReminderPillList);
                } else if (value == 'profiles') {
                  await context.push(RoutesStr.pillReminderProfile);
                } else {
                  await context.push(RoutesStr.pillReminderSetting);
                }
                await controller.loadHome();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'medicines',
                  child: _MenuItem(
                    icon: Icons.medication_outlined,
                    label: 'My medicines',
                  ),
                ),
                PopupMenuItem(
                  value: 'profiles',
                  child: _MenuItem(
                    icon: Icons.people_outline_rounded,
                    label: 'Profiles',
                  ),
                ),
                PopupMenuItem(
                  value: 'settings',
                  child: _MenuItem(
                    icon: Icons.tune_rounded,
                    label: 'Pill settings',
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: DesktopContentFrame(
        child: state.isLoading && state.weekOccurrences.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: controller.loadHome,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
                    sliver: SliverList.list(
                      children: [
                        if (state.profiles.length > 1) ...[
                          _ProfileSelector(
                            state: state,
                            controller: controller,
                          ),
                          const SizedBox(height: 14),
                        ],
                        if (state.error != null) ...[
                          _ErrorCard(message: state.error!),
                          const SizedBox(height: 14),
                        ],
                        _TodaySummary(state: state),
                        const SizedBox(height: 14),
                        _NextDoseCard(state: state),
                        if (state.lowStockPills.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _LowStockCard(
                            pills: state.lowStockPills,
                            onTap: () async {
                              if (desktopNav != null) {
                                desktopNav.onOpenMedicines();
                                return;
                              }
                              await context.push(
                                RoutesStr.pillReminderPillList,
                              );
                              await controller.loadHome();
                            },
                          ),
                        ],
                        const SizedBox(height: 28),
                        _SectionTitle(
                          title: 'Today',
                          subtitle:
                              '${state.todayOccurrences.length} scheduled doses',
                        ),
                        const SizedBox(height: 12),
                        if (state.todayOccurrences.isEmpty)
                          const _EmptyCard(
                            icon: Icons.event_available_outlined,
                            title: 'Nothing scheduled today',
                            subtitle: 'Your day is clear.',
                          )
                        else
                          ...state.todayOccurrences.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _OccurrenceCard(
                                occurrence: item,
                                controller: controller,
                              ),
                            ),
                          ),
                        const SizedBox(height: 18),
                        _CompactOccurrenceSection(
                          title: 'Upcoming',
                          subtitle: 'Next scheduled doses',
                          items: state.upcomingOccurrences.take(3).toList(),
                          controller: controller,
                          emptyText: 'No upcoming doses',
                        ),
                        const SizedBox(height: 24),
                        _CompactOccurrenceSection(
                          title: 'Past activity',
                          subtitle: 'Recently taken, missed, or skipped',
                          items: state.recentOccurrences
                              .where((item) => item['status'] != 'PENDING')
                              .take(3)
                              .toList(),
                          controller: controller,
                          emptyText: 'No recent history',
                        ),
                        const SizedBox(height: 28),
                        _WeekSchedule(
                          state: state,
                          controller: controller,
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

