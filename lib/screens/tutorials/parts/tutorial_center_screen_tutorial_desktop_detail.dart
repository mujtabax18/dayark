part of '../tutorial_center_screen.dart';

class _TutorialDesktopDetail extends StatelessWidget {
  const _TutorialDesktopDetail({required this.guide});

  final _TutorialGuide guide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 40),
      child: ResponsiveContent(
        maxWidth: 980,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    guide.icon,
                    size: 29,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guide.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        guide.description,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                if (guide.route != null) ...[
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: () => _openTutorialModule(context, guide),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(context.l10n.tr('openModule')),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 30),
            AppSurface(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.format_list_numbered_rounded,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Step-by-step guide',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  for (var index = 0; index < guide.steps.length; index++) ...[
                    _TutorialDesktopStep(
                      number: index + 1,
                      text: guide.steps[index],
                    ),
                    if (index != guide.steps.length - 1)
                      const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppSurface(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.tips_and_updates_outlined, color: scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Learn without leaving the desktop workspace',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Choose another guide from the tutorial sidebar. Opening a feature on desktop keeps it inside the main admin workspace instead of creating a separate full-screen mobile page.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialDesktopStep extends StatelessWidget {
  const _TutorialDesktopStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$number',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45),
            ),
          ),
        ),
      ],
    );
  }
}

class _TutorialEmptyState extends StatelessWidget {
  const _TutorialEmptyState({required this.onClearSearch});

  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 46,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No tutorials found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              'Try another search or clear the current filter.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onClearSearch,
              icon: const Icon(Icons.clear_rounded),
              label: const Text('Clear search'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialCard extends StatelessWidget {
  const _TutorialCard({required this.guide});

  final _TutorialGuide guide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppSurface(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        leading: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: AppRadius.small,
          ),
          child: Icon(guide.icon, color: scheme.onPrimaryContainer),
        ),
        title: Text(guide.title),
        subtitle: Text(
          guide.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        children: [
          for (var index = 0; index < guide.steps.length; index++)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 12,
                    child: Text(
                      '${index + 1}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(guide.steps[index])),
                ],
              ),
            ),
          if (guide.route != null) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                onPressed: () => _openTutorialModule(context, guide),
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(context.l10n.tr('openModule')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

void _openTutorialModule(BuildContext context, _TutorialGuide guide) {
  final route = guide.route;
  if (route == null || route.isEmpty) return;

  // Shell destinations change the current top-level branch. Standalone
  // feature routes use the desktop navigation scope when available so they
  // remain inside the admin panel's right content pane.
  const shellRoutes = <String>{
    RoutesStr.home,
    RoutesStr.finance,
    RoutesStr.planner,
    RoutesStr.more,
  };

  if (shellRoutes.contains(route)) {
    context.go(route);
    return;
  }

  openResponsiveModule(context, route);
}

