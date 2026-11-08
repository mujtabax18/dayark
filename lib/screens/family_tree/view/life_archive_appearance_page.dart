import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_theme_preset.dart';

/// A scope-local appearance editor. Archive settings are independent from
/// DayArk's global appearance and are supplied/persisted by the archive route.
class LifeArchiveAppearancePage extends StatefulWidget {
  const LifeArchiveAppearancePage({
    super.key,
    required this.initialMode,
    required this.initialPreset,
    required this.appBrightness,
    required this.systemBrightness,
    required this.appPreset,
    required this.onChanged,
  });

  final ThemeMode? initialMode;
  final AppThemePreset? initialPreset;
  final Brightness appBrightness;
  final Brightness systemBrightness;
  final AppThemePreset appPreset;
  final void Function(ThemeMode?, AppThemePreset?) onChanged;

  @override
  State<LifeArchiveAppearancePage> createState() => _LifeArchiveAppearancePageState();
}

class _LifeArchiveAppearancePageState extends State<LifeArchiveAppearancePage> {
  ThemeMode? _mode;
  AppThemePreset? _preset;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _preset = widget.initialPreset;
  }

  void _update({ThemeMode? mode, AppThemePreset? preset,
      bool setMode = false, bool setPreset = false}) {
    setState(() {
      if (setMode) _mode = mode;
      if (setPreset) _preset = preset;
    });
    widget.onChanged(_mode, _preset);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = switch (_mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => widget.systemBrightness,
      null => widget.appBrightness,
    };
    final palette = _preset ?? widget.appPreset;
    final theme = brightness == Brightness.dark
        ? AppTheme.dark(palette) : AppTheme.light(palette);
    return Theme(
      data: theme,
      child: Builder(builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(title: const Text('Life Archive appearance')),
          body: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
            children: [
              Text('Make your archive yours',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              const Text('Choose a display mode and accent color. These settings apply only to this Life Archive and are saved on this device.'),
              const SizedBox(height: 28),
              Text('Display mode', style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ...<({String label, String subtitle, IconData icon, ThemeMode? mode})>[
                (label: 'Follow app', subtitle: 'Use DayArk’s current appearance',
                  icon: Icons.sync_rounded, mode: null),
                (label: 'System', subtitle: 'Match your device’s light or dark setting',
                  icon: Icons.brightness_auto_outlined, mode: ThemeMode.system),
                (label: 'Light', subtitle: 'Bright backgrounds',
                  icon: Icons.light_mode_outlined, mode: ThemeMode.light),
                (label: 'Dark', subtitle: 'Comfortable in low light',
                  icon: Icons.dark_mode_outlined, mode: ThemeMode.dark),
              ].map((choice) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => _update(mode: choice.mode, setMode: true),
                  selected: _mode == choice.mode,
                  leading: Icon(choice.icon, size: 24),
                  title: Text(choice.label),
                  subtitle: Text(choice.subtitle),
                  trailing: _mode == choice.mode
                      ? Icon(Icons.check_circle_rounded, color: scheme.primary)
                      : const Icon(Icons.circle_outlined, size: 20),
                ),
              )),
              const SizedBox(height: 25),
              Text('Color themes', style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              const Text('Pick an accent for the archive, or follow DayArk.'),
              const SizedBox(height: 14),
              Wrap(spacing: 10, runSpacing: 10, children: [
                _PaletteChoice(label: 'App default',
                  color: widget.appPreset.primary,
                  selected: _preset == null,
                  onTap: () => _update(setPreset: true)),
                ...AppThemePreset.values.map((preset) => _PaletteChoice(
                  label: preset.label, color: preset.primary,
                  selected: _preset == preset,
                  onTap: () => _update(preset: preset, setPreset: true))),
              ]),
              const SizedBox(height: 25),
              Card(
                color: scheme.primaryContainer,
                child: Padding(padding: const EdgeInsets.all(20),
                  child: Row(children: [
                    Icon(Icons.auto_stories_rounded, color: scheme.onPrimaryContainer,
                      size: 35),
                    const SizedBox(width: 14),
                    Expanded(child: Text('Your stories, your colors',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700))),
                  ])),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _PaletteChoice extends StatelessWidget {
  const _PaletteChoice({required this.label, required this.color,
    required this.selected, required this.onTap});
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(15), onTap: onTap,
      child: Container(width: 105,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
          border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1),
        ),
        child: Column(children: [
          CircleAvatar(radius: 20, backgroundColor: color,
            child: selected ? const Icon(Icons.check_rounded, color: Colors.white) : null),
          const SizedBox(height: 9),
          Text(label, textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500)),
        ]),
      ),
    );
  }
}
