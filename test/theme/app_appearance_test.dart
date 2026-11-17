import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metersystem/controller/UserSettingsController.dart';
import 'package:metersystem/controller/dark_style_notifier.dart';
import 'package:metersystem/controller/theme_notifier.dart';
import 'package:metersystem/controller/theme_preset_notifier.dart';
import 'package:metersystem/core/theme/app_dark_style.dart';
import 'package:metersystem/core/theme/app_theme.dart';
import 'package:metersystem/core/theme/app_theme_extension.dart';
import 'package:metersystem/core/theme/app_theme_preset.dart';
import 'package:metersystem/localization/app_localizations.dart';
import 'package:metersystem/screens/Settings/widgets/appearance_sheet.dart';
import 'package:metersystem/services/database_service.dart';
import 'package:metersystem/services/localDatabaseServices/UserSettingsRepository.dart';
import 'package:metersystem/utlis/enums.dart';

class _SettingsRepository extends UserSettingsRepository {
  _SettingsRepository() : super(DatabaseService());
  final values = <AppSettingKey, String>{};
  bool failWrites = false;

  @override
  Future<String?> getValue(AppSettingKey key, {int userId = 0}) async =>
      values[key];

  @override
  Future<void> setValue(
    AppSettingKey key,
    String value, {
    int userId = 0,
  }) async {
    if (failWrites) throw StateError('Unavailable storage');
    values[key] = value;
  }
}

double _contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
}

void main() {
  test(
    'every palette has readable text and controls in every surface mode',
    () {
      for (final preset in AppThemePreset.values) {
        for (final theme in [
          AppTheme.light(preset),
          AppTheme.dark(preset),
          AppTheme.dark(preset, AppDarkStyle.black),
        ]) {
          final scheme = theme.colorScheme;
          final neutral = theme.extension<AppThemeColors>()!.neutral;
          for (final pair in [
            (scheme.primary, scheme.onPrimary),
            (scheme.secondary, scheme.onSecondary),
            (scheme.error, scheme.onError),
            (scheme.surface, scheme.onSurface),
            (neutral.background, neutral.textSecondary),
            (neutral.card, neutral.textPrimary),
            (scheme.primaryContainer, scheme.onPrimaryContainer),
          ]) {
            expect(
              _contrast(pair.$1, pair.$2),
              greaterThanOrEqualTo(4.5),
              reason: '${preset.name} ${theme.brightness}',
            );
          }
          if (theme.brightness == Brightness.dark) {
            expect(
              _contrast(scheme.primary, neutral.background),
              greaterThanOrEqualTo(4.5),
            );
          }
        }
        expect(
          AppTheme.dark(preset, AppDarkStyle.black).scaffoldBackgroundColor,
          Colors.black,
        );
      }
    },
  );

  test(
    'old preferences keep defaults and black persists independently',
    () async {
      final repo = _SettingsRepository();
      final settings = UserSettingsController(repo);
      expect(await settings.getDarkStyle(), AppDarkStyle.dim);
      expect(await settings.getThemeMode(), ThemeMode.light);
      repo.values[AppSettingKey.themePreset] = 'unknown';
      expect(await settings.getThemePreset(), AppThemePreset.indigo);
      await settings.setThemeMode(ThemeMode.system);
      await settings.setThemePreset(AppThemePreset.amber);
      await settings.setDarkStyle(AppDarkStyle.black);
      final restored = UserSettingsController(repo);
      expect(await restored.getDarkStyle(), AppDarkStyle.black);
      expect(await restored.getThemeMode(), ThemeMode.system);
      expect(await restored.getThemePreset(), AppThemePreset.amber);
    },
  );

  test('failed saves leave the last saved appearance active', () async {
    final repo = _SettingsRepository()..failWrites = true;
    final settings = UserSettingsController(repo);
    final mode = ThemeNotifier(settings, ThemeMode.light);
    final preset = ThemePresetNotifier(settings, AppThemePreset.indigo);
    final style = DarkStyleNotifier(settings, AppDarkStyle.dim);
    addTearDown(mode.dispose);
    addTearDown(preset.dispose);
    addTearDown(style.dispose);
    await expectLater(mode.setTheme(ThemeMode.dark), throwsStateError);
    await expectLater(preset.setPreset(AppThemePreset.amber), throwsStateError);
    await expectLater(style.setStyle(AppDarkStyle.black), throwsStateError);
    expect(mode.state, ThemeMode.light);
    expect(preset.state, AppThemePreset.indigo);
    expect(style.state, AppDarkStyle.dim);
  });

  for (final scenario in [
    (size: const Size(320, 568), scale: 1.0, locale: const Locale('en')),
    (size: const Size(568, 320), scale: 1.0, locale: const Locale('en')),
    (size: const Size(320, 568), scale: 2.0, locale: const Locale('ar')),
    (size: const Size(1280, 800), scale: 1.0, locale: const Locale('ur')),
  ]) {
    testWidgets(
      'appearance works at ${scenario.size}, ${scenario.scale}, ${scenario.locale}',
      (tester) async {
        tester.view.physicalSize = scenario.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final settings = UserSettingsController(_SettingsRepository());
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              themeProvider.overrideWith(
                (ref) => ThemeNotifier(settings, ThemeMode.dark),
              ),
              themePresetProvider.overrideWith(
                (ref) => ThemePresetNotifier(settings, AppThemePreset.indigo),
              ),
              darkStyleProvider.overrideWith(
                (ref) => DarkStyleNotifier(settings, AppDarkStyle.dim),
              ),
            ],
            child: Consumer(
              builder: (context, ref, _) => MaterialApp(
                theme: AppTheme.light(ref.watch(themePresetProvider)),
                darkTheme: AppTheme.dark(
                  ref.watch(themePresetProvider),
                  ref.watch(darkStyleProvider),
                ),
                themeMode: ref.watch(themeProvider),
                locale: scenario.locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scenario.scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Builder(
                    builder: (context) => Center(
                      child: TextButton(
                        onPressed: () => showAppearanceSheet(context),
                        child: const Text('Open appearance'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open appearance'));
        await tester.pumpAndSettle();
        final l10n = AppLocalizations(scenario.locale);
        await tester.scrollUntilVisible(
          find.text(l10n.tr('pureBlack')),
          120,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.tr('pureBlack')));
        await tester.pumpAndSettle();
        final sheetContext = tester.element(find.byType(AppearanceSheet));
        expect(Theme.of(sheetContext).scaffoldBackgroundColor, Colors.black);
        await tester.scrollUntilVisible(
          find.text(l10n.tr('palette_graphite')),
          120,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.tr('palette_graphite')));
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(sheetContext);
        expect(container.read(themePresetProvider), AppThemePreset.graphite);
        expect(container.read(themeProvider), ThemeMode.dark);
        expect(container.read(darkStyleProvider), AppDarkStyle.black);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
