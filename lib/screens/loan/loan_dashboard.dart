import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_x.dart';
import '../../models/LoanModel.dart';
import 'LoanDetailsPage.dart';
import 'khata_account_form_sheet.dart';
import 'khata_formatters.dart';
import 'khata_whatsapp_service.dart';
import 'loan_controller.dart';

class LoanDashboard extends ConsumerStatefulWidget {
  const LoanDashboard({super.key});

  @override
  ConsumerState<LoanDashboard> createState() => _LoanDashboardState();
}

class _LoanDashboardState extends ConsumerState<LoanDashboard> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final loansAsync = ref.watch(loanListProvider);
    final summaryAsync = ref.watch(loanSummaryProvider);
    final activityAsync = ref.watch(loanMonthlyActivityProvider);

    return Scaffold(
      backgroundColor: neutral.background,
      appBar: AppBar(
        backgroundColor: neutral.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Digital Khata',
              style: TextStyle(
                color: neutral.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
            Text(
              'Loans, credit and payment ledger',
              style: TextStyle(
                color: neutral.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sort accounts',
            onPressed: _showSortSheet,
            icon: Icon(Icons.sort_rounded, color: neutral.textPrimary),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ResponsivePageFrame(
        maxWidth: 1280,
        child: RefreshIndicator(
          onRefresh: () async {
            refreshKhata(ref);
            await ref.read(loanSummaryProvider.future);
          },
          child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: summaryAsync.when(
                data: (summary) => _summarySection(summary),
                loading: () => const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
                error: (error, _) => _errorCard('Summary unavailable', error),
              ),
            ),
            SliverToBoxAdapter(child: _searchAndFilters()),
            SliverToBoxAdapter(
              child: activityAsync.when(
                data: _monthlyActivityCard,
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
            SliverToBoxAdapter(child: _listHeader(loansAsync)),
            loansAsync.when(
              data: (loans) {
                if (loans.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _emptyState(),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList.builder(
                    itemCount: loans.length,
                    itemBuilder: (context, index) =>
                        _accountCard(loans[index]),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SliverFillRemaining(
                child: Center(child: Text('Unable to load khata: $error')),
              ),
            ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.loan,
        foregroundColor: Colors.white,
        onPressed: _addAccount,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text(
          'New Khata',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _summarySection(KhataDashboardSummary summary) {
    final neutral = context.themeColors.neutral;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.loan,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppColors.loan.withOpacity(0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Current Khata Position',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.86),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${summary.activeAccounts} active',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _heroAmount(
                        'You will receive',
                        summary.toReceive,
                        Icons.south_west_rounded,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 54,
                      color: Colors.white.withOpacity(0.22),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: _heroAmount(
                          'You will pay',
                          summary.toPay,
                          Icons.north_east_rounded,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _miniSummaryCard(
                  title: 'Overdue',
                  value: KhataFormatters.compactMoney(summary.overdueAmount),
                  subtitle: '${summary.overdueAccounts} accounts',
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniSummaryCard(
                  title: 'Collected',
                  value:
                      KhataFormatters.compactMoney(summary.collectedThisMonth),
                  subtitle: 'This month',
                  icon: Icons.trending_up_rounded,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniSummaryCard(
                  title: 'Settled',
                  value: '${summary.settledAccounts}',
                  subtitle: 'Accounts',
                  icon: Icons.verified_outlined,
                  color: AppColors.loan,
                ),
              ),
            ],
          ),
          if (summary.paidThisMonth > 0) ...[
            const SizedBox(height: 9),
            Row(
              children: [
                Icon(Icons.info_outline,
                    size: 15, color: neutral.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'You paid ${KhataFormatters.money(summary.paidThisMonth)} this month.',
                  style: TextStyle(
                    color: neutral.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _heroAmount(String label, double amount, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white, size: 17),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.78),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            KhataFormatters.compactMoney(amount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final neutral = context.themeColors.neutral;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: neutral.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 9),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: neutral.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$title · $subtitle',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: neutral.textSecondary, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _searchAndFilters() {
    final neutral = context.themeColors.neutral;
    final typeFilter = ref.watch(loanFilterProvider);
    final statusFilter = ref.watch(loanStatusFilterProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) =>
                ref.read(loanSearchProvider.notifier).state = value,
            decoration: InputDecoration(
              hintText: 'Search name, phone or reference number',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        ref.read(loanSearchProvider.notifier).state = '';
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
              filled: true,
              fillColor: neutral.card,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: neutral.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: neutral.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide:
                    const BorderSide(color: AppColors.loan, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _segmentedTypeButton(
                  'All',
                  2,
                  typeFilter,
                  Icons.people_alt_outlined,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _segmentedTypeButton(
                  'Receive',
                  0,
                  typeFilter,
                  Icons.south_west,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _segmentedTypeButton(
                  'Pay',
                  1,
                  typeFilter,
                  Icons.north_east,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _statusChip('active', 'Active', statusFilter),
                _statusChip('overdue', 'Overdue', statusFilter),
                _statusChip('due_soon', 'Due soon', statusFilter),
                _statusChip('settled', 'Settled', statusFilter),
                _statusChip('all', 'All history', statusFilter),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _segmentedTypeButton(
    String label,
    int value,
    int current,
    IconData icon,
  ) {
    final neutral = context.themeColors.neutral;
    final selected = current == value;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => ref.read(loanFilterProvider.notifier).state = value,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.loan : neutral.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.loan : neutral.divider,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? Colors.white : neutral.textSecondary,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : neutral.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String value, String label, String current) {
    final neutral = context.themeColors.neutral;
    final selected = current == value;
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: value == 'overdue' ? AppColors.danger : AppColors.loan,
        backgroundColor: neutral.card,
        side: BorderSide(
          color: selected
              ? (value == 'overdue' ? AppColors.danger : AppColors.loan)
              : neutral.divider,
        ),
        labelStyle: TextStyle(
          color: selected ? Colors.white : neutral.textPrimary,
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
        onSelected: (_) =>
            ref.read(loanStatusFilterProvider.notifier).state = value,
      ),
    );
  }

  Widget _monthlyActivityCard(List<KhataMonthlyActivity> activity) {
    if (activity.isEmpty) return const SizedBox.shrink();
    final neutral = context.themeColors.neutral;
    final maxValue = activity
        .expand((item) => [item.received, item.paid, item.chargesAdded])
        .fold<double>(0, (max, value) => value > max ? value : max);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: neutral.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined,
                  size: 19, color: AppColors.loan),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '6-Month Payment Activity',
                  style: TextStyle(
                    color: neutral.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              _legendDot(AppColors.success, 'Received'),
              const SizedBox(width: 8),
              _legendDot(AppColors.danger, 'Paid'),
            ],
          ),
          const SizedBox(height: 14),
          for (final item in activity) ...[
            Row(
              children: [
                SizedBox(
                  width: 47,
                  child: Text(
                    KhataFormatters.month(item.monthKey),
                    style: TextStyle(
                      color: neutral.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _activityBar(
                        maxValue == 0 ? 0 : item.received / maxValue,
                        AppColors.success,
                      ),
                      const SizedBox(height: 3),
                      _activityBar(
                        maxValue == 0 ? 0 : item.paid / maxValue,
                        AppColors.danger,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: Text(
                    KhataFormatters.compactMoney(item.received),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: neutral.textPrimary,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    final neutral = context.themeColors.neutral;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(color: neutral.textSecondary, fontSize: 8)),
      ],
    );
  }

  Widget _activityBar(double value, Color color) {
    final neutral = context.themeColors.neutral;
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0).toDouble(),
        minHeight: 5,
        backgroundColor: neutral.section,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }

  Widget _listHeader(AsyncValue<List<LoanModel>> loansAsync) {
    final neutral = context.themeColors.neutral;
    final sort = ref.watch(loanSortProvider);
    final count = loansAsync.asData?.value.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              count == null ? 'Khata Accounts' : 'Khata Accounts ($count)',
              style: TextStyle(
                color: neutral.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _showSortSheet,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.swap_vert,
                      size: 16, color: neutral.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    _sortLabel(sort),
                    style: TextStyle(
                      color: neutral.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountCard(LoanModel loan) {
    final neutral = context.themeColors.neutral;
    final snapshotAsync = ref.watch(loanSnapshotProvider(loan.id!));
    final accent = loan.isGiven ? AppColors.success : AppColors.danger;
    final overdue = loan.isOverdue;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LoanDetailsPage(loan: loan),
          ),
        );
        refreshKhata(ref, loanId: loan.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: neutral.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: overdue
                ? AppColors.danger.withOpacity(0.65)
                : neutral.divider,
            width: overdue ? 1.3 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _initials(loan.entityName),
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
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
                              loan.entityName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: neutral.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              loan.isGiven ? 'RECEIVE' : 'PAY',
                              style: TextStyle(
                                color: accent,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (loan.category.trim().isNotEmpty) loan.category,
                          if (loan.phone.trim().isNotEmpty) loan.phone,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: neutral.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            snapshotAsync.when(
              data: (snapshot) => Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Outstanding balance',
                              style: TextStyle(
                                color: neutral.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              KhataFormatters.money(
                                snapshot.outstanding,
                                currencyCode: loan.currencyCode,
                              ),
                              style: TextStyle(
                                color: snapshot.outstanding <= 0
                                    ? AppColors.success
                                    : accent,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'WhatsApp reminder',
                        onPressed: () => _sendReminder(loan, snapshot),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.success.withOpacity(0.1),
                        ),
                        icon: const Icon(
                          Icons.chat_outlined,
                          color: AppColors.success,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right,
                          color: neutral.textDisabled, size: 22),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: snapshot.progress,
                      minHeight: 6,
                      backgroundColor: neutral.section,
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${KhataFormatters.money(snapshot.totalCredits, currencyCode: loan.currencyCode)} cleared',
                          style: TextStyle(
                            color: neutral.textSecondary,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      _dueBadge(loan),
                    ],
                  ),
                ],
              ),
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (_, __) => Text(
                'Balance unavailable',
                style: TextStyle(color: neutral.textSecondary, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dueBadge(LoanModel loan) {
    final neutral = context.themeColors.neutral;
    final overdue = loan.isOverdue;
    final dueSoon = !overdue && loan.daysUntilDue <= loan.reminderDaysBefore;
    final color = loan.isSettled
        ? AppColors.success
        : overdue
            ? AppColors.danger
            : dueSoon
                ? AppColors.warning
                : neutral.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            overdue ? Icons.warning_amber_rounded : Icons.event_outlined,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            KhataFormatters.dueLabel(
              loan.dueDateTime,
              settled: loan.isSettled,
            ),
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    final neutral = context.themeColors.neutral;
    final query = ref.watch(loanSearchProvider);
    final status = ref.watch(loanStatusFilterProvider);
    final hasFilter = query.trim().isNotEmpty || status != 'active';

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 110),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: AppColors.loan.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasFilter ? Icons.search_off_rounded : Icons.menu_book_outlined,
              color: AppColors.loan,
              size: 38,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            hasFilter ? 'No matching khata found' : 'Start your digital khata',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: neutral.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilter
                ? 'Change the search or filters to view other accounts.'
                : 'Create an account, record credit and payments, track due dates and send WhatsApp reminders.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: neutral.textSecondary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          if (hasFilter) ...[
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Clear filters'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _errorCard(String title, Object error) {
    final neutral = context.themeColors.neutral;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$title: $error',
              style: TextStyle(color: neutral.textPrimary, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addAccount() async {
    final account = await showKhataAccountForm(context);
    if (account == null || !mounted) return;

    try {
      final id = await ref.read(loanServiceProvider).addLoan(account);
      refreshKhata(ref, loanId: id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${account.entityName} added to Digital Khata.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to create khata: $error')),
      );
    }
  }

  Future<void> _sendReminder(
    LoanModel loan,
    KhataAccountSnapshot snapshot,
  ) async {
    final message = KhataWhatsAppService.paymentReminder(
      loan: loan,
      snapshot: snapshot,
    );
    await KhataWhatsAppService.send(phone: loan.phone, message: message);
    await ref.read(loanServiceProvider).markReminderSent(loan.id!);
    ref.invalidate(loanByIdProvider(loan.id!));
  }

  void _clearFilters() {
    _searchController.clear();
    ref.read(loanSearchProvider.notifier).state = '';
    ref.read(loanFilterProvider.notifier).state = 2;
    ref.read(loanStatusFilterProvider.notifier).state = 'active';
    ref.read(loanSortProvider.notifier).state = 'smart';
    setState(() {});
  }

  Future<void> _showSortSheet() async {
    final neutral = context.themeColors.neutral;
    final current = ref.read(loanSortProvider);
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: neutral.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: neutral.divider,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Sort Khata Accounts',
                  style: TextStyle(
                    color: neutral.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final entry in const <String, String>{
                'smart': 'Smart priority',
                'due_date': 'Due date first',
                'latest': 'Recently added',
                'oldest': 'Oldest first',
                'name': 'Name A–Z',
                'balance_high': 'Highest opening balance',
              }.entries)
                RadioListTile<String>(
                  value: entry.key,
                  groupValue: current,
                  activeColor: AppColors.loan,
                  title: Text(
                    entry.value,
                    style: TextStyle(color: neutral.textPrimary),
                  ),
                  onChanged: (value) => Navigator.pop(context, value),
                ),
            ],
          ),
        ),
      ),
    );

    if (selected != null) {
      ref.read(loanSortProvider.notifier).state = selected;
    }
  }

  static String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final end = words.first.length >= 2 ? 2 : 1;
      return words.first.substring(0, end).toUpperCase();
    }
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  static String _sortLabel(String value) {
    return switch (value) {
      'due_date' => 'Due date',
      'latest' => 'Latest',
      'oldest' => 'Oldest',
      'name' => 'Name',
      'balance_high' => 'Highest',
      _ => 'Smart',
    };
  }
}
