part of '../HomeScreenAlignment.dart';

class _ToggleReorderCard extends StatelessWidget {
  const _ToggleReorderCard({
    super.key,
    required this.index,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onChanged,
    this.position,
    this.positionCount,
    this.onPositionSelected,
  });

  final int index;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final int? position;
  final int? positionCount;
  final ValueChanged<int>? onPositionSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.medium,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsetsDirectional.fromSTEB(10, 2, 6, 2),
        leading: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withOpacity(.13),
            borderRadius: AppRadius.small,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: enabled ? null : scheme.onSurfaceVariant,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (position != null &&
                positionCount != null &&
                onPositionSelected != null)
              PopupMenuButton<int>(
                tooltip: 'Select Home position',
                initialValue: position,
                onSelected: onPositionSelected,
                icon: Icon(
                  Icons.pin_drop_outlined,
                  color: scheme.onSurfaceVariant,
                  size: 20,
                ),
                itemBuilder: (context) => List.generate(
                  positionCount!,
                  (itemIndex) => PopupMenuItem<int>(
                    value: itemIndex,
                    child: Text('Position ${itemIndex + 1}'),
                  ),
                ),
              ),
            Switch.adaptive(value: enabled, onChanged: onChanged),
            if (onPositionSelected == null)
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.drag_handle_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _QuickActionData {
  const _QuickActionData(this.title, this.icon, this.color);
  final String title;
  final IconData icon;
  final Color color;
}

_QuickActionData _quickActionData(String id) {
  return switch (id) {
    HomeQuickActionId.expense => const _QuickActionData(
        'Expense', Icons.add_card_rounded, Color(0xFFF43F5E)),
    HomeQuickActionId.meterReading => const _QuickActionData(
        'Meter reading', Icons.add_chart_rounded, Color(0xFF4F46E5)),
    HomeQuickActionId.habit => const _QuickActionData(
        'Habit', Icons.task_alt_rounded, Color(0xFF8B5CF6)),
    HomeQuickActionId.grocery => const _QuickActionData(
        'Grocery', Icons.shopping_cart_checkout_rounded, Color(0xFF22C55E)),
    HomeQuickActionId.pill => const _QuickActionData(
        'Pill reminder', Icons.medication_rounded, Color(0xFF14B8A6)),
    HomeQuickActionId.loan => const _QuickActionData(
        'Loan / Khata', Icons.person_add_alt_1_rounded, Color(0xFF0891B2)),
    HomeQuickActionId.invoice => const _QuickActionData(
        'Invoice', Icons.post_add_rounded, Color(0xFF6366F1)),
    HomeQuickActionId.quotation => const _QuickActionData(
        'Quotation', Icons.format_quote_rounded, Color(0xFF7C3AED)),
    HomeQuickActionId.media => const _QuickActionData(
        'Media', Icons.auto_fix_high_rounded, Color(0xFFE11D48)),
    HomeQuickActionId.diary => const _QuickActionData(
        'Diary', Icons.edit_note_rounded, Color(0xFFEC4899)),
    HomeQuickActionId.scan => const _QuickActionData(
        'Document scan', Icons.document_scanner_rounded, Color(0xFF0EA5E9)),
    _ => const _QuickActionData(
        'Action', Icons.bolt_rounded, Color(0xFF64748B)),
  };
}

String _featureTitle(HomeFeatureModel feature) {
  return switch (feature.id) {
    10 => 'Media Studio',
    12 => 'Document Scanner',
    _ => feature.title,
  };
}

IconData _featureIcon(HomeFeatureModel feature) {
  return feature.iconCode >= 0 && feature.iconCode < homeIconList.length
      ? homeIconList[feature.iconCode]
      : Icons.widgets_outlined;
}
