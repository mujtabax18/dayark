import 'enums.dart';

extension AppSettingKeyX on AppSettingKey {
  String get key {
    switch (this) {
      case AppSettingKey.theme:
        return 'theme';
      case AppSettingKey.themePreset:
        return 'theme_preset';
      case AppSettingKey.language:
        return 'language';
      case AppSettingKey.notifications:
        return 'notifications';
      case AppSettingKey.tutorialSeen:
        return 'tutorial_seen';
      case AppSettingKey.homePageStyle:
        return 'home_page_style';
      case AppSettingKey.homeSummaryStyle:
        return 'home_summary_style';
      case AppSettingKey.homeCreateStyle:
        return 'home_create_style';
      case AppSettingKey.homeSummaryOrder:
        return 'home_summary_order';
      case AppSettingKey.homeVisibleSummaries:
        return 'home_visible_summaries';
      case AppSettingKey.homeQuickActionOrder:
        return 'home_quick_action_order';
      case AppSettingKey.homeVisibleQuickActions:
        return 'home_visible_quick_actions';
      case AppSettingKey.homeVisibleQuickAccess:
        return 'home_visible_quick_access';
      case AppSettingKey.familyTreeHomeShortcutMigrated:
        return 'family_tree_home_shortcut_migrated';
      case AppSettingKey.homeQuoteVisible:
        return 'home_quote_visible';
      case AppSettingKey.showNavigationBar:
        return 'show_navigation_bar';
      case AppSettingKey.currencyCode:
        return 'currency_code';
      case AppSettingKey.currencySymbol:
        return 'currency_symbol';
      case AppSettingKey.currencyName:
        return 'currency_name';
    }
  }
}
