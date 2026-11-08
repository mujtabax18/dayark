import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_x.dart';
import '../controller/quotation_controller.dart';
import '../services/quotation_service.dart';

class QuotationManagementSheet extends ConsumerStatefulWidget {
  const QuotationManagementSheet({
    super.key,
    required this.currentCategory,
    this.embedded = false,
  });

  final String currentCategory;
  final bool embedded;

  @override
  ConsumerState<QuotationManagementSheet> createState() =>
      _QuotationManagementSheetState();
}

class _QuotationManagementSheetState
    extends ConsumerState<QuotationManagementSheet> {
  QuotationLibraryStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final stats = await ref.read(quotationServiceProvider).getLibraryStats();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _loading = false;
    });
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(
                  'Continue',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _resetUsage() async {
    final ok = await _confirm(
      'Reset usage history?',
      'Usage counts will be reset for every quotation. Favorites are kept.',
    );
    if (!ok) return;

    await ref.read(quotationServiceProvider).resetUsageHistory();
    await ref.read(quotationControllerProvider.notifier).refresh();
    await _reload();
    _showMessage('Quotation usage history reset.');
  }

  Future<void> _removeOnline() async {
    final count = _stats?.online ?? 0;
    if (count == 0) return;

    final ok = await _confirm(
      'Remove downloaded quotations?',
      'This removes $count quotations downloaded from the online repository. '
          'You can download them again later.',
    );
    if (!ok) return;

    final removed = await ref.read(quotationServiceProvider).removeAllOnline();
    await ref.read(quotationControllerProvider.notifier).refresh();
    await _reload();
    _showMessage('$removed online quotations removed.');
  }

  Future<void> _deleteCurrentCategory() async {
    final category = widget.currentCategory;
    if (category == 'All' || category.trim().isEmpty) return;

    final ok = await _confirm(
      'Delete "$category"?',
      'All local quotations in this category will be deleted. This cannot be undone.',
    );
    if (!ok) return;

    final removed =
        await ref.read(quotationServiceProvider).deleteCategory(category);
    final controller = ref.read(quotationControllerProvider.notifier);
    await controller.setCategory('All');
    await controller.refresh();
    await _reload();
    _showMessage('$removed quotations deleted from $category.');
    if (mounted) Navigator.pop(context);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final stats = _stats;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.embedded) ...[
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: neutral.divider,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ] else
              const SizedBox(height: 8),
            const Text(
              'Manage quotation library',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Library statistics, downloaded content and cleanup tools.',
              style: TextStyle(color: neutral.textSecondary),
            ),
            const SizedBox(height: 16),
            if (_loading || stats == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                childAspectRatio: 1.35,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  _StatTile(label: 'Quotes', value: stats.total),
                  _StatTile(label: 'Favorites', value: stats.favorites),
                  _StatTile(label: 'Online', value: stats.online),
                  _StatTile(label: 'Categories', value: stats.categories),
                  _StatTile(label: 'Used', value: stats.used),
                  _StatTile(label: 'Total uses', value: stats.totalUses),
                ],
              ),
              const SizedBox(height: 16),
              _ActionTile(
                icon: Icons.history_outlined,
                title: 'Reset usage history',
                subtitle: 'Clear used flags and usage counters',
                onTap: _resetUsage,
              ),
              _ActionTile(
                icon: Icons.cloud_off_outlined,
                title: 'Remove all online downloads',
                subtitle: stats.online == 0
                    ? 'No downloaded online quotations'
                    : 'Remove ${stats.online} downloaded quotations',
                enabled: stats.online > 0,
                onTap: _removeOnline,
              ),
              if (widget.currentCategory != 'All')
                _ActionTile(
                  icon: Icons.delete_outline,
                  title: 'Delete current category',
                  subtitle:
                      'Delete all quotations in "${widget.currentCategory}"',
                  destructive: true,
                  onTap: _deleteCurrentCategory,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: neutral.divider),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$value',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: neutral.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final color = destructive ? AppColors.danger : neutral.textPrimary;

    return ListTile(
      enabled: enabled,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: enabled ? color : neutral.textSecondary),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: enabled ? onTap : null,
    );
  }
}
