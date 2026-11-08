part of '../view/grocery_title.dart';

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.dashboard,
    required this.onCreatePlan,
    required this.onCreateChore,
  });

  final AsyncValue<Map<String, dynamic>> dashboard;
  final VoidCallback onCreatePlan;
  final VoidCallback onCreateChore;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final scheme = Theme.of(context).colorScheme;
    final overdue = dashboard.asData?.value['overdue'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, const Color(0xFF0E4C3A), 0.45)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Center(
                  child: CenteredFaIcon(
                    FontAwesomeIcons.house,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CenteredFaIcon(
                      overdue > 0
                          ? FontAwesomeIcons.triangleExclamation
                          : FontAwesomeIcons.circleCheck,
                      size: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      overdue > 0 ? '$overdue overdue' : 'Everything on track',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'One dashboard for your home',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              height: 1.12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Plan monthly groceries, see what is left to buy, manage chores, and keep a complete delay record.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onCreatePlan,
                  icon: const CenteredFaIcon(FontAwesomeIcons.basketShopping, size: 14),
                  label: const Text('Grocery plan'),
                  style: FilledButton.styleFrom(
                    foregroundColor: scheme.primary,
                    backgroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCreateChore,
                  icon: const CenteredFaIcon(FontAwesomeIcons.broom, size: 14),
                  label: const Text('Add chore'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.55)),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (dashboard.isLoading) ...[
            const SizedBox(height: 14),
            LinearProgressIndicator(
              minHeight: 2,
              color: Colors.white,
              backgroundColor: Colors.white.withOpacity(0.16),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.dashboard});

  final AsyncValue<Map<String, dynamic>> dashboard;

  @override
  Widget build(BuildContext context) {
    final data = dashboard.asData?.value ?? const <String, dynamic>{};
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.75,
      children: [
        _StatCard(
          icon: FontAwesomeIcons.layerGroup,
          label: 'Active plans',
          value: '${data['plans'] ?? 0}',
          color: const Color(0xFF2E7D32),
        ),
        _StatCard(
          icon: FontAwesomeIcons.basketShopping,
          label: 'To buy',
          value: '${data['pending_items'] ?? 0}',
          color: const Color(0xFF1565C0),
        ),
        _StatCard(
          icon: FontAwesomeIcons.broom,
          label: 'Open chores',
          value: '${data['pending_chores'] ?? 0}',
          color: const Color(0xFF6A1B9A),
        ),
        _StatCard(
          icon: FontAwesomeIcons.triangleExclamation,
          label: 'Overdue',
          value: '${data['overdue'] ?? 0}',
          color: const Color(0xFFC62828),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final FaIconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: neutral.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.11),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: CenteredFaIcon(icon, size: 17, color: color)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: neutral.textPrimary,
                    fontSize: 20,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: neutral.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
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

class _AlertPreview extends StatelessWidget {
  const _AlertPreview({
    required this.alert,
    required this.remaining,
    required this.onTap,
  });

  final Map<String, dynamic> alert;
  final int remaining;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final severity = alert['severity']?.toString() ?? 'info';
    final color = severity == 'critical'
        ? const Color(0xFFC62828)
        : severity == 'warning'
            ? const Color(0xFFEF6C00)
            : const Color(0xFF1565C0);
    final neutral = context.themeColors.neutral;

    return Material(
      color: color.withOpacity(0.09),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: CenteredFaIcon(
                    FontAwesomeIcons.bell,
                    size: 17,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert['title']?.toString() ?? 'Household alert',
                      style: TextStyle(
                        color: neutral.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${alert['message'] ?? ''}${remaining > 0 ? '  •  +$remaining more' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: neutral.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              CenteredFaIcon(
                FontAwesomeIcons.chevronRight,
                color: neutral.textDisabled,
                size: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: neutral.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: neutral.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onAction,
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

class _GroceryPlanCard extends StatelessWidget {
  const _GroceryPlanCard({
    required this.plan,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onShare,
  });

  final Map<String, dynamic> plan;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final color = GroceryCatalog.colorFrom(plan['color_value']);
    final total = (plan['item_count'] as num?)?.toInt() ?? 0;
    final completed = (plan['completed_count'] as num?)?.toInt() ?? 0;
    final pending = (plan['pending_count'] as num?)?.toInt() ?? 0;
    final overdue = (plan['overdue_count'] as num?)?.toInt() ?? 0;
    final progress = total == 0 ? 0.0 : completed / total;
    final date = GroceryCatalog.dateTimeFrom(plan['plan_date']);
    final status = plan['status']?.toString() ?? 'active';

    return Material(
      color: neutral.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: neutral.divider),
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
                      color: color.withOpacity(0.11),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: CenteredFaIcon(
                        GroceryCatalog.iconFor(plan['icon_key']?.toString()),
                        color: color,
                        size: 20,
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
                                plan['title']?.toString() ?? 'Grocery plan',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: neutral.textPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (status == 'completed')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.11),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: const Text(
                                  'Done',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            CenteredFaIcon(FontAwesomeIcons.calendarDays, size: 10, color: neutral.textDisabled),
                            const SizedBox(width: 5),
                            Text(
                              date == null ? 'No date' : DateFormat('MMMM yyyy').format(date),
                              style: TextStyle(color: neutral.textSecondary, fontSize: 11),
                            ),
                            const SizedBox(width: 10),
                            CenteredFaIcon(FontAwesomeIcons.layerGroup, size: 10, color: neutral.textDisabled),
                            const SizedBox(width: 5),
                            Text(
                              _typeLabel(plan['plan_type']?.toString()),
                              style: TextStyle(color: neutral.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_horiz, color: neutral.textSecondary),
                    color: neutral.card,
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'share') onShare();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      _menuItem(FontAwesomeIcons.pen, 'edit', 'Edit', neutral),
                      _menuItem(FontAwesomeIcons.shareNodes, 'share', 'Share', neutral),
                      _menuItem(FontAwesomeIcons.trash, 'delete', 'Delete', neutral, danger: true),
                    ],
                  ),
                ],
              ),
              if ((plan['description']?.toString() ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  plan['description'].toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: neutral.textSecondary,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 7,
                        backgroundColor: color.withOpacity(0.09),
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(progress * 100).round()}%',
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _MiniMetric(label: '$completed done', color: AppColors.success),
                  const SizedBox(width: 8),
                  _MiniMetric(label: '$pending to buy', color: color),
                  if (overdue > 0) ...[
                    const SizedBox(width: 8),
                    _MiniMetric(label: '$overdue overdue', color: AppColors.danger),
                  ],
                  const Spacer(),
                  CenteredFaIcon(FontAwesomeIcons.chevronRight, size: 11, color: neutral.textDisabled),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _typeLabel(String? type) {
    switch (type) {
      case 'weekly':
        return 'Weekly';
      case 'event':
        return 'Event';
      case 'custom':
        return 'Custom';
      default:
        return 'Monthly';
    }
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ChoreCard extends StatelessWidget {
  const _ChoreCard({
    required this.chore,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onHistory,
  });

  final Map<String, dynamic> chore;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final color = GroceryCatalog.colorFrom(chore['color_value'], fallback: const Color(0xFF1565C0));
    final status = chore['status']?.toString() ?? 'pending';
    final isDone = status == 'completed';
    final dueAt = GroceryCatalog.dateTimeFrom(chore['due_at']);
    final isOverdue = !isDone && dueAt != null && dueAt.isBefore(DateTime.now());
    final delay = (chore['completion_delay_minutes'] as num?)?.toInt() ?? 0;

    return Material(
      color: neutral.card,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isOverdue ? AppColors.danger.withOpacity(0.35) : neutral.divider,
          ),
        ),
        child: Row(
          children: [
            InkWell(
              customBorder: const CircleBorder(),
              onTap: onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isDone ? AppColors.success : color.withOpacity(0.11),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isDone
                      ? const CenteredFaIcon(FontAwesomeIcons.check, color: Colors.white, size: 15)
                      : CenteredFaIcon(
                          GroceryCatalog.iconFor(chore['icon_key']?.toString()),
                          color: color,
                          size: 16,
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chore['title']?.toString() ?? 'Household chore',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDone ? neutral.textDisabled : neutral.textPrimary,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    runSpacing: 5,
                    children: [
                      _InlineMeta(
                        icon: FontAwesomeIcons.tags,
                        text: _capitalize(chore['chore_type']?.toString() ?? 'general'),
                        color: neutral.textSecondary,
                      ),
                      if (dueAt != null)
                        _InlineMeta(
                          icon: FontAwesomeIcons.clock,
                          text: DateFormat('dd MMM, h:mm a').format(dueAt),
                          color: isOverdue ? AppColors.danger : neutral.textSecondary,
                        ),
                      if (isDone && delay > 0)
                        _InlineMeta(
                          icon: FontAwesomeIcons.clockRotateLeft,
                          text: '${_formatDelay(delay)} late',
                          color: AppColors.warning,
                        ),
                      if ((chore['recurrence_type']?.toString() ?? 'none') != 'none')
                        _InlineMeta(
                          icon: FontAwesomeIcons.rotate,
                          text: _capitalize(chore['recurrence_type'].toString()),
                          color: color,
                        ),
                    ],
                  ),
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
    );
  }
}

class _InlineMeta extends StatelessWidget {
  const _InlineMeta({
    required this.icon,
    required this.text,
    required this.color,
  });

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

class _AlertButton extends StatelessWidget {
  const _AlertButton({required this.onTap, this.unreadCount = 0});

  final VoidCallback onTap;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return IconButton(
      onPressed: onTap,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          CenteredFaIcon(FontAwesomeIcons.bell, size: 19, color: neutral.textPrimary),
          if (unreadCount > 0)
            Positioned(
              right: -8,
              top: -8,
              child: Container(
                constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  unreadCount > 9 ? '9+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
