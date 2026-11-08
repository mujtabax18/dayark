part of '../finance_screen.dart';

class _FinanceOverviewCards extends StatelessWidget {
  const _FinanceOverviewCards({
    required this.summary,
    required this.currency,
  });

  final DashboardSummary summary;
  final CurrencySetting currency;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = <Widget>[
          _ExpenseOverviewCard(expense: summary.expenses, currency: currency),
          _KhataOverviewCard(loans: summary.loans, currency: currency),
        ];

        if (constraints.maxWidth >= 760) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: cards[1]),
            ],
          );
        }

        return Column(
          children: [
            cards[0],
            const SizedBox(height: AppSpacing.sm),
            cards[1],
          ],
        );
      },
    );
  }
}

class _ExpenseOverviewCard extends StatelessWidget {
  const _ExpenseOverviewCard({
    required this.expense,
    required this.currency,
  });

  final ExpenseHomeSummary expense;
  final CurrencySetting currency;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFF43F5E);
    final scheme = Theme.of(context).colorScheme;

    return AppSurface(
      onTap: () => openResponsiveModule(context, RoutesStr.expense),
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
                  color: color.withOpacity(.12),
                  borderRadius: AppRadius.small,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: color,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expenses',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(
                      'Current active expense period',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            currency.formatCompact(expense.remaining),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.4,
                ),
          ),
          Text(
            'Available balance',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _FinanceMetric(
                  label: 'Income',
                  value: currency.formatCompact(expense.income),
                  icon: Icons.south_west_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _FinanceMetric(
                  label: 'Spent',
                  value: currency.formatCompact(expense.expense),
                  icon: Icons.north_east_rounded,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${expense.transactionCount} transactions • ${expense.categoryCount} categories',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _KhataOverviewCard extends StatelessWidget {
  const _KhataOverviewCard({
    required this.loans,
    required this.currency,
  });

  final LoanHomeSummary loans;
  final CurrencySetting currency;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF0891B2);
    final scheme = Theme.of(context).colorScheme;

    return AppSurface(
      onTap: () => openResponsiveModule(context, RoutesStr.loans),
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
                  color: color.withOpacity(.12),
                  borderRadius: AppRadius.small,
                ),
                child: const Icon(
                  Icons.account_balance_outlined,
                  color: color,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Digital Khata',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(
                      'Receivables and payables',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            currency.formatCompact(loans.toReceive),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.4,
                ),
          ),
          Text(
            'Total to receive',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _FinanceMetric(
                  label: 'To pay',
                  value: currency.formatCompact(loans.toPay),
                  icon: Icons.call_made_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _FinanceMetric(
                  label: 'Overdue',
                  value: currency.formatCompact(loans.overdueAmount),
                  icon: Icons.schedule_rounded,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${loans.activeAccounts} active accounts • ${loans.overdueAccounts} overdue',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _FinanceMetric extends StatelessWidget {
  const _FinanceMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(.55),
        borderRadius: AppRadius.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _CurrentFinanceActivity extends StatelessWidget {
  const _CurrentFinanceActivity({
    required this.summary,
    required this.quotationCount,
  });

  final DashboardSummary? summary;
  final int? quotationCount;

  @override
  Widget build(BuildContext context) {
    final data = summary;
    final items = <_ActivityItem>[
      _ActivityItem(
        icon: Icons.swap_vert_rounded,
        color: const Color(0xFFF43F5E),
        title: 'Expense transactions',
        value: data == null ? '—' : '${data.expenses.transactionCount}',
        subtitle: 'Recorded this month',
      ),
      _ActivityItem(
        icon: Icons.people_alt_outlined,
        color: const Color(0xFF0891B2),
        title: 'Active Khata accounts',
        value: data == null ? '—' : '${data.loans.activeAccounts}',
        subtitle: '${data?.loans.overdueAccounts ?? 0} overdue',
      ),
      _ActivityItem(
        icon: Icons.receipt_long_outlined,
        color: const Color(0xFF6366F1),
        title: 'Saved invoices',
        value: data == null ? '—' : '${data.invoiceCount}',
        subtitle: 'Available locally',
      ),
      _ActivityItem(
        icon: Icons.request_quote_outlined,
        color: const Color(0xFF7C3AED),
        title: 'Saved quotations',
        value: quotationCount == null ? '—' : '$quotationCount',
        subtitle: 'Available locally',
      ),
    ];

    return AppSurface(
      padding: EdgeInsets.zero,
      borderRadius: AppRadius.large,
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _ActivityRow(item: items[index]),
            if (index != items.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});

  final _ActivityItem item;

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

class _ActivityItem {
  const _ActivityItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String subtitle;
}

