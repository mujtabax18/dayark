import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/pill_ui_helpers.dart';
import '../provider/pill_settings_provider.dart';
import '../../../navigation/widgets/desktop_content_frame.dart';

class PillSettingsScreen extends ConsumerStatefulWidget {
  const PillSettingsScreen({super.key});

  @override
  ConsumerState<PillSettingsScreen> createState() =>
      _PillSettingsScreenState();
}

class _PillSettingsScreenState extends ConsumerState<PillSettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleTabChanged);
  }

  void _handleTabChanged() {
    if (!_tabController.indexIsChanging && mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = ref.watch(pillSettingsControllerProvider);
    final controller = ref.read(pillSettingsControllerProvider.notifier);
    final isPillTypeTab = _tabController.index == 0;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: const Text('Pill settings')),
      body: DesktopContentFrame(
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              children: [
                _SettingsIntro(isPillTypeTab: isPillTypeTab),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.medication_outlined, size: 19),
                        text: 'Pill types',
                      ),
                      Tab(
                        icon: Icon(Icons.straighten_rounded, size: 19),
                        text: 'Dosage units',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? _SettingsMessage(
                        icon: Icons.error_outline_rounded,
                        title: 'Could not load settings',
                        subtitle: state.error!,
                        color: scheme.error,
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildList(
                            context: context,
                            items: state.pillTypes,
                            itemIcon: Icons.medication_outlined,
                            emptyTitle: 'No pill types',
                            emptySubtitle:
                                'Add a type such as tablet, capsule, or syrup.',
                            onEdit: controller.updatePillType,
                            onDelete: controller.deletePillType,
                          ),
                          _buildList(
                            context: context,
                            items: state.dosageTypes,
                            itemIcon: Icons.straighten_rounded,
                            emptyTitle: 'No dosage units',
                            emptySubtitle:
                                'Add a unit such as mg, ml, tablet, or drop.',
                            onEdit: controller.updateDosageType,
                            onDelete: controller.deleteDosageType,
                          ),
                        ],
                      ),
          ),
        ],
      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showEditDialog(
            context,
            initialValue: '',
            title: isPillTypeTab ? 'Add pill type' : 'Add dosage unit',
            label: isPillTypeTab ? 'Type name' : 'Unit name',
            onSave: (value) async {
              if (isPillTypeTab) {
                await controller.addPillType(value);
              } else {
                await controller.addDosageType(value);
              }
            },
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(isPillTypeTab ? 'Add type' : 'Add unit'),
      ),
    );
  }

  Widget _buildList({
    required BuildContext context,
    required List<Map<String, dynamic>> items,
    required IconData itemIcon,
    required String emptyTitle,
    required String emptySubtitle,
    required Future<void> Function(int, String) onEdit,
    required Future<void> Function(int) onDelete,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (items.isEmpty) {
      return _SettingsMessage(
        icon: itemIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 104),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final item = items[index];
        final isProtected = item['is_system'] == 1;

        return Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          decoration: PillUi.cardDecoration(context, radius: 19),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: PillUi.tintedSurface(
                    context,
                    scheme.primary,
                    opacity: .09,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(itemIcon, color: scheme.primary, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'].toString(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isProtected ? 'Default system item' : 'Custom item',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isProtected)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Tooltip(
                    message: 'Default items cannot be edited',
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 19,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                PopupMenuButton<String>(
                  tooltip: 'Item options',
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditDialog(
                        context,
                        initialValue: item['name'].toString(),
                        title: 'Edit item',
                        label: 'Name',
                        onSave: (name) => onEdit(item['id'] as int, name),
                      );
                    } else if (value == 'delete') {
                      _confirmDelete(
                        context,
                        itemName: item['name'].toString(),
                        onConfirm: () => onDelete(item['id'] as int),
                      );
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: _SettingsMenuItem(
                        icon: Icons.edit_outlined,
                        label: 'Edit',
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: _SettingsMenuItem(
                        icon: Icons.delete_outline_rounded,
                        label: 'Delete',
                        color: scheme.error,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  void _showEditDialog(
    BuildContext context, {
    required String initialValue,
    required String title,
    required String label,
    required Future<void> Function(String) onSave,
  }) {
    final textCtrl = TextEditingController(text: initialValue);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          initialValue.isEmpty ? Icons.add_circle_outline : Icons.edit_outlined,
        ),
        title: Text(title),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: label),
          onSubmitted: (value) async {
            final name = value.trim();
            if (name.isEmpty) return;
            Navigator.pop(dialogContext);
            await onSave(name);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final value = textCtrl.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(dialogContext);
              await onSave(value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).whenComplete(textCtrl.dispose);
  }

  void _confirmDelete(
    BuildContext context, {
    required String itemName,
    required Future<void> Function() onConfirm,
  }) {
    final scheme = Theme.of(context).colorScheme;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
        title: const Text('Delete item?'),
        content: Text(
          '“$itemName” will be removed from the available options. Existing '
          'medicine records are not changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await onConfirm();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _SettingsIntro extends StatelessWidget {
  const _SettingsIntro({required this.isPillTypeTab});

  final bool isPillTypeTab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: PillUi.cardDecoration(
        context,
        color: PillUi.tintedSurface(context, scheme.primary, opacity: .06),
        borderColor: scheme.primary.withOpacity(.16),
        radius: 22,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: PillUi.tintedSurface(
                context,
                scheme.primary,
                opacity: .12,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              isPillTypeTab
                  ? Icons.medication_outlined
                  : Icons.straighten_rounded,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPillTypeTab ? 'Medicine forms' : 'Dosage units',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isPillTypeTab
                      ? 'Control the medicine types shown in the add form.'
                      : 'Control the measurement units shown for strength.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
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

class _SettingsMenuItem extends StatelessWidget {
  const _SettingsMenuItem({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 11),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

class _SettingsMessage extends StatelessWidget {
  const _SettingsMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = color ?? scheme.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(26),
          decoration: PillUi.cardDecoration(context, radius: 23),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: PillUi.tintedSurface(context, accent, opacity: .10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: accent, size: 27),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
