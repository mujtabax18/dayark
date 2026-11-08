import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:metersystem/services/localDatabaseServices/UserSettingsRepository.dart';
import 'package:metersystem/services/pdf_editor_bootstrap.dart';

import 'controller/UserSettingsController.dart';
import 'controller/currency_notifier.dart';
import 'controller/locale_notifier.dart';
import 'controller/theme_notifier.dart';
import 'controller/theme_preset_notifier.dart';
import 'core/design/app_scroll_behavior.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_theme_preset.dart';
import 'localization/app_localizations.dart';
import 'models/currency_setting.dart';
import 'services/database_service.dart';
import 'services/device_sync/device_sync_service.dart';
import 'services/app_update/app_update_coordinator.dart';
import 'services/app_update/app_update_preferences.dart';
import 'services/app_data_reset_signal.dart';
import 'utlis/app_router.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // IMPORTANT: do this before the first SharedPreferences.getInstance().
  // Release retains the plugin's existing default 'flutter.' prefix.
  // Debug uses a separate namespace (including LAN pairing credentials).
  if (kDebugMode) {
    SharedPreferences.setPrefix('flutter.dayark_debug.');
  }

  initializePdfEditorAssets();

  final databaseService = DatabaseService();
  await databaseService.database;
  await AppUpdatePreferences.instance.load();

  final repository = UserSettingsRepository(databaseService);
  final settingsController = UserSettingsController(repository);
  final initialTheme = await settingsController.getThemeMode();
  final initialThemePreset = await settingsController.getThemePreset();
  final initialLanguage = await settingsController.getLanguage();
  final initialCurrency = await settingsController.getCurrencySetting();

  runApp(
    MeterReadingRoot(
      databaseService: databaseService,
      settingsController: settingsController,
      initialTheme: initialTheme,
      initialThemePreset: initialThemePreset,
      initialLanguage: initialLanguage,
      initialCurrency: initialCurrency,
    ),
  );

  // Debug must not offer to install a GitHub Release over the development app.
  if (!kDebugMode) WidgetsBinding.instance.addPostFrameCallback((_) async {
    // Give GoRouter's root navigator one frame to attach before showing UI.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final context = rootNavigatorKey.currentContext;
    if (context != null && context.mounted) {
      await AppUpdateCoordinator.checkAndPrompt(context);
    }
  });
}

class MeterReadingRoot extends StatefulWidget {
  const MeterReadingRoot({
    super.key,
    required this.databaseService,
    required this.settingsController,
    required this.initialTheme,
    required this.initialThemePreset,
    required this.initialLanguage,
    required this.initialCurrency,
  });

  final DatabaseService databaseService;
  final UserSettingsController settingsController;
  final ThemeMode initialTheme;
  final AppThemePreset initialThemePreset;
  final String initialLanguage;
  final CurrencySetting initialCurrency;

  @override
  State<MeterReadingRoot> createState() => _MeterReadingRootState();
}

class _MeterReadingRootState extends State<MeterReadingRoot> {
  late ThemeMode _theme;
  late AppThemePreset _themePreset;
  late String _language;
  late CurrencySetting _currency;
  int _scopeRevision = 0;
  bool _resetting = false;

  @override
  void initState() {
    super.initState();
    _theme = widget.initialTheme;
    _themePreset = widget.initialThemePreset;
    _language = widget.initialLanguage;
    _currency = widget.initialCurrency;
    AppDataResetSignal.instance.revision.addListener(_reloadAfterDatabaseChange);
  }

  @override
  void dispose() {
    AppDataResetSignal.instance.revision
        .removeListener(_reloadAfterDatabaseChange);
    super.dispose();
  }

  Future<void> _reloadAfterDatabaseChange() async {
    if (_resetting) return;
    setState(() => _resetting = true);

    try {
      final values = await Future.wait<dynamic>([
        widget.settingsController.getThemeMode(),
        widget.settingsController.getThemePreset(),
        widget.settingsController.getLanguage(),
        widget.settingsController.getCurrencySetting(),
      ]);
      if (!mounted) return;
      setState(() {
        _theme = values[0] as ThemeMode;
        _themePreset = values[1] as AppThemePreset;
        _language = values[2] as String;
        _currency = values[3] as CurrencySetting;
        _scopeRevision++;
        _resetting = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Even when a preference read fails, recreate the provider container so
      // deleted/restored feature data can never remain cached in memory.
      setState(() {
        _scopeRevision++;
        _resetting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = ProviderScope(
      key: ValueKey('database-provider-scope-$_scopeRevision'),
      overrides: [
        databaseServiceProvider.overrideWithValue(widget.databaseService),
        themeProvider.overrideWith((ref) {
          return ThemeNotifier(widget.settingsController, _theme);
        }),
        themePresetProvider.overrideWith((ref) {
          return ThemePresetNotifier(widget.settingsController, _themePreset);
        }),
        localeProvider.overrideWith((ref) {
          return LocaleNotifier(
            widget.settingsController,
            Locale(_language),
          );
        }),
        currencyProvider.overrideWith((ref) {
          return CurrencyNotifier(widget.settingsController, _currency);
        }),
      ],
      child: const MeterReadingApp(),
    );

    if (!_resetting) return app;

    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        IgnorePointer(child: app),
        const Positioned.fill(
          child: ColoredBox(
            color: Color(0x66000000),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
    );
  }
}

class MeterReadingApp extends ConsumerWidget {
  const MeterReadingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eagerly create the application-scoped sync service. It must not depend on
    // DeviceSyncScreen being visible; navigation to Home or another feature
    // must not stop the LAN listener, timer, or durable queue processing.
    ref.read(deviceSyncProvider.notifier);

    final themeMode = ref.watch(themeProvider);
    final themePreset = ref.watch(themePresetProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      routerConfig: appRouter,
      onGenerateTitle: (context) => context.l10n.tr('appName'),
      theme: AppTheme.light(themePreset),
      darkTheme: AppTheme.dark(themePreset),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeAnimationDuration: const Duration(milliseconds: 260),
      themeAnimationCurve: Curves.easeOutCubic,
      scrollBehavior: const AppScrollBehavior(),
    );
  }
}
