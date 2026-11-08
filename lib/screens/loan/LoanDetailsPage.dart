import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_x.dart';
import '../../models/LoanModel.dart';
import 'khata_account_form_sheet.dart';
import 'khata_formatters.dart';
import 'khata_transaction_sheet.dart';
import 'khata_whatsapp_service.dart';
import 'loan_controller.dart';
import '../navigation/widgets/desktop_content_frame.dart';

class LoanDetailsPage extends ConsumerWidget {
  const LoanDetailsPage({super.key, required this.loan});

  final LoanModel loan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLoanAsync = ref.watch(loanByIdProvider(loan.id!));
    final neutral = context.themeColors.neutral;

    return currentLoanAsync.when(
      data: (currentLoan) {
        if (currentLoan == null) {
          return Scaffold(
            backgroundColor: neutral.background,
            appBar: AppBar(backgroundColor: neutral.background),
            body: DesktopContentFrame(
              child: const Center(child: Text('This khata account was removed.')),
            ),
          );
        }
        return _buildDetails(context, ref, currentLoan);
      },
      loading: () => Scaffold(
        backgroundColor: neutral.background,
        appBar: AppBar(backgroundColor: neutral.background),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: neutral.background,
        appBar: AppBar(backgroundColor: neutral.background),
        body: Center(child: Text('Unable to load khata: $error')),
      ),
    );
  }

  Widget _buildDetails(
    BuildContext context,
    WidgetRef ref,
    LoanModel currentLoan,
  ) {
    final neutral = context.themeColors.neutral;
    final snapshotAsync = ref.watch(loanSnapshotProvider(currentLoan.id!));
    final transactionsAsync =
        ref.watch(loanTransactionsProvider(currentLoan.id!));
    final accent = currentLoan.isGiven ? AppColors.success : AppColors.danger;

    return Scaffold(
      backgroundColor: neutral.background,
      appBar: AppBar(
        backgroundColor: neutral.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currentLoan.entityName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: neutral.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              currentLoan.isGiven ? 'Money to receive' : 'Money to pay',
              style: TextStyle(color: accent, fontSize: 10),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Edit account',
            onPressed: () => _editAccount(context, ref, currentLoan),
            icon: Icon(Icons.edit_outlined, color: neutral.textPrimary),
          ),
          PopupMenuButton<String>(
            color: neutral.card,
            onSelected: (value) {
              if (value == 'archive') {
                _archiveAccount(context, ref, currentLoan);
              } else if (value == 'delete') {
                _deleteAccount(context, ref, currentLoan);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(Icons.archive_outlined,
                        color: neutral.textSecondary, size: 20),
                    const SizedBox(width: 10),
                    const Text('Archive account'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline,
                        color: AppColors.danger, size: 20),
                    SizedBox(width: 10),
                    Text('Delete permanently',
                        style: TextStyle(color: AppColors.danger)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          refreshKhata(ref, loanId: currentLoan.id);
          await ref.read(loanSnapshotProvider(currentLoan.id!).future);
        },
        child: snapshotAsync.when(
          data: (snapshot) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            children: [
              _balanceCard(context, currentLoan, snapshot, accent),
              const SizedBox(height: 14),
              _quickActions(
                context,
                ref,
                currentLoan,
                snapshot,
                transactionsAsync.asData?.value ?? const <LoanTransaction>[],
                accent,
              ),
              const SizedBox(height: 16),
              _balanceBreakdown(context, currentLoan, snapshot),
              const SizedBox(height: 14),
              _accountInfoCard(context, currentLoan),
              const SizedBox(height: 20),
              _ledgerHeader(context, snapshot.entryCount),
              const SizedBox(height: 10),
              transactionsAsync.when(
                data: (transactions) => _ledgerList(
                  context,
                  ref,
                  currentLoan,
                  snapshot,
                  transactions,
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => _messageCard(
                  context,
                  Icons.error_outline,
                  'Unable to load ledger entries: $error',
                ),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Balance error: $error')),
        ),
      ),
      bottomNavigationBar: snapshotAsync.asData?.value == null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                decoration: BoxDecoration(
                  color: neutral.background,
                  border: Border(top: BorderSide(color: neutral.divider)),
                ),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: () => _addEntry(
                    context,
                    ref,
                    currentLoan,
                    snapshotAsync.asData!.value,
                  ),
                  icon: const Icon(Icons.add_card_outlined),
                  label: const Text(
                    'Add Ledger Entry',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _balanceCard(
    BuildContext context,
    LoanModel loan,
    KhataAccountSnapshot snapshot,
    Color accent,
  ) {
    final overdue = loan.isOverdue && snapshot.outstanding > 0;
    final settled = snapshot.outstanding <= 0.005;
    final statusColor = settled
        ? AppColors.success
        : overdue
            ? AppColors.danger
            : AppColors.warning;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent, accent.withOpacity(0.78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.22),
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
                  loan.isGiven ? 'Outstanding Receivable' : 'Outstanding Payable',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      settled
                          ? Icons.verified_outlined
                          : overdue
                              ? Icons.warning_amber_rounded
                              : Icons.schedule,
                      color: Colors.white,
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      settled
                          ? 'SETTLED'
                          : overdue
                              ? 'OVERDUE'
                              : 'ACTIVE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              KhataFormatters.money(
                snapshot.outstanding,
                currencyCode: loan.currencyCode,
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: snapshot.progress,
              minHeight: 7,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${(snapshot.progress * 100).toStringAsFixed(0)}% cleared',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
                    fontSize: 11,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(settled ? 0.95 : 0.88),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  KhataFormatters.dueLabel(
                    loan.dueDateTime,
                    settled: settled,
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickActions(
    BuildContext context,
    WidgetRef ref,
    LoanModel loan,
    KhataAccountSnapshot snapshot,
    List<LoanTransaction> transactions,
    Color accent,
  ) {
    return Row(
      children: [
        Expanded(
          child: _quickAction(
            context,
            label: 'Payment',
            icon: Icons.payments_outlined,
            color: AppColors.success,
            onTap: snapshot.outstanding <= 0.005
                ? null
                : () => _addEntry(
                      context,
                      ref,
                      loan,
                      snapshot,
                      initialType: 'payment',
                    ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _quickAction(
            context,
            label: 'Add Credit',
            icon: Icons.add_card_outlined,
            color: AppColors.danger,
            onTap: () => _addEntry(
              context,
              ref,
              loan,
              snapshot,
              initialType: 'charge',
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _quickAction(
            context,
            label: 'WhatsApp',
            icon: Icons.chat_outlined,
            color: AppColors.success,
            onTap: () => _showWhatsAppOptions(
              context,
              ref,
              loan,
              snapshot,
              transactions,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _quickAction(
            context,
            label: 'Statement',
            icon: Icons.receipt_long_outlined,
            color: accent,
            onTap: () => KhataWhatsAppService.share(
              KhataWhatsAppService.accountStatement(
                loan: loan,
                snapshot: snapshot,
                recentTransactions: transactions,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _quickAction(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final neutral = context.themeColors.neutral;
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          decoration: BoxDecoration(
            color: neutral.card,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: neutral.divider),
          ),
          child: Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.11),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: neutral.textPrimary,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _balanceBreakdown(
    BuildContext context,
    LoanModel loan,
    KhataAccountSnapshot snapshot,
  ) {
    final neutral = context.themeColors.neutral;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: neutral.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Balance Breakdown',
            style: TextStyle(
              color: neutral.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _breakdownItem(
                  context,
                  'Opening',
                  snapshot.openingAmount,
                  loan.currencyCode,
                  Icons.flag_outlined,
                  AppColors.loan,
                ),
              ),
              Expanded(
                child: _breakdownItem(
                  context,
                  'Added',
                  snapshot.addedCharges,
                  loan.currencyCode,
                  Icons.add_circle_outline,
                  AppColors.danger,
                ),
              ),
              Expanded(
                child: _breakdownItem(
                  context,
                  'Payments',
                  snapshot.payments,
                  loan.currencyCode,
                  Icons.check_circle_outline,
                  AppColors.success,
                ),
              ),
              Expanded(
                child: _breakdownItem(
                  context,
                  'Discount',
                  snapshot.discounts,
                  loan.currencyCode,
                  Icons.local_offer_outlined,
                  AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _breakdownItem(
    BuildContext context,
    String label,
    double amount,
    String currency,
    IconData icon,
    Color color,
  ) {
    final neutral = context.themeColors.neutral;
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            KhataFormatters.compactMoney(amount, currencyCode: currency),
            style: TextStyle(
              color: neutral.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(color: neutral.textSecondary, fontSize: 9),
        ),
      ],
    );
  }

  Widget _accountInfoCard(BuildContext context, LoanModel loan) {
    final neutral = context.themeColors.neutral;
    final rows = <Widget>[
      _infoRow(
        context,
        Icons.calendar_today_outlined,
        'Started',
        KhataFormatters.date(loan.startDate),
      ),
      _infoRow(
        context,
        Icons.event_available_outlined,
        'Due date',
        KhataFormatters.date(loan.dueDate),
      ),
      if (loan.phone.trim().isNotEmpty)
        _infoRow(context, Icons.phone_outlined, 'WhatsApp', loan.phone),
      if (loan.referenceNumber.trim().isNotEmpty)
        _infoRow(
          context,
          Icons.tag,
          'Reference',
          loan.referenceNumber,
          onTap: () {
            Clipboard.setData(ClipboardData(text: loan.referenceNumber));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Reference number copied.')),
            );
          },
        ),
      _infoRow(
        context,
        Icons.event_repeat_outlined,
        'Installment',
        loan.installmentFrequency == 'none'
            ? 'No fixed schedule'
            : '${KhataFormatters.titleCase(loan.installmentFrequency)} · '
                '${KhataFormatters.money(loan.installmentAmount, currencyCode: loan.currencyCode)}',
      ),
      _infoRow(
        context,
        Icons.notifications_active_outlined,
        'Reminder',
        loan.reminderEnabled
            ? '${loan.reminderDaysBefore} days before due date'
            : 'Disabled',
      ),
      if (loan.address.trim().isNotEmpty)
        _infoRow(context, Icons.location_on_outlined, 'Address', loan.address),
      if (loan.notes.trim().isNotEmpty)
        _infoRow(context, Icons.notes_outlined, 'Notes', loan.notes),
    ];

    return Container(
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
              Expanded(
                child: Text(
                  'Account Details',
                  style: TextStyle(
                    color: neutral.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.loan.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  loan.category,
                  style: const TextStyle(
                    color: AppColors.loan,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < rows.length; index++) ...[
            rows[index],
            if (index != rows.length - 1)
              Divider(height: 16, color: neutral.divider),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    final neutral = context.themeColors.neutral;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: neutral.textSecondary),
            const SizedBox(width: 10),
            SizedBox(
              width: 78,
              child: Text(
                label,
                style: TextStyle(
                  color: neutral.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: neutral.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 5),
              Icon(Icons.copy, size: 14, color: neutral.textSecondary),
            ],
          ],
        ),
      ),
    );
  }

  Widget _ledgerHeader(BuildContext context, int count) {
    final neutral = context.themeColors.neutral;
    return Row(
      children: [
        Expanded(
          child: Text(
            'Khata Ledger',
            style: TextStyle(
              color: neutral.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
        ),
        Text(
          '$count ${count == 1 ? 'entry' : 'entries'}',
          style: TextStyle(color: neutral.textSecondary, fontSize: 10),
        ),
      ],
    );
  }

  Widget _ledgerList(
    BuildContext context,
    WidgetRef ref,
    LoanModel loan,
    KhataAccountSnapshot snapshot,
    List<LoanTransaction> transactions,
  ) {
    if (transactions.isEmpty) {
      return _messageCard(
        context,
        Icons.receipt_long_outlined,
        'No ledger entries yet. Add a payment, new credit, markup or discount.',
      );
    }

    return Column(
      children: [
        for (final transaction in transactions)
          _transactionTile(
            context,
            ref,
            loan,
            snapshot,
            transaction,
          ),
      ],
    );
  }

  Widget _transactionTile(
    BuildContext context,
    WidgetRef ref,
    LoanModel loan,
    KhataAccountSnapshot snapshot,
    LoanTransaction transaction,
  ) {
    final neutral = context.themeColors.neutral;
    final color = _transactionColor(transaction.transactionType);
    final icon = _transactionIcon(transaction.transactionType);
    final sign = transaction.increasesBalance ? '+' : '-';

    return Dismissible(
      key: ValueKey('khata-entry-${transaction.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDeleteEntry(context),
      onDismissed: (_) async {
        await ref
            .read(loanServiceProvider)
            .deleteTransaction(transaction.id!, loan.id!);
        refreshKhata(ref, loanId: loan.id);
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.danger),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _editEntry(
            context,
            ref,
            loan,
            snapshot,
            transaction,
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: neutral.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: neutral.divider),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.11),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              transaction.note.trim().isEmpty
                                  ? KhataFormatters.titleCase(
                                      transaction.transactionType,
                                    )
                                  : transaction.note,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: neutral.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '$sign${KhataFormatters.money(transaction.amount, currencyCode: loan.currencyCode)}',
                            style: TextStyle(
                              color: color,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              KhataFormatters.dateTime(transaction.date),
                              style: TextStyle(
                                color: neutral.textSecondary,
                                fontSize: 9,
                              ),
                            ),
                          ),
                          if (transaction.transactionType == 'payment')
                            Text(
                              KhataFormatters.titleCase(
                                transaction.paymentMethod,
                              ),
                              style: TextStyle(
                                color: neutral.textSecondary,
                                fontSize: 9,
                              ),
                            ),
                        ],
                      ),
                      if (transaction.referenceNumber.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Ref: ${transaction.referenceNumber}',
                          style: TextStyle(
                            color: neutral.textSecondary,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _messageCard(BuildContext context, IconData icon, String text) {
    final neutral = context.themeColors.neutral;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: neutral.divider),
      ),
      child: Column(
        children: [
          Icon(icon, color: neutral.textDisabled, size: 32),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: neutral.textSecondary,
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addEntry(
    BuildContext context,
    WidgetRef ref,
    LoanModel loan,
    KhataAccountSnapshot snapshot, {
    String initialType = 'payment',
  }) async {
    final entry = await showKhataTransactionSheet(
      context,
      loan: loan,
      outstanding: snapshot.outstanding,
      initialType: initialType,
    );
    if (entry == null || !context.mounted) return;

    try {
      await ref.read(loanServiceProvider).addTransaction(entry);
      refreshKhata(ref, loanId: loan.id);
      if (!context.mounted) return;

      final isPayment = entry.transactionType == 'payment';
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isPayment ? 'Payment recorded successfully.' : 'Ledger entry added.',
          ),
          action: isPayment
              ? SnackBarAction(
                  label: 'Send receipt',
                  onPressed: () async {
                    final updatedSnapshot = await ref
                        .read(loanServiceProvider)
                        .getAccountSnapshot(loan.id!);
                    await KhataWhatsAppService.send(
                      phone: loan.phone,
                      message: KhataWhatsAppService.paymentThankYou(
                        loan: loan,
                        snapshot: updatedSnapshot,
                        payment: entry,
                      ),
                    );
                  },
                )
              : null,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save entry: $error')),
      );
    }
  }

  Future<void> _editEntry(
    BuildContext context,
    WidgetRef ref,
    LoanModel loan,
    KhataAccountSnapshot snapshot,
    LoanTransaction transaction,
  ) async {
    final updated = await showKhataTransactionSheet(
      context,
      loan: loan,
      outstanding: snapshot.outstanding +
          (transaction.reducesBalance ? transaction.amount : 0),
      existing: transaction,
    );
    if (updated == null) return;

    await ref.read(loanServiceProvider).updateTransaction(updated);
    refreshKhata(ref, loanId: loan.id);
  }

  Future<void> _editAccount(
    BuildContext context,
    WidgetRef ref,
    LoanModel loan,
  ) async {
    final updated = await showKhataAccountForm(context, existing: loan);
    if (updated == null) return;

    await ref.read(loanServiceProvider).updateLoan(updated);
    refreshKhata(ref, loanId: loan.id);
  }

  Future<void> _showWhatsAppOptions(
    BuildContext context,
    WidgetRef ref,
    LoanModel loan,
    KhataAccountSnapshot snapshot,
    List<LoanTransaction> transactions,
  ) async {
    final neutral = context.themeColors.neutral;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: neutral.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
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
                  'WhatsApp Message',
                  style: TextStyle(
                    color: neutral.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x1A25D366),
                  child: Icon(Icons.notifications_active_outlined,
                      color: AppColors.success),
                ),
                title: const Text('Payment reminder'),
                subtitle: const Text('Send current balance and due date'),
                onTap: () => Navigator.pop(context, 'reminder'),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x1A5063F0),
                  child: Icon(Icons.receipt_long_outlined,
                      color: AppColors.loan),
                ),
                title: const Text('Account statement'),
                subtitle: const Text('Send balance summary and recent entries'),
                onTap: () => Navigator.pop(context, 'statement'),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected == null) return;
    final message = selected == 'statement'
        ? KhataWhatsAppService.accountStatement(
            loan: loan,
            snapshot: snapshot,
            recentTransactions: transactions,
          )
        : KhataWhatsAppService.paymentReminder(
            loan: loan,
            snapshot: snapshot,
          );
    await KhataWhatsAppService.send(phone: loan.phone, message: message);
    await ref.read(loanServiceProvider).markReminderSent(loan.id!);
    ref.invalidate(loanByIdProvider(loan.id!));
  }

  Future<void> _archiveAccount(
    BuildContext context,
    WidgetRef ref,
    LoanModel loan,
  ) async {
    final confirmed = await _confirmationDialog(
      context,
      title: 'Archive khata account?',
      message:
          'The account will be hidden from the active list but its ledger will remain in the database and backup.',
      actionLabel: 'Archive',
      destructive: false,
    );
    if (!confirmed) return;

    await ref.read(loanServiceProvider).archiveLoan(loan.id!);
    refreshKhata(ref, loanId: loan.id);
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _deleteAccount(
    BuildContext context,
    WidgetRef ref,
    LoanModel loan,
  ) async {
    final confirmed = await _confirmationDialog(
      context,
      title: 'Delete khata permanently?',
      message:
          'This will permanently delete the account and every ledger entry. This cannot be undone.',
      actionLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;

    await ref.read(loanServiceProvider).deleteLoan(loan.id!);
    refreshKhata(ref, loanId: loan.id);
    if (context.mounted) Navigator.pop(context);
  }

  Future<bool> _confirmDeleteEntry(BuildContext context) {
    return _confirmationDialog(
      context,
      title: 'Delete ledger entry?',
      message: 'The outstanding balance will be recalculated immediately.',
      actionLabel: 'Delete',
      destructive: true,
    );
  }

  Future<bool> _confirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String actionLabel,
    required bool destructive,
  }) async {
    final neutral = context.themeColors.neutral;
    final result = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        backgroundColor: neutral.card,
        title: Text(title, style: TextStyle(color: neutral.textPrimary)),
        content: Text(message, style: TextStyle(color: neutral.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: neutral.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  destructive ? AppColors.danger : AppColors.loan,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static Color _transactionColor(String type) {
    return switch (type) {
      'payment' => AppColors.success,
      'discount' => AppColors.loan,
      'interest' => AppColors.warning,
      _ => AppColors.danger,
    };
  }

  static IconData _transactionIcon(String type) {
    return switch (type) {
      'payment' => Icons.south_west_rounded,
      'discount' => Icons.local_offer_outlined,
      'interest' => Icons.percent,
      _ => Icons.add_rounded,
    };
  }
}
