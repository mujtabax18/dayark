part of '../scanner_desktop_dashboard.dart';

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String? badge;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: enabled
                      ? (selected
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant)
                      : scheme.onSurfaceVariant.withValues(alpha: .45),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: enabled
                          ? (selected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurface)
                          : scheme.onSurfaceVariant.withValues(alpha: .45),
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.onPrimaryContainer.withValues(alpha: .10)
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
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

class _RecentDocumentItem extends StatelessWidget {
  const _RecentDocumentItem({
    required this.group,
    required this.selected,
    required this.onTap,
  });

  final ScanGroupPreview group;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(
                group.isFavorite
                    ? Icons.description_rounded
                    : Icons.description_outlined,
                size: 18,
                color: selected
                    ? scheme.onSecondaryContainer
                    : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.title.trim().isEmpty
                          ? 'Untitled document'
                          : group.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      '${group.pageCount} page${group.pageCount == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (group.isFavorite)
                const Icon(Icons.star_rounded, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
