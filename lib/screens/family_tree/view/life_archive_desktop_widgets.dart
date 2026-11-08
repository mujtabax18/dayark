import 'package:flutter/material.dart';

/// Shared, responsive layout components for the Life Archives web/desktop UI.
/// Phone screens continue to use their existing navigation and visual language.
class LifeArchiveDesktop {
  const LifeArchiveDesktop._();

  static const double breakpoint = 840;
  static const double sidebarWidth = 224;
  static const double contentMaxWidth = 1540;

  static bool enabled(BoxConstraints constraints) =>
      constraints.maxWidth >= breakpoint;
}

class ArchiveNavigationItem {
  const ArchiveNavigationItem(this.label, this.icon, {this.description});
  final String label;
  final IconData icon;
  final String? description;
}

class ArchiveDesktopSidebar extends StatelessWidget {
  const ArchiveDesktopSidebar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.title = 'LIFE ARCHIVES',
    this.subtitle = 'Your personal workspace',
    this.footer,
  });

  final List<ArchiveNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final String title;
  final String subtitle;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: LifeArchiveDesktop.sidebarWidth,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(top: false, right: false, child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 14, 25),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(Icons.auto_stories_rounded,
                color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 11),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900)),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant)),
              ],
            )),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Align(alignment: Alignment.centerLeft,
            child: Text('WORKSPACE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 1.1, fontWeight: FontWeight.w800))),
        ),
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final selected = index == selectedIndex;
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Material(
                color: selected ? scheme.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  dense: true,
                  selected: selected,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                  leading: Icon(item.icon,
                    color: selected ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant),
                  title: Text(item.label,
                    style: TextStyle(fontWeight:
                      selected ? FontWeight.w800 : FontWeight.w500,
                      color: selected ? scheme.onPrimaryContainer
                        : scheme.onSurface)),
                  onTap: () => onSelected(index),
                ),
              ),
            );
          },
        )),
        if (footer != null) ...[
          Divider(color: scheme.outlineVariant, height: 1),
          Padding(padding: const EdgeInsets.all(12), child: footer!),
        ],
      ])),
    );
  }
}

class ArchiveDesktopHeader extends StatelessWidget {
  const ArchiveDesktopHeader({
    super.key, required this.title, required this.subtitle,
    this.breadcrumb, this.actions = const [],
  });
  final String title;
  final String subtitle;
  final String? breadcrumb;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (breadcrumb != null) ...[
        Text(breadcrumb!, style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 9),
      ],
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900, letterSpacing: -.6)),
            const SizedBox(height: 5),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant)),
          ],
        )),
        if (actions.isNotEmpty) ...[
          const SizedBox(width: 16),
          Flexible(child: Wrap(alignment: WrapAlignment.end,
            spacing: 8, runSpacing: 8, children: actions)),
        ],
      ]),
    ]);
  }
}

class ArchiveDesktopStat extends StatelessWidget {
  const ArchiveDesktopStat({
    super.key, required this.label, required this.value,
    required this.icon, this.onTap,
  });
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16), onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(value, style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(label, style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            )),
          ]),
        ),
      ),
    );
  }
}

/// Padding and max-width applied to the workspace only, not the network canvas.
class ArchiveDesktopWorkspace extends StatelessWidget {
  const ArchiveDesktopWorkspace({super.key, required this.child,
      this.padding = const EdgeInsets.fromLTRB(28, 26, 28, 24)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: LifeArchiveDesktop.contentMaxWidth),
      child: Padding(padding: padding, child: child),
    ),
  );
}
