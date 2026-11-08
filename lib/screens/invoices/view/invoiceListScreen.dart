import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_tokens.dart';
import '../../../core/design/responsive_layout.dart';
import '../../../core/theme/theme_x.dart';
import '../../../core/widgets/common/app_empty_state.dart';
import '../../../core/widgets/common/app_surface.dart';
import '../../navigation/widgets/desktop_navigation_scope.dart';
import '../data/invoiceProvider.dart';
import '../data/invoice_model.dart';
import 'InvoiceDataManagementScreen.dart';

class InvoiceListScreen extends ConsumerStatefulWidget {
  const InvoiceListScreen({
    super.key,
    this.desktopEmbedded = false,
    this.filter = 'all',
    this.onCreateInvoice,
    this.onOpenInvoice,
    this.onManageData,
  });

  final bool desktopEmbedded;
  final String filter;
  final VoidCallback? onCreateInvoice;
  final ValueChanged<Invoice>? onOpenInvoice;
  final VoidCallback? onManageData;

  @override
  ConsumerState<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends ConsumerState<InvoiceListScreen> {
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(invoicesProvider.notifier).loadInvoices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final invoices = ref.watch(invoicesProvider);
    final query = _search.trim().toLowerCase();
    final filtered = invoices.where((invoice) {
      final effectiveStatus = invoice.isPaid ? 'paid' : invoice.status;
      final matchesFilter = switch (widget.filter) {
        'draft' => effectiveStatus == 'draft',
        'paid' => invoice.isPaid || effectiveStatus == 'paid',
        'outstanding' => !invoice.isPaid && effectiveStatus != 'draft',
        _ => true,
      };
      if (!matchesFilter) return false;
      return invoice.number.toLowerCase().contains(query) ||
          invoice.customerName.toLowerCase().contains(query) ||
          invoice.businessName.toLowerCase().contains(query) ||
          invoice.status.toLowerCase().contains(query);
    }).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitle),
        actions: [
          IconButton(
            tooltip: 'Manage businesses, customers and invoice defaults',
            icon: const Icon(Icons.manage_accounts_outlined),
            onPressed: widget.onManageData ??
                () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const InvoiceDataManagementScreen(),
                      ),
                    ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: IconButton.filledTonal(
              tooltip: 'Create invoice',
              icon: const Icon(Icons.add_rounded),
              onPressed: _openCreateInvoice,
            ),
          ),
        ],
      ),
      body: ResponsivePageFrame(
        maxWidth: 1280,
        child: RefreshIndicator(
          onRefresh: () => ref.read(invoicesProvider.notifier).loadInvoices(),
          child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildSearch()),
            if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: query.isEmpty ? 'No invoices yet' : 'No matches found',
                  message: query.isEmpty
                      ? 'Create your first invoice to start tracking billing.'
                      : 'Try another invoice number or customer name.',
                  actionLabel: query.isEmpty ? 'Create invoice' : null,
                  onAction: query.isEmpty ? _openCreateInvoice : null,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                sliver: SliverList.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _InvoiceCard(
                    invoice: filtered[index],
                    onTap: widget.onOpenInvoice == null
                        ? null
                        : () => widget.onOpenInvoice!(filtered[index]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _pageTitle => switch (widget.filter) {
        'draft' => 'Draft invoices',
        'paid' => 'Paid invoices',
        'outstanding' => 'Outstanding invoices',
        _ => 'Invoices',
      };

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: TextField(
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          hintText: 'Search invoice, customer, business or status',
          prefixIcon: Icon(Icons.search_rounded),
        ),
        onChanged: (value) => setState(() => _search = value),
      ),
    );
  }

  void _openCreateInvoice() {
    final callback = widget.onCreateInvoice;
    if (callback != null) {
      callback();
      return;
    }
    openResponsiveModule(context, '/invoices/new');
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice, this.onTap});

  final Invoice invoice;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Color(invoice.accentColorValue);
    final effectiveStatus = invoice.isPaid ? 'paid' : invoice.status;

    return AppSurface(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        leading: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withOpacity(context.isDarkMode ? .20 : .11),
            borderRadius: AppRadius.small,
          ),
          child: Icon(Icons.receipt_long_outlined, color: accent),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Invoice #${invoice.number}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: accent.withOpacity(.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _statusLabel(effectiveStatus),
                style: context.textTheme.labelSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${invoice.customerName}\n'
          '${DateFormat.yMMMd().format(invoice.date)} • '
          'Due ${DateFormat.MMMd().format(invoice.dueDate)}',
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${invoice.currencySymbol}${invoice.total.toStringAsFixed(2)}',
              style: context.textTheme.titleSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              invoice.balanceDue <= .009
                  ? 'Paid in full'
                  : 'Due ${invoice.currencySymbol}${invoice.balanceDue.toStringAsFixed(2)}',
              style: context.textTheme.bodySmall,
            ),
          ],
        ),
        onTap: onTap ??
            () => openResponsiveModule(context, '/invoices/${invoice.id}'),
      ),
    );
  }

  String _statusLabel(String value) {
    if (value == 'partially_paid') return 'Partially paid';
    if (value.isEmpty) return 'Draft';
    return '${value[0].toUpperCase()}${value.substring(1).replaceAll('_', ' ')}';
  }
}
