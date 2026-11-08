part of '../view/expenses.dart';

class _ClosedPeriodBar extends StatelessWidget {
  final VoidCallback onShowOpenPeriod;

  const _ClosedPeriodBar({required this.onShowOpenPeriod});

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        decoration: BoxDecoration(
          color: neutral.card,
          border: Border(top: BorderSide(color: neutral.divider)),
        ),
        child: Row(
          children: [
            Icon(Icons.edit_calendar_outlined, color: neutral.textSecondary, size: 20),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'Historical month: edit its transactions directly here.',
                style: TextStyle(
                  color: neutral.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: onShowOpenPeriod,
              child: const Text('Active month'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTotals extends StatelessWidget {
  final double totalIn;
  final double totalOut;
  final Color color;

  const _CategoryTotals({
    required this.totalIn,
    required this.totalOut,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _value(
              context,
              'Income',
              totalIn,
              AppColors.success,
            ),
          ),
          Container(width: 1, height: 34, color: neutral.divider),
          Expanded(
            child: _value(
              context,
              'Expense',
              totalOut,
              AppColors.danger,
            ),
          ),
          Container(width: 1, height: 34, color: neutral.divider),
          Expanded(
            child: _value(
              context,
              'Balance',
              totalIn - totalOut,
              color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _value(
    BuildContext context,
    String label,
    double value,
    Color color,
  ) {
    final neutral = context.themeColors.neutral;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: neutral.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 4),
        FittedBox(
          child: Text(
            value.toStringAsFixed(2),
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _EmptyItems extends StatelessWidget {
  const _EmptyItems({required this.color, required this.icon});

  final Color color;
  final FaIconData icon;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: icon.data,
      title: 'No transactions in this view',
      message: 'Add a transaction below or change the active filters.',
      accent: color,
    );
  }
}

class _DesktopCategoryTotals extends StatelessWidget {
  const _DesktopCategoryTotals({
    required this.totalIn,
    required this.totalOut,
    required this.transactionCount,
    required this.color,
  });

  final double totalIn;
  final double totalOut;
  final int transactionCount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _DesktopMetricCard(
        label: 'Income',
        value: totalIn.toStringAsFixed(2),
        icon: Icons.south_west_rounded,
        color: AppColors.success,
      ),
      _DesktopMetricCard(
        label: 'Expense',
        value: totalOut.toStringAsFixed(2),
        icon: Icons.north_east_rounded,
        color: AppColors.danger,
      ),
      _DesktopMetricCard(
        label: 'Balance',
        value: (totalIn - totalOut).toStringAsFixed(2),
        icon: Icons.account_balance_wallet_outlined,
        color: color,
      ),
      _DesktopMetricCard(
        label: 'Transactions',
        value: transactionCount.toString(),
        icon: Icons.receipt_long_outlined,
        color: AppColors.warning,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          final cardWidth = (constraints.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final card in cards)
                SizedBox(width: cardWidth, child: card),
            ],
          );
        }

        return Row(
          children: [
            for (var index = 0; index < cards.length; index++) ...[
              Expanded(child: cards[index]),
              if (index != cards.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _DesktopMetricCard extends StatelessWidget {
  const _DesktopMetricCard({
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
    final neutral = context.themeColors.neutral;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: neutral.divider.withOpacity(0.75)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: neutral.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: neutral.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
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

class _DesktopClosedPeriodPanel extends StatelessWidget {
  const _DesktopClosedPeriodPanel({required this.onShowOpenPeriod});

  final VoidCallback onShowOpenPeriod;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: neutral.divider.withOpacity(0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: AppColors.warning,
              size: 21,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Historical period',
            style: TextStyle(
              color: neutral.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'You are viewing a closed month. Existing transactions can still be reviewed and edited here.',
            style: TextStyle(
              color: neutral.textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onShowOpenPeriod,
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: const Text('Return to active month'),
            ),
          ),
        ],
      ),
    );
  }
}
