import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/pill_ui_helpers.dart';
import '../../shared/pill_desktop_navigation.dart';
import '../controller/pill_list_controller.dart';
import '../provider/pill_list_provider.dart';
import '../../../navigation/widgets/desktop_content_frame.dart';

class PillInventoryRefillScreen extends ConsumerStatefulWidget {
  const PillInventoryRefillScreen({
    super.key,
    required this.pillId,
    required this.pillName,
  });

  final int pillId;
  final String pillName;

  @override
  ConsumerState<PillInventoryRefillScreen> createState() =>
      _PillInventoryRefillScreenState();
}

class _PillInventoryRefillScreenState
    extends ConsumerState<PillInventoryRefillScreen> {
  final qtyCtrl = TextEditingController();
  String? error;
  bool isSubmitting = false;

  @override
  void dispose() {
    qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final controller = ref.read(pillListControllerProvider.notifier);
    final desktopNav = PillDesktopNavigationScope.maybeOf(context);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        leading: desktopNav == null
            ? null
            : IconButton(
                tooltip: 'Back to medicines',
                onPressed: desktopNav.onCloseDetail,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
        title: const Text('Refill inventory'),
      ),
      body: DesktopContentFrame(
        child: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            _PillHeader(name: widget.pillName),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: PillUi.cardDecoration(context, radius: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How much are you adding?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This quantity will be added to the current stock.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: qtyCtrl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+(\.\d{0,2})?$'),
                      ),
                    ],
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    onChanged: (_) {
                      if (error != null) setState(() => error = null);
                    },
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      hintText: '0',
                      errorText: error,
                      prefixIcon: const Icon(Icons.add_box_outlined),
                      suffixText: 'units',
                    ),
                  ),
                  const SizedBox(height: 14),
                  _RefillTip(
                    icon: Icons.info_outline_rounded,
                    text:
                        'Use the same unit you selected when creating the medicine.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
      bottomNavigationBar: Material(
        color: scheme.surface,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: isSubmitting
                  ? null
                  : () => _submit(controller),
              icon: isSubmitting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.inventory_rounded),
              label: const Text('Update inventory'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(PillListController controller) async {
    final qty = double.tryParse(qtyCtrl.text.trim());

    if (qty == null || qty <= 0) {
      setState(() => error = 'Enter a number above zero');
      HapticFeedback.mediumImpact();
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      error = null;
      isSubmitting = true;
    });
    HapticFeedback.lightImpact();

    try {
      await controller.refillInventory(widget.pillId, qty);
      if (mounted) {
        final desktopNav = PillDesktopNavigationScope.maybeOf(context);
        if (desktopNav != null) {
          desktopNav.onCloseDetail();
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          isSubmitting = false;
          error = 'Could not update inventory';
        });
      }
    }
  }
}

class _PillHeader extends StatelessWidget {
  const _PillHeader({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: PillUi.cardDecoration(
        context,
        color: PillUi.tintedSurface(context, scheme.primary, opacity: .07),
        borderColor: scheme.primary.withOpacity(.17),
        radius: 24,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: PillUi.tintedSurface(
                context,
                scheme.primary,
                opacity: .13,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.medication_outlined,
              color: scheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REFILLING',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
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

class _RefillTip extends StatelessWidget {
  const _RefillTip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: scheme.onSurfaceVariant),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
