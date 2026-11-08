import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_x.dart';
import '../data/invoiceProvider.dart';
import '../data/invoice_model.dart';
import 'PdfInvoiceService.dart';
import '../../navigation/widgets/desktop_content_frame.dart';

class InvoiceViewScreen extends ConsumerWidget {
  final String id;
  final bool desktopEmbedded;
  final ValueChanged<Invoice>? onEdit;

  const InvoiceViewScreen({
    super.key,
    required this.id,
    this.desktopEmbedded = false,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neutral = context.themeColors.neutral;
    final invoices = ref.watch(invoicesProvider);
    Invoice? invoice;
    for (final value in invoices) {
      if (value.id == id) {
        invoice = value;
        break;
      }
    }

    if (invoice == null) {
      return Scaffold(
        backgroundColor: neutral.background,
        appBar: AppBar(
          backgroundColor: neutral.background,
          title: const Text('Invoice'),
        ),
        body: DesktopContentFrame(
          child: Center(
          child: Text(
            'Invoice not found',
            style: TextStyle(color: neutral.textSecondary),
          ),
        ),
        ),
      );
    }

    final currentInvoice = invoice;
    final accent = Color(currentInvoice.accentColorValue);

    return Scaffold(
      backgroundColor: neutral.background,
      appBar: AppBar(
        backgroundColor: neutral.background,
        elevation: 0,
        title: Text(
          'Invoice #${currentInvoice.number}',
          style: TextStyle(
            color: neutral.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Edit invoice',
            icon: Icon(Icons.edit_outlined, color: accent),
            onPressed: () {
              final callback = onEdit;
              if (callback != null) {
                callback(currentInvoice);
                return;
              }
              context.push(
                '/invoices/${currentInvoice.id}/edit',
                extra: currentInvoice,
              );
            },
          ),
          IconButton(
            tooltip: 'PDF preview',
            icon: Icon(Icons.picture_as_pdf_outlined, color: accent),
            onPressed: () => PdfInvoiceService.generateAndPreview(
              currentInvoice,
              context,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'More actions',
            onSelected: (action) => _handleAction(
              context,
              ref,
              currentInvoice,
              action,
            ),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'save',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.download_outlined),
                  title: Text('Save PDF anywhere'),
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.share_outlined),
                  title: Text('Share PDF'),
                ),
              ),
              PopupMenuItem(
                value: 'print',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.print_outlined),
                  title: Text('Print invoice'),
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline, color: Colors.red),
                  title: Text('Delete invoice'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        child: Column(
          children: [
            _hero(context, currentInvoice, accent),
            const SizedBox(height: 16),
            _parties(context, currentInvoice),
            const SizedBox(height: 16),
            _items(context, currentInvoice, accent),
            const SizedBox(height: 16),
            _totals(context, currentInvoice, accent),
            const SizedBox(height: 16),
            _details(context, currentInvoice, accent),
            const SizedBox(height: 16),
            _actionBar(context, currentInvoice, accent),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    Invoice invoice,
    String action,
  ) async {
    try {
      switch (action) {
        case 'save':
          await PdfInvoiceService.savePdf(invoice, context: context);
          break;
        case 'share':
          await PdfInvoiceService.sharePdf(invoice);
          break;
        case 'print':
          await PdfInvoiceService.printPdf(invoice);
          break;
        case 'delete':
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Delete invoice?'),
              content: Text(
                'Invoice #${invoice.number} will be permanently deleted.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                  ),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await ref.read(invoicesProvider.notifier).deleteInvoice(invoice.id);
            if (context.mounted) {
              if (desktopEmbedded) {
                Navigator.of(context).pop();
              } else {
                context.pop();
              }
            }
          }
          break;
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invoice action failed: $error')),
      );
    }
  }

  Widget _hero(BuildContext context, Invoice invoice, Color accent) {
    final neutral = context.themeColors.neutral;
    final logoExists =
        invoice.logoPath != null && File(invoice.logoPath!).existsSync();
    final backgroundExists = invoice.backgroundImagePath != null &&
        File(invoice.backgroundImagePath!).existsSync();

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(.25)),
      ),
      child: Stack(
        children: [
          if (backgroundExists)
            Positioned.fill(
              child: Opacity(
                opacity: invoice.backgroundOpacity.clamp(.02, .20).toDouble(),
                child: Image.file(
                  File(invoice.backgroundImagePath!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (logoExists) ...[
                      Container(
                        width: 62,
                        height: 62,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: neutral.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: neutral.divider),
                        ),
                        child: Image.file(
                          File(invoice.logoPath!),
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoice.businessName.isEmpty
                                ? 'Invoice'
                                : invoice.businessName,
                            style: TextStyle(
                              color: neutral.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (invoice.businessAddress.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              invoice.businessAddress,
                              style: TextStyle(
                                color: neutral.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _statusChip(context, invoice, accent),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _heroMetric(
                        context,
                        'Invoice',
                        '#${invoice.number}',
                      ),
                    ),
                    Expanded(
                      child: _heroMetric(
                        context,
                        'Issued',
                        DateFormat.yMMMd().format(invoice.date),
                      ),
                    ),
                    Expanded(
                      child: _heroMetric(
                        context,
                        'Due',
                        DateFormat.yMMMd().format(invoice.dueDate),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroMetric(BuildContext context, String label, String value) {
    final neutral = context.themeColors.neutral;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: neutral.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: neutral.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _statusChip(BuildContext context, Invoice invoice, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withOpacity(.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(.35)),
      ),
      child: Text(
        _statusLabel(invoice.isPaid ? 'paid' : invoice.status),
        style: TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _parties(BuildContext context, Invoice invoice) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _sectionCard(
            context,
            title: 'From',
            icon: Icons.storefront_outlined,
            children: [
              _strong(context, invoice.businessName),
              if (invoice.businessAddress.isNotEmpty)
                _muted(context, invoice.businessAddress),
              if (invoice.businessEmail != null)
                _muted(context, invoice.businessEmail!),
              if (invoice.businessPhone != null)
                _muted(context, invoice.businessPhone!),
              if (invoice.businessTaxId != null)
                _muted(context, 'Tax ID: ${invoice.businessTaxId}'),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _sectionCard(
            context,
            title: 'Bill to',
            icon: Icons.person_outline,
            children: [
              _strong(context, invoice.customerName),
              _muted(context, invoice.customerAddress),
              if (invoice.customerEmail != null)
                _muted(context, invoice.customerEmail!),
              if (invoice.customerPhone != null)
                _muted(context, invoice.customerPhone!),
            ],
          ),
        ),
      ],
    );
  }

  Widget _items(BuildContext context, Invoice invoice, Color accent) {
    final neutral = context.themeColors.neutral;
    return _sectionCard(
      context,
      title: 'Line items',
      icon: Icons.format_list_bulleted,
      children: invoice.items
          .map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: neutral.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: neutral.divider),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.description,
                          style: TextStyle(
                            color: neutral.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_quantity(item.quantity)} ${item.unit} × '
                          '${invoice.currencySymbol}${item.unitPrice.toStringAsFixed(2)}'
                          '${item.discountPercent > 0 ? ' • ${_quantity(item.discountPercent)}% off' : ''}',
                          style: TextStyle(
                            color: neutral.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if (item.sku != null)
                          Text(
                            'SKU: ${item.sku}',
                            style: TextStyle(
                              color: neutral.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${invoice.currencySymbol}${item.total.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _totals(BuildContext context, Invoice invoice, Color accent) {
    final neutral = context.themeColors.neutral;
    return _sectionCard(
      context,
      title: 'Summary',
      icon: Icons.calculate_outlined,
      children: [
        _amountRow(context, invoice, 'Subtotal', invoice.subtotal),
        if (invoice.discountAmount > 0)
          _amountRow(
            context,
            invoice,
            'Invoice discount',
            -invoice.discountAmount,
          ),
        if (invoice.tax > 0)
          _amountRow(
            context,
            invoice,
            'Tax (${_quantity(invoice.taxRate)}%)',
            invoice.tax,
          ),
        if (invoice.shippingAmount > 0)
          _amountRow(
            context,
            invoice,
            'Shipping / extra',
            invoice.shippingAmount,
          ),
        Divider(color: neutral.divider),
        _amountRow(
          context,
          invoice,
          'Invoice total',
          invoice.total,
          strong: true,
        ),
        if (invoice.paidAmount > 0)
          _amountRow(context, invoice, 'Paid', -invoice.paidAmount),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'BALANCE DUE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${invoice.currencySymbol}${invoice.balanceDue.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _amountRow(
    BuildContext context,
    Invoice invoice,
    String label,
    double value, {
    bool strong = false,
  }) {
    final neutral = context.themeColors.neutral;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: strong ? neutral.textPrimary : neutral.textSecondary,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            '${value < 0 ? '-' : ''}${invoice.currencySymbol}${value.abs().toStringAsFixed(2)}',
            style: TextStyle(
              color: neutral.textPrimary,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _details(BuildContext context, Invoice invoice, Color accent) {
    return _sectionCard(
      context,
      title: 'Payment & notes',
      icon: Icons.description_outlined,
      children: [
        _detailBlock(context, 'Payment information', invoice.paymentInfo),
        if (invoice.purchaseOrderNumber != null)
          _detailBlock(context, 'PO / reference', invoice.purchaseOrderNumber!),
        if (invoice.terms != null)
          _detailBlock(context, 'Terms and conditions', invoice.terms!),
        if (invoice.notes != null)
          _detailBlock(context, 'Customer note', invoice.notes!),
        if (invoice.footerText != null)
          _detailBlock(context, 'Footer message', invoice.footerText!),
        Row(
          children: [
            Icon(Icons.palette_outlined, size: 17, color: accent),
            const SizedBox(width: 7),
            Text(
              '${_titleCase(invoice.templateStyle)} PDF template',
              style: TextStyle(color: accent, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  Widget _detailBlock(BuildContext context, String title, String value) {
    final neutral = context.themeColors.neutral;
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: neutral.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: neutral.textSecondary)),
        ],
      ),
    );
  }

  Widget _actionBar(BuildContext context, Invoice invoice, Color accent) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => PdfInvoiceService.savePdf(
              invoice,
              context: context,
            ),
            icon: const Icon(Icons.download_outlined),
            label: const Text('Save PDF'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () =>
                PdfInvoiceService.generateAndPreview(invoice, context),
            icon: const Icon(Icons.preview_outlined),
            label: const Text('Preview PDF'),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final neutral = context.themeColors.neutral;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
              Icon(icon, color: neutral.textSecondary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: neutral.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _strong(BuildContext context, String value) {
    final neutral = context.themeColors.neutral;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        value.isEmpty ? 'Not provided' : value,
        style: TextStyle(
          color: neutral.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _muted(BuildContext context, String value) {
    final neutral = context.themeColors.neutral;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(
        value,
        style: TextStyle(color: neutral.textSecondary, fontSize: 12),
      ),
    );
  }

  String _statusLabel(String value) {
    if (value == 'partially_paid') return 'Partially paid';
    return _titleCase(value);
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1).replaceAll('_', ' ')}';
  }

  String _quantity(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }
}
