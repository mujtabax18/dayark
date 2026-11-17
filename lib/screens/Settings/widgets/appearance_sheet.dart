import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controller/dark_style_notifier.dart';
import '../../../controller/theme_notifier.dart';
import '../../../controller/theme_preset_notifier.dart';
import '../../../core/theme/app_dark_style.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_theme_preset.dart';
import '../../../localization/app_localizations.dart';

Future<void> showAppearanceSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (context) => const FractionallySizedBox(
        heightFactor: .9,
        child: AppearanceSheet(),
      ),
    );

/// All controls update the app immediately, using its existing preferences.
class AppearanceSheet extends ConsumerWidget {
  const AppearanceSheet({super.key});

  Future<void> _save(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.tr('appearanceSaveError'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeProvider);
    final preset = ref.watch(themePresetProvider);
    final darkStyle = ref.watch(darkStyleProvider);
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final brightness = switch (mode) {
      ThemeMode.system => MediaQuery.platformBrightnessOf(context),
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
    };

    Widget heading(String key) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(l10n.tr(key), style: theme.textTheme.titleMedium),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.tr('appearance'),
                style: theme.textTheme.headlineSmall,
              ),
            ),
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        Text(
          l10n.tr('appearanceDescription'),
          style: theme.textTheme.bodyMedium,
        ),
        heading('themeMode'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final option in ThemeMode.values)
              ChoiceChip(
                avatar: Icon(switch (option) {
                  ThemeMode.system => Icons.brightness_auto_outlined,
                  ThemeMode.light => Icons.light_mode_outlined,
                  ThemeMode.dark => Icons.dark_mode_outlined,
                }, size: 18),
                label: Text(l10n.tr(option.name)),
                selected: mode == option,
                onSelected: (_) => _save(
                  context,
                  () => ref.read(themeProvider.notifier).setTheme(option),
                ),
              ),
          ],
        ),
        heading('darkSurfaces'),
        Text(
          l10n.tr('darkSurfacesDescription'),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final style in AppDarkStyle.values)
              _ThemeChoice(
                label: l10n.tr(
                  style == AppDarkStyle.black ? 'pureBlack' : 'dimDark',
                ),
                theme: AppTheme.dark(preset, style),
                selected: darkStyle == style,
                onTap: () => _save(
                  context,
                  () => ref.read(darkStyleProvider.notifier).setStyle(style),
                ),
              ),
          ],
        ),
        heading('themeStyle'),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 560
                ? 4
                : constraints.maxWidth >= 360
                ? 3
                : 2;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final option in AppThemePreset.values)
                  SizedBox(
                    width: width,
                    child: _ThemeChoice(
                      label: l10n.tr('palette_${option.name}'),
                      theme: brightness == Brightness.dark
                          ? AppTheme.dark(option, darkStyle)
                          : AppTheme.light(option),
                      selected: preset == option,
                      onTap: () => _save(
                        context,
                        () => ref
                            .read(themePresetProvider.notifier)
                            .setPreset(option),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.label,
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final ThemeData theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = theme.colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: SizedBox(
        width: 144,
        child: Material(
          color: selected
              ? scheme.secondaryContainer
              : scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ExcludeSemantics(
                    child: Container(
                      height: 72,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: preview.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 6,
                            decoration: BoxDecoration(
                              color: preview.primary,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: preview.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              padding: const EdgeInsets.all(6),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: preview.primary,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Container(
                                      height: 3,
                                      color: preview.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ExcludeSemantics(
                          child: Text(
                            label,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: selected
                                      ? scheme.onSecondaryContainer
                                      : scheme.onSurface,
                                ),
                          ),
                        ),
                      ),
                      if (selected) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: scheme.primary,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
