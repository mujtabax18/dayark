import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_x.dart';
import '../../../controller/monthclosingController.dart';
import '../../../models/MonthClosing.dart';
import '../../../services/localDatabaseServices/monthClosing.dart';
import '../controller/ExpensesController.dart';

Future<void> showExpenseMonthClosingSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final isDesktop = MediaQuery.sizeOf(context).width >= 1100;
  if (isDesktop) {
    await showDialog<void>(
      context: context,
      builder: (_) => const Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(32),
        child: SizedBox(
          width: 760,
          height: 760,
          child: _MonthClosingSheet(desktopMode: true),
        ),
      ),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _MonthClosingSheet(),
  );
}

class _MonthClosingSheet extends ConsumerStatefulWidget {
  final bool desktopMode;

  const _MonthClosingSheet({this.desktopMode = false});

  @override
  ConsumerState<_MonthClosingSheet> createState() => _MonthClosingSheetState();
}

class _MonthClosingSheetState extends ConsumerState<_MonthClosingSheet> {
  late DateTime _month;
  late TextEditingController _titleController;
  final _descriptionController = TextEditingController();
  Future<ClosingPreview>? _preview;
  bool _closing = false;

  DateTime get _start => DateTime(_month.year, _month.month, 1);
  DateTime get _end => DateTime(_month.year, _month.month + 1, 0);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    _titleController = TextEditingController(text: DateFormat('MMMM yyyy').format(_month));
    _preview = _loadPreview();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<ClosingPreview> _loadPreview() {
    return ref.read(monthClosingControllerProvider.notifier).preview(
          startDate: _start,
          endDate: _end,
        );
  }

  void _changeMonth(int offset) {
    setState(() {
      _month = DateTime(_month.year, _month.month + offset, 1);
      _titleController.text = DateFormat('MMMM yyyy').format(_month);
      _preview = _loadPreview();
    });
  }

  Future<void> _closeMonth() async {
    if (_closing) return;
    setState(() => _closing = true);
    try {
      final closing = await ref
          .read(monthClosingControllerProvider.notifier)
          .closeMonth(
            title: _titleController.text,
            description: _descriptionController.text,
            startDate: _start,
            endDate: _end,
          );
      invalidateExpenseData(ref);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${closing.title} closed with ${closing.itemCount} transactions.',
          ),
        ),
      );
      setState(() => _preview = _loadPreview());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final closings = ref.watch(monthClosingControllerProvider);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: neutral.background,
        borderRadius: widget.desktopMode
            ? BorderRadius.circular(20)
            : const BorderRadius.vertical(top: Radius.circular(24)),
        border: widget.desktopMode
            ? Border.all(color: neutral.divider.withOpacity(0.75))
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (!widget.desktopMode) ...[
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: neutral.divider,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.expense.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: AppColors.expense,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Month closing',
                        style: TextStyle(
                          color: neutral.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Lock transactions into a historical period.',
                        style: TextStyle(
                          color: neutral.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: neutral.textSecondary),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: neutral.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: neutral.divider),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => _changeMonth(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              DateFormat('MMMM yyyy').format(_month),
                              style: TextStyle(
                                color: neutral.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${DateFormat('dd MMM').format(_start)} – '
                              '${DateFormat('dd MMM').format(_end)}',
                              style: TextStyle(
                                color: neutral.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _changeMonth(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                FutureBuilder<ClosingPreview>(
                  future: _preview,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox(
                        height: 90,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final preview = snapshot.data!;
                    return _ClosingPreviewCard(preview: preview);
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _titleController,
                  decoration: _inputDecoration(context, 'Closing title'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: _inputDecoration(
                    context,
                    'Notes (optional)',
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _closing ? null : _closeMonth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.expense,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: _closing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.lock_outline_rounded),
                    label: const Text('Close selected month'),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Previous closings',
                  style: TextStyle(
                    color: neutral.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                closings.when(
                  data: (data) => data.isEmpty
                      ? Text(
                          'No months have been closed yet.',
                          style: TextStyle(color: neutral.textSecondary),
                        )
                      : Column(
                          children: data
                              .map(
                                (closing) => _ClosingTile(
                                  closing: closing,
                                  onOpen: () => _openClosing(closing),
                                  onReopen: () => _confirmReopen(closing),
                                ),
                              )
                              .toList(),
                        ),
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text(
                    error.toString(),
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openClosing(MonthClosing closing) {
    ref
        .read(expenseItemFilterClosingIdProvider.notifier)
        .setExpenseItemFilterClosingId(closing.id.toString());
    ref
        .read(expenseItemFilterStartDateProvider.notifier)
        .setExpenseItemFilterStartDate(null);
    ref
        .read(expenseItemFilterEndDateProvider.notifier)
        .setExpenseItemFilterEndDate(null);
    invalidateExpenseData(ref);
    Navigator.of(context).pop();
  }

  Future<void> _confirmReopen(MonthClosing closing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reopen month?'),
        content: Text(
          'You can already edit ${closing.title} by opening it directly. '
          'Reopening will remove this closing and move all ${closing.itemCount} transactions back to the active month.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Move to active month'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(monthClosingControllerProvider.notifier)
        .reopenClosing(closing.id);
    invalidateExpenseData(ref);
    setState(() => _preview = _loadPreview());
  }

  InputDecoration _inputDecoration(BuildContext context, String label) {
    final neutral = context.themeColors.neutral;
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: neutral.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: neutral.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: neutral.divider),
      ),
    );
  }
}

class _ClosingPreviewCard extends StatelessWidget {
  final ClosingPreview preview;

  const _ClosingPreviewCard({required this.preview});

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: neutral.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: _value(context, 'Items', preview.itemCount.toString(), AppColors.warning),
          ),
          Expanded(
            child: _value(context, 'In', preview.totalIn.toStringAsFixed(2), AppColors.success),
          ),
          Expanded(
            child: _value(context, 'Out', preview.totalOut.toStringAsFixed(2), AppColors.danger),
          ),
          Expanded(
            child: _value(context, 'Net', preview.net.toStringAsFixed(2), AppColors.expense),
          ),
        ],
      ),
    );
  }

  Widget _value(BuildContext context, String label, String value, Color color) {
    final neutral = context.themeColors.neutral;
    return Column(
      children: [
        Text(label, style: TextStyle(color: neutral.textSecondary, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _ClosingTile extends StatelessWidget {
  final MonthClosing closing;
  final VoidCallback onOpen;
  final VoidCallback onReopen;

  const _ClosingTile({
    required this.closing,
    required this.onOpen,
    required this.onReopen,
  });

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: neutral.divider),
      ),
      child: ListTile(
        onTap: onOpen,
        leading: const Icon(Icons.history_rounded, color: AppColors.expense),
        title: Text(
          closing.title,
          style: TextStyle(
            color: neutral.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${closing.startDate} – ${closing.endDate} • ${closing.itemCount} items',
          style: TextStyle(color: neutral.textSecondary, fontSize: 12),
        ),
        trailing: IconButton(
          tooltip: 'Move closing to active month',
          onPressed: onReopen,
          icon: const Icon(Icons.lock_open_outlined),
        ),
      ),
    );
  }
}
