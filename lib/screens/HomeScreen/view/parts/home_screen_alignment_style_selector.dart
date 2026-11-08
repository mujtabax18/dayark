part of '../HomeScreenAlignment.dart';

class _StyleSelector extends StatelessWidget {
  const _StyleSelector({
    required this.selected,
    required this.onChanged,
  });

  final HomePageStyle selected;
  final ValueChanged<HomePageStyle> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: HomePageStyle.values.map((style) {
        final isSelected = selected == style;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Material(
            color: isSelected
                ? scheme.primaryContainer.withOpacity(.36)
                : scheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.medium,
              side: BorderSide(
                color: isSelected ? scheme.primary : scheme.outlineVariant,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onChanged(style),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? scheme.primary.withOpacity(.13)
                            : scheme.surfaceContainerHighest,
                        borderRadius: AppRadius.small,
                      ),
                      child: Icon(
                        _styleIcon(style),
                        color: isSelected
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            style.label,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            style.description,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: isSelected ? scheme.primary : scheme.outline,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }

  IconData _styleIcon(HomePageStyle style) {
    return switch (style) {
      HomePageStyle.detailed => Icons.dashboard_rounded,
      HomePageStyle.quickLinks => Icons.apps_rounded,
      HomePageStyle.compact => Icons.view_quilt_rounded,
      HomePageStyle.glance => Icons.auto_awesome_mosaic_rounded,
    };
  }
}

class _SummaryStyleSelector extends StatelessWidget {
  const _SummaryStyleSelector({
    required this.selected,
    required this.onChanged,
  });

  final HomeSummaryStyle selected;
  final ValueChanged<HomeSummaryStyle> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: HomeSummaryStyle.values
          .map(
            (style) => _ChoiceCard(
              selected: selected == style,
              icon: switch (style) {
                HomeSummaryStyle.cards => Icons.dashboard_rounded,
                HomeSummaryStyle.compact => Icons.view_carousel_outlined,
                HomeSummaryStyle.glance => Icons.view_week_outlined,
              },
              title: style.label,
              subtitle: style.description,
              onTap: () => onChanged(style),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _CreateStyleSelector extends StatelessWidget {
  const _CreateStyleSelector({
    required this.selected,
    required this.onChanged,
  });

  final HomeCreateStyle selected;
  final ValueChanged<HomeCreateStyle> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: HomeCreateStyle.values
          .map(
            (style) => _ChoiceCard(
              selected: selected == style,
              icon: switch (style) {
                HomeCreateStyle.floating => Icons.add_circle_outline_rounded,
                HomeCreateStyle.dock => Icons.view_agenda_outlined,
              },
              title: style.label,
              subtitle: style.description,
              onTap: () => onChanged(style),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: selected
            ? scheme.primaryContainer.withOpacity(.32)
            : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.medium,
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.primary.withOpacity(.13)
                        : scheme.surfaceContainerHighest,
                    borderRadius: AppRadius.small,
                  ),
                  child: Icon(
                    icon,
                    color: selected
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? scheme.primary : scheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsSwitchCard extends StatelessWidget {
  const _SettingsSwitchCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.medium,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        secondary: Icon(icon, color: scheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
      ),
    );
  }
}

class _SummarySettingsList extends StatelessWidget {
  const _SummarySettingsList({
    required this.order,
    required this.visibleIds,
    required this.onVisibilityChanged,
    required this.onReorder,
  });

  final List<int> order;
  final Set<int> visibleIds;
  final void Function(int id, bool visible) onVisibilityChanged;
  final ValueChanged<List<int>> onReorder;

  @override
  Widget build(BuildContext context) {
    final normalized = HomeLayoutSettings.normalizeSummaryOrder(order);
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: normalized.length,
      onReorder: (oldIndex, newIndex) {
        final updated = [...normalized];
        final item = updated.removeAt(oldIndex);
        updated.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
        onReorder(updated);
      },
      itemBuilder: (context, index) {
        final id = normalized[index];
        final feature = HomeFeatureModel.defaultFeaturesById[id]!;
        return _ToggleReorderCard(
          key: ValueKey('summary-$id'),
          index: index,
          title: _featureTitle(feature),
          subtitle: 'Home position ${index + 1}',
          icon: _featureIcon(feature),
          color: Color(feature.colorCode),
          enabled: visibleIds.contains(id),
          position: index,
          positionCount: normalized.length,
          onPositionSelected: (position) {
            if (position == index) return;
            final updated = [...normalized]..removeAt(index);
            updated.insert(position, id);
            onReorder(updated);
          },
          onChanged: (value) => onVisibilityChanged(id, value),
        );
      },
    );
  }
}

class _QuickActionSettingsList extends StatelessWidget {
  const _QuickActionSettingsList({
    required this.order,
    required this.visibleIds,
    required this.onVisibilityChanged,
    required this.onReorder,
  });

  final List<String> order;
  final Set<String> visibleIds;
  final void Function(String id, bool visible) onVisibilityChanged;
  final ValueChanged<List<String>> onReorder;

  @override
  Widget build(BuildContext context) {
    final normalized = HomeLayoutSettings.normalizeQuickActionOrder(order);
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: normalized.length,
      onReorder: (oldIndex, newIndex) {
        final updated = [...normalized];
        final item = updated.removeAt(oldIndex);
        updated.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
        onReorder(updated);
      },
      itemBuilder: (context, index) {
        final id = normalized[index];
        final data = _quickActionData(id);
        return _ToggleReorderCard(
          key: ValueKey('action-$id'),
          index: index,
          title: data.title,
          icon: data.icon,
          color: data.color,
          enabled: visibleIds.contains(id),
          onChanged: (value) => onVisibilityChanged(id, value),
        );
      },
    );
  }
}

class _QuickAccessSettingsList extends StatelessWidget {
  const _QuickAccessSettingsList({
    required this.features,
    required this.visibleIds,
    required this.onVisibilityChanged,
    required this.onReorder,
  });

  final List<HomeFeatureModel> features;
  final Set<int> visibleIds;
  final void Function(int id, bool visible) onVisibilityChanged;
  final ValueChanged<List<HomeFeatureModel>> onReorder;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: features.length,
      onReorder: (oldIndex, newIndex) {
        final updated = [...features];
        final item = updated.removeAt(oldIndex);
        updated.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
        onReorder(updated);
      },
      itemBuilder: (context, index) {
        final feature = features[index];
        return _ToggleReorderCard(
          key: ValueKey('access-${feature.id}'),
          index: index,
          title: _featureTitle(feature),
          icon: _featureIcon(feature),
          color: Color(feature.colorCode),
          enabled: visibleIds.contains(feature.id),
          onChanged: (value) => onVisibilityChanged(feature.id, value),
        );
      },
    );
  }
}

