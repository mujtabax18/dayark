part of '../view/grocery_item.dart';

class _PlanHeader extends StatelessWidget {
  const _PlanHeader({required this.plan, required this.onEdit});

  final Map<String, dynamic> plan;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final color = GroceryCatalog.colorFrom(plan['color_value']);
    final total = (plan['item_count'] as num?)?.toInt() ?? 0;
    final done = (plan['completed_count'] as num?)?.toInt() ?? 0;
    final pending = (plan['pending_count'] as num?)?.toInt() ?? 0;
    final overdue = (plan['overdue_count'] as num?)?.toInt() ?? 0;
    final progress = total == 0 ? 0.0 : done / total;
    final planDate = GroceryCatalog.dateTimeFrom(plan['plan_date']);
    final dueAt = GroceryCatalog.dateTimeFrom(plan['due_at']);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color,
            Color.lerp(color, Colors.black, 0.26)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: CenteredFaIcon(
                    GroceryCatalog.iconFor(plan['icon_key']?.toString()),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const Spacer(),
              IconButton.filledTonal(
                onPressed: onEdit,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.14),
                  foregroundColor: Colors.white,
                ),
                icon: const CenteredFaIcon(FontAwesomeIcons.pen, size: 14),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            plan['title']?.toString() ?? 'Grocery plan',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          if ((plan['description']?.toString() ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              plan['description'].toString(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.82),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (planDate != null)
                _HeaderPill(
                  icon: FontAwesomeIcons.calendarDays,
                  text: DateFormat('MMMM yyyy').format(planDate),
                ),
              if (dueAt != null)
                _HeaderPill(
                  icon: FontAwesomeIcons.clock,
                  text: 'Due ${DateFormat('dd MMM, h:mm a').format(dueAt)}',
                ),
              _HeaderPill(
                icon: FontAwesomeIcons.layerGroup,
                text: _planTypeLabel(plan['plan_type']?.toString()),
              ),
              if (plan['alert_enabled'] == 1)
                const _HeaderPill(
                  icon: FontAwesomeIcons.bell,
                  text: 'Alert enabled',
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    color: Colors.white,
                    backgroundColor: Colors.white.withOpacity(0.18),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _HeaderCount(value: '$done', label: 'Done'),
              const SizedBox(width: 20),
              _HeaderCount(value: '$pending', label: 'To buy'),
              const SizedBox(width: 20),
              _HeaderCount(value: '$overdue', label: 'Overdue'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.icon, required this.text});

  final FaIconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CenteredFaIcon(icon, color: Colors.white, size: 9),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCount extends StatelessWidget {
  const _HeaderCount({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.72),
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.onSelected,
    required this.items,
  });

  final String selected;
  final ValueChanged<String> onSelected;
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final pending = items.where((item) => item['status'] != 1).length;
    final done = items.where((item) => item['status'] == 1).length;
    final overdue = items.where((item) {
      if (item['status'] == 1) return false;
      final dueAt = GroceryCatalog.dateTimeFrom(item['due_at']);
      return dueAt != null && dueAt.isBefore(DateTime.now());
    }).length;

    final options = <({String key, String label, int count})>[
      (key: 'all', label: 'All', count: items.length),
      (key: 'pending', label: 'To buy', count: pending),
      (key: 'done', label: 'Done', count: done),
      (key: 'overdue', label: 'Overdue', count: overdue),
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final option = options[index];
          final isSelected = selected == option.key;
          return ChoiceChip(
            selected: isSelected,
            onSelected: (_) => onSelected(option.key),
            label: Text('${option.label}  ${option.count}'),
            labelStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : context.themeColors.neutral.textSecondary,
            ),
            selectedColor: Theme.of(context).colorScheme.primary,
            backgroundColor: context.themeColors.neutral.card,
            side: BorderSide(color: context.themeColors.neutral.divider),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
          );
        },
      ),
    );
  }
}

class _GroceryItemCard extends StatelessWidget {
  const _GroceryItemCard({
    required this.item,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onHistory,
  });

  final Map<String, dynamic> item;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final done = item['status'] == 1;
    final dueAt = GroceryCatalog.dateTimeFrom(item['due_at']);
    final overdue = !done && dueAt != null && dueAt.isBefore(DateTime.now());
    final priority = item['priority']?.toString() ?? 'normal';
    final priorityColor = _priorityColor(priority);
    final delay = (item['completion_delay_minutes'] as num?)?.toInt() ?? 0;
    final quantity = (item['quantity'] as num?)?.toDouble() ?? 1;
    final unit = item['unit']?.toString() ?? 'item';

    return Material(
      color: neutral.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: overdue ? AppColors.danger.withOpacity(0.35) : neutral.divider,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                customBorder: const CircleBorder(),
                onTap: onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: done
                        ? AppColors.success
                        : Theme.of(context).colorScheme.primary.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: CenteredFaIcon(
                      done ? FontAwesomeIcons.check : _itemTypeIcon(item['item_type']?.toString()),
                      color: done ? Colors.white : Theme.of(context).colorScheme.primary,
                      size: 15,
                    ),
                  ),
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
                            item['name']?.toString() ?? 'Grocery item',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: done ? neutral.textDisabled : neutral.textPrimary,
                              decoration: done ? TextDecoration.lineThrough : null,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: priorityColor.withOpacity(0.09),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            _capitalize(priority),
                            style: TextStyle(
                              color: priorityColor,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 9,
                      runSpacing: 5,
                      children: [
                        _ItemMeta(
                          icon: FontAwesomeIcons.scaleBalanced,
                          text: '${_formatQuantity(quantity)} $unit',
                          color: neutral.textSecondary,
                        ),
                        _ItemMeta(
                          icon: FontAwesomeIcons.tags,
                          text: _capitalize(item['item_type']?.toString() ?? 'general'),
                          color: neutral.textSecondary,
                        ),
                        if (dueAt != null)
                          _ItemMeta(
                            icon: FontAwesomeIcons.clock,
                            text: DateFormat('dd MMM, h:mm a').format(dueAt),
                            color: overdue ? AppColors.danger : neutral.textSecondary,
                          ),
                        if (done && delay > 0)
                          _ItemMeta(
                            icon: FontAwesomeIcons.clockRotateLeft,
                            text: '${_formatDelay(delay)} late',
                            color: AppColors.warning,
                          ),
                        if (item['alert_enabled'] == 1)
                          _ItemMeta(
                            icon: FontAwesomeIcons.bell,
                            text: 'Alert',
                            color: Theme.of(context).colorScheme.primary,
                          ),
                      ],
                    ),
                    if ((item['notes']?.toString() ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        item['notes'].toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: neutral.textSecondary,
                          fontSize: 10,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: neutral.textSecondary),
                color: neutral.card,
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'history') onHistory();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  _menuItem(FontAwesomeIcons.pen, 'edit', 'Edit', neutral),
                  _menuItem(FontAwesomeIcons.clockRotateLeft, 'history', 'History', neutral),
                  _menuItem(FontAwesomeIcons.trash, 'delete', 'Delete', neutral, danger: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemMeta extends StatelessWidget {
  const _ItemMeta({required this.icon, required this.text, required this.color});

  final FaIconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CenteredFaIcon(icon, size: 9, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
