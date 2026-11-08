part of '../view/expense_reports_page.dart';

class _RangeSelector extends StatelessWidget {
  final ExpenseReportRange value;
  final ValueChanged<ExpenseReportRange> onChanged;

  const _RangeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final labels = <ExpenseReportRange, String>{
      ExpenseReportRange.currentMonth: 'Month',
      ExpenseReportRange.threeMonths: '3M',
      ExpenseReportRange.sixMonths: '6M',
      ExpenseReportRange.twelveMonths: '1Y',
      ExpenseReportRange.allTime: 'All',
    };
    return SegmentedButton<ExpenseReportRange>(
      segments: labels.entries
          .map(
            (entry) => ButtonSegment(
              value: entry.key,
              label: Text(entry.value),
            ),
          )
          .toList(),
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final ExpenseReportData report;

  const _SummaryGrid({required this.report});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 4 : 2;
        final totalSpacing = 12.0 * (columns - 1);
        final width = (constraints.maxWidth - totalSpacing) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(
              width: width,
              label: 'Income',
              value: report.totalIn,
              icon: Icons.arrow_upward_rounded,
              color: AppColors.success,
            ),
            _MetricCard(
              width: width,
              label: 'Expense',
              value: report.totalOut,
              icon: Icons.arrow_downward_rounded,
              color: AppColors.danger,
            ),
            _MetricCard(
              width: width,
              label: 'Net balance',
              value: report.net,
              icon: Icons.account_balance_wallet_outlined,
              color: AppColors.expense,
            ),
            _MetricCard(
              width: width,
              label: 'Transactions',
              valueText: report.transactionCount.toString(),
              icon: Icons.receipt_long_outlined,
              color: AppColors.warning,
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final double width;
  final String label;
  final double? value;
  final String? valueText;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.width,
    required this.label,
    this.value,
    this.valueText,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Container(
      width: width,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: neutral.divider.withOpacity(0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(color: neutral.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            valueText ?? (value ?? 0).toStringAsFixed(2),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: neutral.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final ExpenseReportData report;

  const _InsightCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final top = report.topExpenseCategory;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.expense.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_graph_rounded, color: AppColors.expense),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              top == null
                  ? 'Add transactions to unlock spending insights.'
                  : '${top.title} is the largest expense category at '
                      '${top.totalOut.toStringAsFixed(2)}. Average daily expense is '
                      '${report.averageDailyExpense.toStringAsFixed(2)}.',
              style: TextStyle(
                color: neutral.textPrimary,
                height: 1.4,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: neutral.divider.withOpacity(0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: neutral.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(color: neutral.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  final ExpenseReportData report;

  const _CategoryBreakdown({required this.report});

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final categories = report.categories
        .where((category) => category.totalOut > 0 || category.totalIn > 0)
        .toList();
    if (categories.isEmpty) return const _EmptyChart();

    final maxValue = categories.fold<double>(
      0,
      (value, item) => math.max(value, item.totalOut),
    );

    return Column(
      children: categories.map((category) {
        final color = ExpenseCategoryStyle.colorFromHex(category.colorHex);
        final icon = ExpenseCategoryStyle.iconFromCode(
          category.iconCode,
          title: category.title,
        );
        final fraction = maxValue <= 0 ? 0.0 : category.totalOut / maxValue;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: CenteredFaIcon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            category.title,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: neutral.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (category.hidden) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.visibility_off_outlined,
                            size: 15,
                            color: neutral.textSecondary,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    category.totalOut.toStringAsFixed(2),
                    style: TextStyle(
                      color: neutral.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 7,
                  color: color,
                  backgroundColor: neutral.divider.withOpacity(0.5),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _CashFlowChart extends StatelessWidget {
  final List<ExpenseTrendPoint> points;

  const _CashFlowChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _LegendDot(label: 'Income', color: AppColors.success),
            const SizedBox(width: 14),
            _LegendDot(label: 'Expense', color: AppColors.danger),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: CustomPaint(
            painter: _CashFlowPainter(
              points: points,
              gridColor: neutral.divider,
              labelColor: neutral.textSecondary,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(color: neutral.textSecondary, fontSize: 11)),
      ],
    );
  }
}

class _CashFlowPainter extends CustomPainter {
  final List<ExpenseTrendPoint> points;
  final Color gridColor;
  final Color labelColor;

  _CashFlowPainter({
    required this.points,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const left = 8.0;
    const right = 8.0;
    const top = 8.0;
    const bottom = 30.0;
    final chartHeight = size.height - top - bottom;
    final chartWidth = size.width - left - right;
    if (chartWidth <= 0 || chartHeight <= 0 || points.isEmpty) return;

    final maxValue = points.fold<double>(
      1,
      (value, point) =>
          math.max(value, math.max(point.totalIn, point.totalOut)),
    );
    final gridPaint = Paint()
      ..color = gridColor.withOpacity(0.55)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = top + chartHeight * i / 4;
      canvas.drawLine(
          Offset(left, y), Offset(size.width - right, y), gridPaint);
    }

    final groupWidth = chartWidth / points.length;
    final barWidth = math.min(14.0, groupWidth * 0.28);
    final incomePaint = Paint()..color = AppColors.success;
    final expensePaint = Paint()..color = AppColors.danger;

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final center = left + groupWidth * (i + 0.5);
      final incomeHeight = chartHeight * (point.totalIn / maxValue);
      final expenseHeight = chartHeight * (point.totalOut / maxValue);
      final baseline = top + chartHeight;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            center - barWidth - 2,
            baseline - incomeHeight,
            barWidth,
            incomeHeight,
          ),
          const Radius.circular(4),
        ),
        incomePaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            center + 2,
            baseline - expenseHeight,
            barWidth,
            expenseHeight,
          ),
          const Radius.circular(4),
        ),
        expensePaint,
      );

      final labelStep = math.max(1, (points.length / 6).ceil()).toInt();
      final showLabel = i % labelStep == 0 || i == points.length - 1;
      if (showLabel) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: DateFormat(points.length > 12 ? 'MMM yy' : 'MMM')
                .format(point.periodStart),
            style: TextStyle(color: labelColor, fontSize: 10),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          Offset(center - textPainter.width / 2, size.height - 20),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CashFlowPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor;
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.bar_chart_rounded,
                color: neutral.textDisabled, size: 42),
            const SizedBox(height: 8),
            Text(
              'No report data for this period',
              style: TextStyle(color: neutral.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 44),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: neutral.textSecondary),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
