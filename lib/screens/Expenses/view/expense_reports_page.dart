import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_x.dart';
import '../../../core/widgets/common/centered_fa_icon.dart';
import 'package:metersystem/models/ExpenseReport.dart';
import '../components/expense_category_style.dart';
import '../controller/ExpensesController.dart';
import '../../navigation/widgets/desktop_content_frame.dart';
part '../components/expense_report_widgets.dart';

enum ExpenseReportRange {
  currentMonth,
  threeMonths,
  sixMonths,
  twelveMonths,
  allTime,
}

class ExpenseReportsPage extends ConsumerStatefulWidget {
  const ExpenseReportsPage({super.key});

  @override
  ConsumerState<ExpenseReportsPage> createState() => _ExpenseReportsPageState();
}

class _ExpenseReportsPageState extends ConsumerState<ExpenseReportsPage> {
  ExpenseReportRange _range = ExpenseReportRange.sixMonths;
  Future<ExpenseReportData>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<ExpenseReportData> _load() {
    final dates = _rangeDates(_range);
    return ref.read(dbExpenseServiceProvider).fetchReportData(
          startDate: dates.$1,
          endDate: dates.$2,
        );
  }

  void _changeRange(ExpenseReportRange range) {
    setState(() {
      _range = range;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final isDesktop = MediaQuery.sizeOf(context).width >= 1100;

    return Scaffold(
      backgroundColor: neutral.background,
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: neutral.background,
              elevation: 0,
              title: Text(
                'Expense reports',
                style: TextStyle(color: neutral.textPrimary),
              ),
              actions: [
                IconButton(
                  tooltip: 'Refresh report',
                  onPressed: () => setState(() => _future = _load()),
                  icon: Icon(Icons.refresh, color: neutral.textPrimary),
                ),
              ],
            ),
      body: DesktopContentFrame(
        maxWidth: 1480,
        child: FutureBuilder<ExpenseReportData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorState(
                message: snapshot.error.toString(),
                onRetry: () => setState(() => _future = _load()),
              );
            }
            final report = snapshot.data!;

            if (isDesktop) {
              return RefreshIndicator(
                onRefresh: () async {
                  final future = _load();
                  setState(() => _future = future);
                  await future;
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Expense reports',
                                style: TextStyle(
                                  color: neutral.textPrimary,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${DateFormat('dd MMM yyyy').format(report.startDate)} – '
                                '${DateFormat('dd MMM yyyy').format(report.endDate)}',
                                style: TextStyle(
                                  color: neutral.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 390,
                          child: _RangeSelector(
                            value: _range,
                            onChanged: _changeRange,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => setState(() => _future = _load()),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Refresh'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SummaryGrid(report: report),
                    const SizedBox(height: 16),
                    _InsightCard(report: report),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _SectionCard(
                            title: 'Monthly cash flow',
                            subtitle: 'Income and expense comparison',
                            child: report.trend.isEmpty
                                ? const _EmptyChart()
                                : SizedBox(
                                    height: 310,
                                    child: _CashFlowChart(points: report.trend),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: _SectionCard(
                            title: 'Category breakdown',
                            subtitle:
                                'Hidden categories are included and marked.',
                            child: _CategoryBreakdown(report: report),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                final future = _load();
                setState(() => _future = future);
                await future;
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  _RangeSelector(value: _range, onChanged: _changeRange),
                  const SizedBox(height: 14),
                  Text(
                    '${DateFormat('dd MMM yyyy').format(report.startDate)} – '
                    '${DateFormat('dd MMM yyyy').format(report.endDate)}',
                    style: TextStyle(
                      color: neutral.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SummaryGrid(report: report),
                  const SizedBox(height: 16),
                  _InsightCard(report: report),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Monthly cash flow',
                    subtitle: 'Income and expense comparison',
                    child: report.trend.isEmpty
                        ? const _EmptyChart()
                        : SizedBox(
                            height: 240,
                            child: _CashFlowChart(points: report.trend),
                          ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Category breakdown',
                    subtitle:
                        'Hidden categories are included in calculations and marked below.',
                    child: _CategoryBreakdown(report: report),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  (DateTime, DateTime) _rangeDates(ExpenseReportRange range) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    switch (range) {
      case ExpenseReportRange.currentMonth:
        return (DateTime(now.year, now.month, 1), end);
      case ExpenseReportRange.threeMonths:
        return (DateTime(now.year, now.month - 2, 1), end);
      case ExpenseReportRange.sixMonths:
        return (DateTime(now.year, now.month - 5, 1), end);
      case ExpenseReportRange.twelveMonths:
        return (DateTime(now.year, now.month - 11, 1), end);
      case ExpenseReportRange.allTime:
        return (DateTime(2000, 1, 1), end);
    }
  }
}

