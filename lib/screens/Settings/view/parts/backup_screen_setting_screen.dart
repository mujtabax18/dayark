part of '../backupScreen.dart';

class SettingScreen extends ConsumerWidget {
  const SettingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neutral = context.themeColors.neutral;
    final backupNotifier = ref.read(backupRestoreProvider.notifier);
    final backupStatus = ref.watch(backupRestoreProvider);
    final themeMode = ref.watch(themeProvider);
    final themePreset = ref.watch(themePresetProvider);
    final locale = ref.watch(localeProvider);
    final currency = ref.watch(currencyProvider);
    final homeLayout = ref.watch(homeLayoutProvider);

    final appearanceSectionKey = GlobalKey();
    final dashboardSectionKey = GlobalKey();
    final learningSectionKey = GlobalKey();
    final dataSectionKey = GlobalKey();
    final updatesSectionKey = GlobalKey();
    final aboutSectionKey = GlobalKey();

    void scrollToSection(_SettingsSection section) {
      final key = switch (section) {
        _SettingsSection.appearance => appearanceSectionKey,
        _SettingsSection.dashboard => dashboardSectionKey,
        _SettingsSection.learning => learningSectionKey,
        _SettingsSection.data => dataSectionKey,
        _SettingsSection.updates => updatesSectionKey,
        _SettingsSection.about => aboutSectionKey,
      };
      final targetContext = key.currentContext;
      if (targetContext == null) return;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
        alignment: 0.02,
      );
    }

    return Scaffold(
      backgroundColor: neutral.background,
      appBar: AppBar(
        title: Text(
          context.l10n.tr('settings'),
          style: TextStyle(color: neutral.textPrimary),
        ),
        centerTitle: MediaQuery.sizeOf(context).width < 1100,
        backgroundColor: neutral.background,
        elevation: 0,
      ),
      body: _SettingsResponsiveFrame(
        onSectionSelected: scrollToSection,
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ResponsiveContent(
          maxWidth: 1040,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(
              context,
              context.l10n.tr('generalAppearance'),
              key: appearanceSectionKey,
            ),
            SettingsGroup(
              children: [
                SettingsTile(
                  icon: _themeModeIcon(themeMode),
                  title: context.l10n.tr('themeMode'),
                  subtitle: _themeModeLabel(context, themeMode),
                  color: AppColors.task,
                  onTap: () => _showThemeModeSheet(context, ref, themeMode),
                ),
                const SettingsDivider(),
                SettingsTile(
                  icon: Icons.palette_outlined,
                  title: context.l10n.tr('themeStyle'),
                  subtitle: _themePresetLabel(context, themePreset),
                  color: themePreset.primary,
                  trailing: CircleAvatar(
                    radius: 11,
                    backgroundColor: themePreset.primary,
                  ),
                  onTap: () =>
                      _showThemePresetSheet(context, ref, themePreset),
                ),
                const SettingsDivider(),
                SettingsTile(
                  icon: Icons.language_rounded,
                  title: context.l10n.tr('language'),
                  subtitle: _languageLabel(locale.languageCode),
                  color: AppColors.info,
                  onTap: () => _showLanguageSheet(context, ref, locale),
                ),
                const SettingsDivider(),
                SettingsTile(
                  icon: Icons.payments_outlined,
                  title: 'Currency',
                  subtitle: '${currency.name} • ${currency.shortLabel}',
                  color: AppColors.success,
                  trailing: Text(
                    currency.symbol,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  onTap: () => _showCurrencySheet(context, ref, currency),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionHeader(
              context,
              'Home & Navigation',
              key: dashboardSectionKey,
            ),
            SettingsGroup(
              children: [
                SettingsTile(
                  icon: Icons.home_work_outlined,
                  title: 'Home layout style',
                  subtitle: homeLayout.style.label,
                  color: AppColors.success,
                  onTap: () => _showHomeStyleSheet(
                    context,
                    ref,
                    homeLayout.style,
                  ),
                ),
                const SettingsDivider(),
                SettingsTile(
                  icon: Icons.view_week_outlined,
                  title: 'Summary UI',
                  subtitle: homeLayout.summaryStyle.label,
                  color: AppColors.info,
                  onTap: () => _showHomeSummaryStyleSheet(
                    context,
                    ref,
                    homeLayout.summaryStyle,
                  ),
                ),
                const SettingsDivider(),
                SettingsTile(
                  icon: Icons.add_box_outlined,
                  title: 'Create new UI',
                  subtitle: homeLayout.createStyle.label,
                  color: AppColors.habit,
                  onTap: () => _showHomeCreateStyleSheet(
                    context,
                    ref,
                    homeLayout.createStyle,
                  ),
                ),
                const SettingsDivider(),
                SettingsTile(
                  icon: Icons.dashboard_customize_outlined,
                  title: 'Customize Home',
                  subtitle:
                      'Summaries, create shortcuts, quick access, order and quotation card',
                  color: AppColors.bills,
                  onTap: () => context.push(RoutesStr.homeSetting),
                ),
                const SettingsDivider(),
                SettingsTile(
                  icon: homeLayout.showNavigationBar
                      ? Icons.dock_rounded
                      : Icons.space_bar_rounded,
                  title: 'Navigation layout',
                  subtitle: homeLayout.showNavigationBar
                      ? 'Phone: bottom navigation • Desktop: expanded admin sidebar'
                      : 'Phone: hidden navigation • Desktop: compact admin sidebar',
                  color: AppColors.info,
                  trailing: Switch.adaptive(
                    value: homeLayout.showNavigationBar,
                    onChanged: (value) => ref
                        .read(homeLayoutProvider.notifier)
                        .setNavigationBarVisible(value),
                  ),
                  onTap: () => ref
                      .read(homeLayoutProvider.notifier)
                      .setNavigationBarVisible(
                        !homeLayout.showNavigationBar,
                      ),
                ),
                const SettingsDivider(),
                SettingsTile(
                  icon: homeLayout.showQuote
                      ? Icons.format_quote_rounded
                      : Icons.comments_disabled_outlined,
                  title: 'Quotation card',
                  subtitle: homeLayout.showQuote
                      ? 'Visible on Home'
                      : 'Hidden from Home',
                  color: AppColors.habit,
                  trailing: Switch.adaptive(
                    value: homeLayout.showQuote,
                    onChanged: (value) => ref
                        .read(homeLayoutProvider.notifier)
                        .setQuoteVisible(value),
                  ),
                  onTap: () => ref
                      .read(homeLayoutProvider.notifier)
                      .setQuoteVisible(!homeLayout.showQuote),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionHeader(
              context,
              context.l10n.tr('helpLearning'),
              key: learningSectionKey,
            ),
            SettingsGroup(
              children: [
                SettingsTile(
                  icon: Icons.school_outlined,
                  title: context.l10n.tr('tutorialCenter'),
                  subtitle: context.l10n.tr('tutorialSubtitle'),
                  color: AppColors.habit,
                  onTap: () => context.push(RoutesStr.tutorials),
                ),
                const SettingsDivider(),
                SettingsTile(
                  icon: Icons.auto_awesome_outlined,
                  title: context.l10n.tr('sampleData'),
                  subtitle: context.l10n.tr('sampleDataSubtitle'),
                  color: AppColors.warning,
                  onTap: () => _seedDemoData(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionHeader(
              context,
              context.l10n.tr('dataManagement'),
              key: dataSectionKey,
            ),
            SettingsGroup(
              children: [
                SettingsTile(
                  icon: Icons.devices_rounded,
                  title: 'Local Multi-Device Sync',
                  subtitle: 'Pair devices on your LAN, sync offline writes, manage conflicts and remote logout',
                  color: AppColors.info,
                  onTap: () => openResponsiveModule(context, RoutesStr.deviceSync),
                ),
                const SettingsDivider(),
                SettingsTile(
                  icon: Icons.restore_page_rounded,
                  title: 'Primary Local Backups',
                  subtitle:
                      'Primary-only local restore points for device sync',
                  color: AppColors.success,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => openResponsiveModule(
                    context,
                    RoutesStr.primaryLocalBackups,
                  ),
                ),
                const SettingsDivider(),
                SettingsTile(
                  icon: Icons.inventory_2_outlined,
                  title: 'Portable Full Backup',
                  subtitle:
                      'Password-encrypted database, media and documents (.housezip)',
                  color: AppColors.expense,
                  onTap: () => backupNotifier.backupDatabase(context),
                ),
                const SettingsDivider(),
                SettingsTile(
                  icon: Icons.perm_media_outlined,
                  title: 'Media Studio Backup',
                  subtitle:
                      'Password-encrypted originals, edits and media history',
                  color: AppColors.task,
                  onTap: () => backupNotifier.backupMediaLibrary(context),
                ),
                const SettingsDivider(),
                SettingsTile(
                  icon: Icons.document_scanner_outlined,
                  title: 'Document Scanner Backup',
                  subtitle:
                      'Password-encrypted groups, page images, edits and metadata',
                  color: AppColors.bills,
                  onTap: () => backupNotifier.backupDocumentScanner(context),
                ),
                const SettingsDivider(),
                SettingsTile(
                  icon: Icons.history_edu_outlined,
                  title: 'Legacy Backup & Compatibility',
                  subtitle: 'Older ZIP/JSON/SQLite restores, legacy exports and selected tables',
                  color: AppColors.warning,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => openResponsiveModule(context, RoutesStr.backupCompatibility),
                ),
                const SettingsDivider(),
                SettingsTile(
                  icon: Icons.restore,
                  title: 'Restore Encrypted Backup',
                  subtitle:
                      'Requires the password used to protect the .housezip file',
                  color: AppColors.success,
                  onTap: () => _confirmRestore(
                    context,
                    () => backupNotifier.restoreDatabase(context),
                  ),
                ),
                const SettingsDivider(),
                SettingsTile(
                  icon: Icons.history_rounded,
                  title: 'Restore Last Delete Safety Backup',
                  subtitle:
                      'Restore the automatic full backup created before the last Delete All Database action',
                  color: AppColors.success,
                  onTap: () => _confirmRestoreDeleteSafetyBackup(
                    context,
                    backupNotifier,
                  ),
                ),
                const SettingsDivider(),
                SettingsTile(
                  icon: Icons.delete_forever_rounded,
                  title: 'Delete All Database',
                  subtitle:
                      'Creates a full automatic safety backup first, then permanently clears all database records',
                  color: Theme.of(context).colorScheme.error,
                  onTap: () => _confirmDeleteAllDatabase(
                    context,
                    backupNotifier,
                  ),
                ),
                const SettingsDivider(),
                SettingsTile(
                  icon: Icons.storage,
                  title: 'Database Inspector',
                  subtitle: 'View raw tables',
                  color: AppColors.task,
                  onTap: () => context.push(RoutesStr.dataBaseViewer),
                ),
              ],
            ),
            if (backupStatus != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: neutral.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: neutral.divider),
                ),
                child: Text(
                  backupStatus,
                  style: TextStyle(
                    color: neutral.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            _sectionHeader(context, 'App Updates', key: updatesSectionKey),
            SettingsGroup(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable:
                      AppUpdatePreferences.instance.checkOnStartupNotifier,
                  builder: (context, enabled, _) {
                    return SettingsTile(
                      icon: Icons.update_rounded,
                      title: 'Check for updates on startup',
                      subtitle: enabled
                          ? 'Automatically check for a new DayArk version when the app starts'
                          : 'Startup update checks are disabled',
                      color: AppColors.success,
                      trailing: Switch.adaptive(
                        value: enabled,
                        onChanged: (value) async {
                          await AppUpdatePreferences.instance
                              .setCheckOnStartup(value);
                        },
                      ),
                      onTap: () async {
                        await AppUpdatePreferences.instance
                            .setCheckOnStartup(!enabled);
                      },
                    );
                  },
                ),
                const SettingsDivider(),
                SettingsTile(
                  icon: Icons.system_update_alt_rounded,
                  title: 'Check for updates',
                  subtitle: 'Get the latest official DayArk release for this device',
                  color: AppColors.info,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => AppUpdateCoordinator.checkAndPrompt(
                    context,
                    manual: true,
                  ),
                ),
                const SettingsDivider(),
                SettingsTile(
                  icon: Icons.open_in_new_rounded,
                  title: 'View DayArk on GitHub',
                  subtitle: 'Open the official releases repository',
                  color: AppColors.task,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _openGithubRepository(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionHeader(
              context,
              context.l10n.tr('about'),
              key: aboutSectionKey,
            ),
            const AppInfoWidget(),
          ],
          ),
        ),
      ),
      ),
    );
  }

  Future<void> _openGithubRepository(BuildContext context) async {
    try {
      await AppUpdateService.instance.openGithubRepository();
    } on AppUpdateException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open GitHub right now.')),
      );
    }
  }

  IconData _themeModeIcon(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => Icons.light_mode_outlined,
      ThemeMode.dark => Icons.dark_mode_outlined,
      ThemeMode.system => Icons.brightness_auto_outlined,
    };
  }

  String _themeModeLabel(BuildContext context, ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => context.l10n.tr('light'),
      ThemeMode.dark => context.l10n.tr('dark'),
      ThemeMode.system => context.l10n.tr('system'),
    };
  }

  String _themePresetLabel(
    BuildContext context,
    AppThemePreset preset,
  ) {
    final language = Localizations.localeOf(context).languageCode;
    if (language == 'ur') {
      return switch (preset) {
        AppThemePreset.indigo => 'انڈیگو',
        AppThemePreset.emerald => 'زمرد',
        AppThemePreset.ocean => 'سمندر',
        AppThemePreset.sunset => 'غروب آفتاب',
        AppThemePreset.rose => 'گلابی',
      };
    }
    if (language == 'ar') {
      return switch (preset) {
        AppThemePreset.indigo => 'نيلي',
        AppThemePreset.emerald => 'زمردي',
        AppThemePreset.ocean => 'محيط',
        AppThemePreset.sunset => 'غروب',
        AppThemePreset.rose => 'وردي',
      };
    }
    return preset.label;
  }

  String _languageLabel(String languageCode) {
    return switch (languageCode) {
      'ur' => 'اردو',
      'ar' => 'العربية',
      _ => 'English',
    };
  }

  Future<void> _showHomeStyleSheet(
    BuildContext context,
    WidgetRef ref,
    HomePageStyle selected,
  ) async {
    final style = await showModalBottomSheet<HomePageStyle>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: HomePageStyle.values.map((style) {
            return RadioListTile<HomePageStyle>(
              value: style,
              groupValue: selected,
              title: Text(style.label),
              subtitle: Text(style.description),
              secondary: Icon(switch (style) {
                HomePageStyle.detailed => Icons.dashboard_rounded,
                HomePageStyle.quickLinks => Icons.apps_rounded,
                HomePageStyle.compact => Icons.view_quilt_rounded,
                HomePageStyle.glance => Icons.auto_awesome_mosaic_rounded,
              }),
              onChanged: (value) => Navigator.pop(sheetContext, value),
            );
          }).toList(growable: false),
        ),
      ),
    );
    if (style != null) {
      await ref.read(homeLayoutProvider.notifier).setStyle(style);
    }
  }

  Future<void> _showHomeSummaryStyleSheet(
    BuildContext context,
    WidgetRef ref,
    HomeSummaryStyle selected,
  ) async {
    final style = await showModalBottomSheet<HomeSummaryStyle>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: HomeSummaryStyle.values.map((style) {
            return RadioListTile<HomeSummaryStyle>(
              value: style,
              groupValue: selected,
              title: Text(style.label),
              subtitle: Text(style.description),
              secondary: Icon(switch (style) {
                HomeSummaryStyle.cards => Icons.dashboard_rounded,
                HomeSummaryStyle.compact => Icons.view_carousel_outlined,
                HomeSummaryStyle.glance => Icons.view_week_outlined,
              }),
              onChanged: (value) => Navigator.pop(sheetContext, value),
            );
          }).toList(growable: false),
        ),
      ),
    );
    if (style != null) {
      await ref.read(homeLayoutProvider.notifier).setSummaryStyle(style);
    }
  }

  Future<void> _showHomeCreateStyleSheet(
    BuildContext context,
    WidgetRef ref,
    HomeCreateStyle selected,
  ) async {
    final style = await showModalBottomSheet<HomeCreateStyle>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: HomeCreateStyle.values.map((style) {
            return RadioListTile<HomeCreateStyle>(
              value: style,
              groupValue: selected,
              title: Text(style.label),
              subtitle: Text(style.description),
              secondary: Icon(switch (style) {
                HomeCreateStyle.floating => Icons.add_circle_outline_rounded,
                HomeCreateStyle.dock => Icons.view_agenda_outlined,
              }),
              onChanged: (value) => Navigator.pop(sheetContext, value),
            );
          }).toList(growable: false),
        ),
      ),
    );
    if (style != null) {
      await ref.read(homeLayoutProvider.notifier).setCreateStyle(style);
    }
  }

  Future<void> _showThemeModeSheet(
    BuildContext context,
    WidgetRef ref,
    ThemeMode selected,
  ) async {
    final mode = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeMode.values.map((mode) {
            return RadioListTile<ThemeMode>(
              value: mode,
              groupValue: selected,
              title: Text(_themeModeLabel(context, mode)),
              secondary: Icon(_themeModeIcon(mode)),
              onChanged: (value) => Navigator.pop(sheetContext, value),
            );
          }).toList(growable: false),
        ),
      ),
    );
    if (mode != null) await ref.read(themeProvider.notifier).setTheme(mode);
  }

  Future<void> _showThemePresetSheet(
    BuildContext context,
    WidgetRef ref,
    AppThemePreset selected,
  ) async {
    final preset = await showModalBottomSheet<AppThemePreset>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppThemePreset.values.map((preset) {
            return RadioListTile<AppThemePreset>(
              value: preset,
              groupValue: selected,
              title: Text(_themePresetLabel(context, preset)),
              secondary: CircleAvatar(backgroundColor: preset.primary),
              onChanged: (value) => Navigator.pop(sheetContext, value),
            );
          }).toList(growable: false),
        ),
      ),
    );
    if (preset != null) {
      await ref.read(themePresetProvider.notifier).setPreset(preset);
    }
  }

  Future<void> _showLanguageSheet(
    BuildContext context,
    WidgetRef ref,
    Locale selected,
  ) async {
    const languages = <Locale>[
      Locale('en'),
      Locale('ur'),
      Locale('ar'),
    ];
    final locale = await showModalBottomSheet<Locale>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: languages.map((locale) {
            return RadioListTile<String>(
              value: locale.languageCode,
              groupValue: selected.languageCode,
              title: Text(_languageLabel(locale.languageCode)),
              onChanged: (_) => Navigator.pop(sheetContext, locale),
            );
          }).toList(growable: false),
        ),
      ),
    );
    if (locale != null) {
      await ref.read(localeProvider.notifier).setLocale(locale);
    }
  }

  Future<void> _showCurrencySheet(
    BuildContext context,
    WidgetRef ref,
    CurrencySetting selected,
  ) async {
    const customKey = '__custom__';
    final exactPreset = CurrencySetting.presets.where(
      (item) =>
          item.code == selected.code &&
          item.symbol == selected.symbol &&
          item.name == selected.name &&
          !selected.isCustom,
    );
    var selectedKey = exactPreset.isNotEmpty ? exactPreset.first.code : customKey;
    final codeController = TextEditingController(text: selected.code);
    final symbolController = TextEditingController(text: selected.symbol);
    final nameController = TextEditingController(
      text: selected.isCustom ? selected.name : '',
    );

    final currency = await showModalBottomSheet<CurrencySetting>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final isCustom = selectedKey == customKey;
          final preview = isCustom
              ? CurrencySetting(
                  code: codeController.text.trim().isEmpty
                      ? 'CUR'
                      : codeController.text.trim().toUpperCase(),
                  symbol: symbolController.text.trim().isEmpty
                      ? '¤'
                      : symbolController.text.trim(),
                  name: nameController.text.trim().isEmpty
                      ? 'Custom currency'
                      : nameController.text.trim(),
                  isCustom: true,
                )
              : CurrencySetting.presetByCode(selectedKey) ?? CurrencySetting.pkr;

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Currency',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose the default shown for finance summaries, invoices and new Khata accounts.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedKey,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      ...CurrencySetting.presets.map(
                        (item) => DropdownMenuItem<String>(
                          value: item.code,
                          child: Text(
                            item.dropdownLabel,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const DropdownMenuItem<String>(
                        value: customKey,
                        child: Text('Custom currency…'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setModalState(() => selectedKey = value);
                    },
                  ),
                  if (isCustom) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: codeController,
                            textCapitalization: TextCapitalization.characters,
                            maxLength: 8,
                            decoration: const InputDecoration(
                              labelText: 'Code / label',
                              hintText: 'e.g. PKR, USD, COIN',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: symbolController,
                            maxLength: 8,
                            decoration: const InputDecoration(
                              labelText: 'Symbol / prefix',
                              hintText: r'e.g. Rs, $, ₿',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: nameController,
                      maxLength: 40,
                      decoration: const InputDecoration(
                        labelText: 'Currency name (optional)',
                        hintText: 'e.g. My Points',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.visibility_outlined),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Preview: ${preview.format(1234.56)}',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            if (isCustom) {
                              final code = codeController.text.trim().toUpperCase();
                              final symbol = symbolController.text.trim();
                              if (code.isEmpty || symbol.isEmpty) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Enter both a custom code and symbol/prefix.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              Navigator.pop(
                                sheetContext,
                                CurrencySetting(
                                  code: code,
                                  symbol: symbol,
                                  name: nameController.text.trim().isEmpty
                                      ? 'Custom currency'
                                      : nameController.text.trim(),
                                  isCustom: true,
                                ),
                              );
                              return;
                            }

                            Navigator.pop(
                              sheetContext,
                              CurrencySetting.presetByCode(selectedKey) ??
                                  CurrencySetting.pkr,
                            );
                          },
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    codeController.dispose();
    symbolController.dispose();
    nameController.dispose();

    if (currency != null) {
      await ref.read(currencyProvider.notifier).setCurrency(currency);
    }
  }

  Future<void> _seedDemoData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: context.l10n.tr('sampleData'),
      message: context.l10n.tr('sampleDataSubtitle'),
      confirmLabel: context.l10n.tr('sampleData'),
    );
    if (!confirmed || !context.mounted) return;

    try {
      final db = await ref.read(databaseServiceProvider).database;
      final result = await DemoDataSeeder.seed(db);
      ref.invalidate(homeDashboardProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.tr(
              result.alreadyPresent ? 'sampleDataAlready' : 'sampleDataDone',
            ),
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add sample data: $error')),
      );
    }
  }

  Future<void> _selectTablesAndBackup(
    BuildContext context,
    BackupRestoreNotifier backupNotifier,
  ) async {
    List<String> tables;
    try {
      tables = await backupNotifier.getDatabaseTables();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load database tables: $error')),
      );
      return;
    }

    if (!context.mounted) return;
    if (tables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No database tables were found.')),
      );
      return;
    }

    final selectedTables = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final selected = tables.toSet();
        var searchText = '';

        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredTables = tables
                .where(
                  (table) => table.toLowerCase().contains(
                        searchText.trim().toLowerCase(),
                      ),
                )
                .toList(growable: false);

            return FractionallySizedBox(
              heightFactor: 0.9,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Tables',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${selected.length} of ${tables.length} selected',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          decoration: const InputDecoration(
                            hintText: 'Search tables',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (value) {
                            setModalState(() => searchText = value);
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                setModalState(() {
                                  selected.addAll(tables);
                                });
                              },
                              icon: const Icon(Icons.select_all),
                              label: const Text('Select all'),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                setModalState(selected.clear);
                              },
                              icon: const Icon(Icons.deselect),
                              label: const Text('Clear'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: filteredTables.isEmpty
                        ? const Center(child: Text('No matching tables.'))
                        : ListView.builder(
                            itemCount: filteredTables.length,
                            itemBuilder: (context, index) {
                              final table = filteredTables[index];
                              final isSelected = selected.contains(table);

                              return CheckboxListTile(
                                value: isSelected,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Text(_readableTableName(table)),
                                subtitle: Text(
                                  table,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                onChanged: (checked) {
                                  setModalState(() {
                                    if (checked == true) {
                                      selected.add(table);
                                    } else {
                                      selected.remove(table);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: selected.isEmpty
                                ? null
                                : () => Navigator.pop(
                                      sheetContext,
                                      Set<String>.from(selected),
                                    ),
                            icon: const Icon(Icons.folder_open),
                            label: Text('Continue (${selected.length})'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!context.mounted || selectedTables == null || selectedTables.isEmpty) {
      return;
    }

    await backupNotifier.backupSelectedTables(context, selectedTables);
  }

  Future<void> _confirmRestoreDeleteSafetyBackup(
    BuildContext context,
    BackupRestoreNotifier backupNotifier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore latest safety backup?'),
        content: const Text(
          'This restores the newest automatic full backup that was created '
          'before Delete All Database. Tables included in that backup will '
          'replace their current database contents.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.history_rounded),
            label: const Text('Restore latest'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await backupNotifier.restoreLatestDeleteSafetyBackup(context);
    }
  }

  Future<void> _confirmDeleteAllDatabase(
    BuildContext context,
    BackupRestoreNotifier backupNotifier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DeleteAllDatabaseDialog(),
    );
    if (confirmed != true || !context.mounted) return;

    final deleted =
        await backupNotifier.deleteAllDatabaseWithSafetyBackup(context);
    if (!deleted || !context.mounted) return;

    // The destructive reset recreates the app-level ProviderScope. All
    // database-backed providers and screen-local selections are refreshed as
    // one unit, so individual invalidations are intentionally unnecessary.
  }

  Future<void> _confirmRestore(
    BuildContext context,
    Future<void> Function() restore,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
          'Media Studio and Document Scanner backups merge into the current '
          'library. A full backup replaces the tables included in that backup. '
          'Create a fresh portable full backup first when you need a rollback copy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Choose backup'),
          ),
        ],
      ),
    );
    if (confirmed == true) await restore();
  }

  String _readableTableName(String tableName) {
    return tableName
        .split('_')
        .where((word) => word.isNotEmpty)
        .map(
          (word) => '${word.substring(0, 1).toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  Widget _sectionHeader(
    BuildContext context,
    String title, {
    Key? key,
  }) {
    final neutral = context.themeColors.neutral;
    return Padding(
      key: key,
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: neutral.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}


