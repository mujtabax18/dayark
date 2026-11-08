import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pill_form/view/pill_form_screen.dart';
import '../../pill_home/provider/pill_home_provider.dart';
import '../../shared/pill_ui_helpers.dart';
import '../../shared/pill_desktop_navigation.dart';
import '../controller/pill_list_controller.dart';
import '../provider/pill_list_provider.dart';
import 'pill_inventory_refill_screen.dart';
import '../../../navigation/widgets/desktop_content_frame.dart';
part '../widgets/pill_list_widgets.dart';

class PillListScreen extends ConsumerStatefulWidget {
  const PillListScreen({super.key});

  @override
  ConsumerState<PillListScreen> createState() => _PillListScreenState();
}

class _PillListScreenState extends ConsumerState<PillListScreen> {
  final searchCtrl = TextEditingController();
  String filter = 'ALL';

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = ref.watch(pillListControllerProvider);
    final controller = ref.read(pillListControllerProvider.notifier);
    final desktopNav = PillDesktopNavigationScope.maybeOf(context);
    final query = searchCtrl.text.trim().toLowerCase();

    final pills = state.pills.where((pill) {
      final nameMatches = pill['name'].toString().toLowerCase().contains(query);
      final active = pill['is_active'] == 1;
      final tracks = pill['track_inventory'] == 1;
      final remaining = (pill['remaining_quantity'] as num?)?.toDouble() ?? 0;
      final threshold =
          (pill['low_stock_threshold'] as num?)?.toDouble() ?? 0;
      final low = active && tracks && remaining <= threshold;
      final filterMatches = switch (filter) {
        'LOW' => low,
        'INACTIVE' => !active,
        _ => true,
      };
      return nameMatches && filterMatches;
    }).toList();

    final activeCount = state.pills.where((pill) => pill['is_active'] == 1).length;
    final lowCount = state.pills.where((pill) {
      final active = pill['is_active'] == 1;
      final tracks = pill['track_inventory'] == 1;
      final remaining = (pill['remaining_quantity'] as num?)?.toDouble() ?? 0;
      final threshold =
          (pill['low_stock_threshold'] as num?)?.toDouble() ?? 0;
      return active && tracks && remaining <= threshold;
    }).length;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('My medicines'),
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
              await controller.loadPills();
              ref.invalidate(pillHomeControllerProvider);
            },
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: DesktopContentFrame(
        child: RefreshIndicator(
        onRefresh: controller.loadPills,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
          children: [
            _InventoryOverview(
              total: state.pills.length,
              active: activeCount,
              lowStock: lowCount,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search medicines',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          searchCtrl.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: const [
                  ('ALL', 'All', Icons.medication_outlined),
                  ('LOW', 'Low stock', Icons.warning_amber_rounded),
                  ('INACTIVE', 'Inactive', Icons.pause_circle_outline_rounded),
                ].map((item) {
                  return _FilterChoice(
                    value: item.$1,
                    label: item.$2,
                    icon: item.$3,
                  );
                }).map((choice) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Icon(choice.icon, size: 17),
                      label: Text(choice.label),
                      selected: filter == choice.value,
                      onSelected: (_) => setState(() => filter = choice.value),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${pills.length} ${pills.length == 1 ? 'medicine' : 'medicines'}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (query.isNotEmpty || filter != 'ALL')
                  TextButton.icon(
                    onPressed: () {
                      searchCtrl.clear();
                      setState(() => filter = 'ALL');
                    },
                    icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                    label: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.error != null)
              _MessageCard(
                icon: Icons.error_outline_rounded,
                title: 'Could not load medicines',
                subtitle: state.error!,
                color: scheme.error,
              )
            else if (pills.isEmpty)
              const _MessageCard(
                icon: Icons.medication_outlined,
                title: 'No medicines found',
                subtitle: 'Add a medicine or clear the filters.',
              )
            else
              ...pills.map(
                (pill) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MedicineCard(
                    pill: pill,
                    controller: controller,
                    onDataChanged: () {
                      ref.invalidate(pillHomeControllerProvider);
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}

