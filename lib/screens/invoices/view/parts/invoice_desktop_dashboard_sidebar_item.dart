part of '../invoice_desktop_dashboard.dart';

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? AppColors.invoice : scheme.onSurfaceVariant;
    final background = selected
        ? AppColors.invoice.withOpacity(.10)
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: SizedBox(
            height: 42,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(icon, size: 19, color: foreground),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: foreground,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                        ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.invoice.withOpacity(.13)
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                const SizedBox(width: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentInvoiceItem extends StatelessWidget {
  const _RecentInvoiceItem({
    required this.invoice,
    required this.selected,
    required this.onTap,
  });

  final Invoice invoice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = Color(invoice.accentColorValue);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? accent.withOpacity(.09) : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(.11),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    invoice.isPaid
                        ? Icons.check_rounded
                        : Icons.receipt_outlined,
                    size: 17,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${invoice.number}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        invoice.customerName.isEmpty
                            ? 'Unnamed customer'
                            : invoice.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${invoice.currencySymbol}${invoice.total.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selected ? accent : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
