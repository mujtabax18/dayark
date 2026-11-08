import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('ur'),
    Locale('ar'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations(Locale('en'));
  }

  static const Map<String, Map<String, String>> _values = {
    'en': {
      'appName': 'Household Manager',
      'dashboard': 'Dashboard',
      'home': 'Home',
      'finance': 'Finance',
      'planner': 'Planner',
      'more': 'More',
      'quickAdd': 'Quick add',
      'goodMorning': 'Good morning',
      'goodAfternoon': 'Good afternoon',
      'goodEvening': 'Good evening',
      'dailyOverview': 'Your complete household overview',
      'refresh': 'Refresh',
      'quickAccess': 'Quick access',
      'summary': 'Summary',
      'meters': 'Meters',
      'grocery': 'Grocery',
      'expenses': 'Expenses',
      'diary': 'Diary',
      'habits': 'Habits',
      'quotes': 'Quotes',
      'loans': 'Loans',
      'photoEditor': 'Media Studio',
      'pillReminder': 'Pill Reminder',
      'docScanner': 'Document Scanner',
      'unitsUsed': 'Units used',
      'monthExpenses': 'Month expenses',
      'pendingGroceries': 'Pending groceries',
      'habitsToday': 'Habits today',
      'activeLoans': 'Active loans',
      'invoices': 'Invoices',
      'mediaFiles': 'Media files',
      'scannedPages': 'Scanned pages',
      'dueMedicines': 'Due medicines',
      'settings': 'Settings',
      'generalAppearance': 'General & Appearance',
      'themeMode': 'Theme mode',
      'light': 'Light',
      'dark': 'Dark',
      'system': 'System',
      'themeStyle': 'Theme style',
      'language': 'Language',
      'homeAlignment': 'Home alignment',
      'reorderHome': 'Reorder dashboard shortcuts',
      'helpLearning': 'Help & Learning',
      'tutorialCenter': 'Tutorial center',
      'tutorialSubtitle': 'Step-by-step guides for every module',
      'sampleData': 'Load sample data',
      'sampleDataSubtitle': 'Add safe demo records to learn the app',
      'sampleDataDone': 'Sample data added successfully.',
      'sampleDataAlready': 'Sample data already exists.',
      'dataManagement': 'Data Management',
      'about': 'About',
      'tutorials': 'Tutorials',
      'gettingStarted': 'Getting started',
      'openModule': 'Open module',
      'steps': 'Steps',
      'welcomeTitle': 'Welcome to Household Manager',
      'welcomeBody': 'Use the dashboard for a live summary, open Tutorials for guided steps, or add sample data from Settings.',
      'startTutorials': 'View tutorials',
      'notNow': 'Not now',
      'noDashboardData': 'Your dashboard will update as you add records.',
    },
    'ur': {
      'appName': 'گھریلو مینیجر',
      'dashboard': 'ڈیش بورڈ',
      'home': 'گھر',
      'finance': 'مالیات',
      'planner': 'منصوبہ بندی',
      'more': 'مزید',
      'quickAdd': 'فوری اضافہ',
      'goodMorning': 'صبح بخیر',
      'goodAfternoon': 'دوپہر بخیر',
      'goodEvening': 'شام بخیر',
      'dailyOverview': 'آپ کے گھر کا مکمل خلاصہ',
      'refresh': 'تازہ کریں',
      'quickAccess': 'فوری رسائی',
      'summary': 'خلاصہ',
      'meters': 'میٹرز',
      'grocery': 'گروسری',
      'expenses': 'اخراجات',
      'diary': 'ڈائری',
      'habits': 'عادات',
      'quotes': 'اقتباسات',
      'loans': 'قرضے',
      'photoEditor': 'میڈیا اسٹوڈیو',
      'pillReminder': 'ادویات یاد دہانی',
      'docScanner': 'دستاویز اسکینر',
      'unitsUsed': 'استعمال شدہ یونٹس',
      'monthExpenses': 'ماہانہ اخراجات',
      'pendingGroceries': 'باقی گروسری',
      'habitsToday': 'آج کی عادات',
      'activeLoans': 'فعال قرضے',
      'invoices': 'انوائسز',
      'mediaFiles': 'میڈیا فائلز',
      'scannedPages': 'اسکین شدہ صفحات',
      'dueMedicines': 'واجب الادا ادویات',
      'settings': 'ترتیبات',
      'generalAppearance': 'عمومی اور ظاہری شکل',
      'themeMode': 'تھیم موڈ',
      'light': 'لائٹ',
      'dark': 'ڈارک',
      'system': 'سسٹم',
      'themeStyle': 'تھیم اسٹائل',
      'language': 'زبان',
      'homeAlignment': 'ہوم ترتیب',
      'reorderHome': 'ڈیش بورڈ شارٹ کٹس ترتیب دیں',
      'helpLearning': 'مدد اور سیکھنا',
      'tutorialCenter': 'ٹیوٹوریل سینٹر',
      'tutorialSubtitle': 'ہر ماڈیول کے لیے مرحلہ وار رہنمائی',
      'sampleData': 'نمونہ ڈیٹا شامل کریں',
      'sampleDataSubtitle': 'ایپ سیکھنے کے لیے محفوظ ڈیمو ریکارڈز',
      'sampleDataDone': 'نمونہ ڈیٹا کامیابی سے شامل ہوگیا۔',
      'sampleDataAlready': 'نمونہ ڈیٹا پہلے سے موجود ہے۔',
      'dataManagement': 'ڈیٹا مینجمنٹ',
      'about': 'متعلق',
      'tutorials': 'ٹیوٹوریلز',
      'gettingStarted': 'شروعات',
      'openModule': 'ماڈیول کھولیں',
      'steps': 'مراحل',
      'welcomeTitle': 'گھریلو مینیجر میں خوش آمدید',
      'welcomeBody': 'لائیو خلاصے کے لیے ڈیش بورڈ، رہنمائی کے لیے ٹیوٹوریلز، یا ترتیبات سے نمونہ ڈیٹا استعمال کریں۔',
      'startTutorials': 'ٹیوٹوریلز دیکھیں',
      'notNow': 'ابھی نہیں',
      'noDashboardData': 'ریکارڈ شامل کرنے پر ڈیش بورڈ خود اپ ڈیٹ ہوگا۔',
    },
    'ar': {
      'appName': 'مدير المنزل',
      'dashboard': 'لوحة التحكم',
      'home': 'الرئيسية',
      'finance': 'المالية',
      'planner': 'المخطط',
      'more': 'المزيد',
      'quickAdd': 'إضافة سريعة',
      'goodMorning': 'صباح الخير',
      'goodAfternoon': 'مساء الخير',
      'goodEvening': 'مساء الخير',
      'dailyOverview': 'ملخص منزلك الكامل',
      'refresh': 'تحديث',
      'quickAccess': 'وصول سريع',
      'summary': 'الملخص',
      'meters': 'العدادات',
      'grocery': 'المشتريات',
      'expenses': 'المصروفات',
      'diary': 'اليوميات',
      'habits': 'العادات',
      'quotes': 'الاقتباسات',
      'loans': 'القروض',
      'photoEditor': 'استوديو الوسائط',
      'pillReminder': 'تذكير الأدوية',
      'docScanner': 'ماسح المستندات',
      'unitsUsed': 'الوحدات المستخدمة',
      'monthExpenses': 'مصروفات الشهر',
      'pendingGroceries': 'مشتريات معلقة',
      'habitsToday': 'عادات اليوم',
      'activeLoans': 'القروض النشطة',
      'invoices': 'الفواتير',
      'mediaFiles': 'ملفات الوسائط',
      'scannedPages': 'صفحات ممسوحة',
      'dueMedicines': 'أدوية مستحقة',
      'settings': 'الإعدادات',
      'generalAppearance': 'عام والمظهر',
      'themeMode': 'وضع المظهر',
      'light': 'فاتح',
      'dark': 'داكن',
      'system': 'النظام',
      'themeStyle': 'نمط المظهر',
      'language': 'اللغة',
      'homeAlignment': 'ترتيب الرئيسية',
      'reorderHome': 'إعادة ترتيب اختصارات اللوحة',
      'helpLearning': 'المساعدة والتعلم',
      'tutorialCenter': 'مركز الشروحات',
      'tutorialSubtitle': 'إرشادات خطوة بخطوة لكل قسم',
      'sampleData': 'إضافة بيانات تجريبية',
      'sampleDataSubtitle': 'سجلات آمنة لتعلم التطبيق',
      'sampleDataDone': 'تمت إضافة البيانات التجريبية.',
      'sampleDataAlready': 'البيانات التجريبية موجودة بالفعل.',
      'dataManagement': 'إدارة البيانات',
      'about': 'حول',
      'tutorials': 'الشروحات',
      'gettingStarted': 'البدء',
      'openModule': 'فتح القسم',
      'steps': 'الخطوات',
      'welcomeTitle': 'مرحباً بك في مدير المنزل',
      'welcomeBody': 'استخدم لوحة التحكم للملخص، والشروحات للتعلم، أو أضف بيانات تجريبية من الإعدادات.',
      'startTutorials': 'عرض الشروحات',
      'notNow': 'ليس الآن',
      'noDashboardData': 'ستتحدث لوحة التحكم عند إضافة السجلات.',
    },
  };

  String tr(String key) {
    return _values[locale.languageCode]?[key] ?? _values['en']![key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales
        .any((item) => item.languageCode == locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
