part of '../tutorial_center_screen.dart';

class _TutorialGuide {
  const _TutorialGuide({
    required this.title,
    required this.description,
    required this.icon,
    required this.steps,
    this.route,
  });

  final String title;
  final String description;
  final IconData icon;
  final List<String> steps;
  final String? route;
}

List<_TutorialGuide> _guides(String language) {
  if (language == 'ur') return _urduGuides;
  if (language == 'ar') return _arabicGuides;
  return _englishGuides;
}

const _englishGuides = <_TutorialGuide>[
  _TutorialGuide(
    title: 'Dashboard',
    description: 'Understand summaries and open every module quickly.',
    icon: Icons.dashboard_outlined,
    route: RoutesStr.home,
    steps: [
      'Pull down or use refresh to reload all summary cards.',
      'Review meters, expenses, groceries, habits, loans and files.',
      'Use Quick access to open any module.',
    ],
  ),
  _TutorialGuide(
    title: 'Meters',
    description: 'Track baseline readings, consumption and estimated cost.',
    icon: Icons.electric_meter_outlined,
    route: RoutesStr.meterList,
    steps: [
      'Create a meter and enter its baseline reading.',
      'Add each new reading with its date and optional bill amount.',
      'Use the detail screen to review units used from baseline and trends.',
    ],
  ),
  _TutorialGuide(
    title: 'Grocery & household plans',
    description: 'Create reusable shopping plans, items and chores.',
    icon: Icons.shopping_basket_outlined,
    route: RoutesStr.grocery,
    steps: [
      'Create a grocery plan with a date and reminder.',
      'Add new items or select reusable existing items.',
      'Check items off and review completion status.',
    ],
  ),
  _TutorialGuide(
    title: 'Expenses',
    description: 'Manage income, spending categories and month closing.',
    icon: Icons.payments_outlined,
    route: RoutesStr.expense,
    steps: [
      'Create categories such as Food, Bills or Salary.',
      'Add each transaction as In or Out.',
      'Use filters, reports and month closing to review a period safely.',
    ],
  ),
  _TutorialGuide(
    title: 'Personal diary',
    description: 'Save private notes, moods, images and drawings.',
    icon: Icons.menu_book_outlined,
    route: RoutesStr.moodTracker,
    steps: [
      'Create an entry and choose a mood or accent.',
      'Add notes, gratitude, tags, images or a drawing.',
      'Use favorites, search and the optional diary lock.',
    ],
  ),
  _TutorialGuide(
    title: 'Habit tracker',
    description: 'Build streaks with daily completion and history.',
    icon: Icons.track_changes_outlined,
    route: RoutesStr.habits,
    steps: [
      'Create a habit with repeat days and a daily deadline.',
      'Update it before the deadline to protect the streak.',
      'Review calendar, completion rate and missed days.',
    ],
  ),
  _TutorialGuide(
    title: 'Quotation studio',
    description: 'Store, style, favorite and reuse quotations.',
    icon: Icons.format_quote_rounded,
    route: RoutesStr.quotes,
    steps: [
      'Add a quote, author and category.',
      'Choose background, alignment, font size and author visibility.',
      'Mark favorites and track frequently used quotes.',
    ],
  ),
  _TutorialGuide(
    title: 'Invoices',
    description: 'Create professional invoices with saved businesses and customers.',
    icon: Icons.receipt_long_outlined,
    route: RoutesStr.invoices,
    steps: [
      'Select an existing business or create one from the invoice form.',
      'Select or add a customer, then add invoice line items.',
      'Apply tax, discount, payment details, terms and a template.',
      'Save, preview and export the invoice to your selected location.',
    ],
  ),
  _TutorialGuide(
    title: 'Digital Khata & loans',
    description: 'Track money given, received, payments and reminders.',
    icon: Icons.account_balance_wallet_outlined,
    route: RoutesStr.loans,
    steps: [
      'Create an account and choose whether money is given or received.',
      'Record every payment or adjustment as a transaction.',
      'Review balance, due date and share a WhatsApp statement.',
    ],
  ),
  _TutorialGuide(
    title: 'Media studio',
    description: 'Manage offline images, video, PDF and text-to-speech tools.',
    icon: Icons.perm_media_outlined,
    route: RoutesStr.multimedia,
    steps: [
      'Import or create media from the dashboard.',
      'Edit while keeping original files and version history.',
      'Use Media Backup in Settings to preserve files and history.',
    ],
  ),
  _TutorialGuide(
    title: 'Pill reminder',
    description: 'Create medicine schedules and track doses and stock.',
    icon: Icons.medication_outlined,
    route: RoutesStr.pillReminder,
    steps: [
      'Create your profile and add a medicine.',
      'Set dosage, schedule, start date and reminders.',
      'Mark doses taken or skipped and watch low stock alerts.',
    ],
  ),
  _TutorialGuide(
    title: 'Document scanner',
    description: 'Scan, organize, edit and export documents offline.',
    icon: Icons.document_scanner_outlined,
    route: RoutesStr.scannerGallery,
    steps: [
      'Capture or import pages and place them in a document group.',
      'Crop, rotate, enhance and reorder pages.',
      'Export PDF and use Scanner Backup to preserve all source files.',
    ],
  ),
  _TutorialGuide(
    title: 'Settings, themes and backup',
    description: 'Personalize the app and protect all local data.',
    icon: Icons.settings_outlined,
    route: RoutesStr.backup,
    steps: [
      'Choose light, dark or system mode and a color theme.',
      'Select English, Urdu or Arabic.',
      'Create a portable full backup before major changes.',
      'Use sample data only when you want a safe guided example.',
    ],
  ),
];

const _urduGuides = <_TutorialGuide>[
  _TutorialGuide(
    title: 'ڈیش بورڈ',
    description: 'تمام خلاصے دیکھیں اور ہر ماڈیول فوری کھولیں۔',
    icon: Icons.dashboard_outlined,
    route: RoutesStr.home,
    steps: ['تازہ کرنے کے لیے نیچے کھینچیں۔', 'خلاصہ کارڈز دیکھیں۔', 'فوری رسائی سے مطلوبہ ماڈیول کھولیں۔'],
  ),
  _TutorialGuide(
    title: 'میٹرز',
    description: 'بیس لائن، ریڈنگ اور استعمال شدہ یونٹس محفوظ کریں۔',
    icon: Icons.electric_meter_outlined,
    route: RoutesStr.meterList,
    steps: ['میٹر اور بیس لائن شامل کریں۔', 'نئی ریڈنگ تاریخ کے ساتھ درج کریں۔', 'تفصیل میں استعمال اور لاگت دیکھیں۔'],
  ),
  _TutorialGuide(
    title: 'گروسری اور گھریلو پلان',
    description: 'خریداری کی فہرستیں اور کام منظم کریں۔',
    icon: Icons.shopping_basket_outlined,
    route: RoutesStr.grocery,
    steps: ['نیا پلان بنائیں۔', 'نئی یا موجودہ اشیاء شامل کریں۔', 'مکمل اشیاء کو چیک کریں۔'],
  ),
  _TutorialGuide(
    title: 'اخراجات',
    description: 'آمدن، خرچ، کیٹیگری اور ماہانہ کلوزنگ۔',
    icon: Icons.payments_outlined,
    route: RoutesStr.expense,
    steps: ['کیٹیگری بنائیں۔', 'آمدن یا خرچ شامل کریں۔', 'فلٹر، رپورٹ اور ماہانہ کلوزنگ استعمال کریں۔'],
  ),
  _TutorialGuide(
    title: 'ڈائری اور عادات',
    description: 'روزانہ نوٹس، موڈ، عادت اور سٹریک محفوظ کریں۔',
    icon: Icons.track_changes_outlined,
    route: RoutesStr.habits,
    steps: ['عادت یا ڈائری اندراج بنائیں۔', 'روزانہ وقت پر اپ ڈیٹ کریں۔', 'کیلنڈر اور تاریخ دیکھیں۔'],
  ),
  _TutorialGuide(
    title: 'انوائس اور قرض',
    description: 'کاروبار، گاہک، انوائس اور کھاتہ منظم کریں۔',
    icon: Icons.receipt_long_outlined,
    route: RoutesStr.invoices,
    steps: ['کاروبار اور گاہک منتخب کریں۔', 'آئٹمز، ٹیکس اور شرائط شامل کریں۔', 'انوائس محفوظ یا ایکسپورٹ کریں۔'],
  ),
  _TutorialGuide(
    title: 'میڈیا، اسکینر اور ادویات',
    description: 'آف لائن فائلیں، دستاویزات اور یاد دہانیاں۔',
    icon: Icons.perm_media_outlined,
    route: RoutesStr.multimedia,
    steps: ['فائل درآمد یا اسکین کریں۔', 'اصل فائل اور ایڈٹ ہسٹری محفوظ رکھیں۔', 'سیٹنگز سے مکمل بیک اپ بنائیں۔'],
  ),
  _TutorialGuide(
    title: 'ترتیبات اور بیک اپ',
    description: 'تھیم، زبان، نمونہ ڈیٹا اور مکمل بیک اپ۔',
    icon: Icons.settings_outlined,
    route: RoutesStr.backup,
    steps: ['تھیم اور زبان منتخب کریں۔', 'سیکھنے کے لیے نمونہ ڈیٹا شامل کریں۔', 'اہم تبدیلی سے پہلے پورٹیبل بیک اپ بنائیں۔'],
  ),
];

const _arabicGuides = <_TutorialGuide>[
  _TutorialGuide(
    title: 'لوحة التحكم',
    description: 'اعرض الملخصات وافتح كل قسم بسرعة.',
    icon: Icons.dashboard_outlined,
    route: RoutesStr.home,
    steps: ['اسحب للتحديث.', 'راجع بطاقات الملخص.', 'استخدم الوصول السريع لفتح القسم.'],
  ),
  _TutorialGuide(
    title: 'العدادات',
    description: 'احفظ القراءة الأساسية والاستهلاك والتكلفة.',
    icon: Icons.electric_meter_outlined,
    route: RoutesStr.meterList,
    steps: ['أضف العداد والقراءة الأساسية.', 'سجل كل قراءة جديدة.', 'راجع الاستهلاك في صفحة التفاصيل.'],
  ),
  _TutorialGuide(
    title: 'المشتريات والمصروفات',
    description: 'نظم القوائم والدخل والمصروفات.',
    icon: Icons.shopping_basket_outlined,
    route: RoutesStr.grocery,
    steps: ['أنشئ قائمة أو فئة.', 'أضف العناصر أو المعاملات.', 'استخدم التقارير والإغلاق الشهري.'],
  ),
  _TutorialGuide(
    title: 'العادات واليوميات',
    description: 'تابع العادات والمزاج والسجل اليومي.',
    icon: Icons.track_changes_outlined,
    route: RoutesStr.habits,
    steps: ['أنشئ عادة أو مذكرة.', 'حدّثها يومياً قبل الموعد.', 'راجع التقويم والسجل.'],
  ),
  _TutorialGuide(
    title: 'الفواتير والقروض',
    description: 'أدر الشركات والعملاء والفواتير والحسابات.',
    icon: Icons.receipt_long_outlined,
    route: RoutesStr.invoices,
    steps: ['اختر الشركة والعميل.', 'أضف البنود والضريبة والشروط.', 'احفظ أو صدّر الفاتورة.'],
  ),
  _TutorialGuide(
    title: 'الوسائط والماسح والأدوية',
    description: 'أدوات ملفات ومستندات وتذكير تعمل دون اتصال.',
    icon: Icons.perm_media_outlined,
    route: RoutesStr.multimedia,
    steps: ['استورد ملفاً أو امسح مستنداً.', 'احتفظ بالأصل وسجل التعديلات.', 'أنشئ نسخة احتياطية كاملة من الإعدادات.'],
  ),
  _TutorialGuide(
    title: 'الإعدادات والنسخ الاحتياطي',
    description: 'المظهر واللغة والبيانات التجريبية والحماية.',
    icon: Icons.settings_outlined,
    route: RoutesStr.backup,
    steps: ['اختر المظهر واللغة.', 'أضف بيانات تجريبية للتعلم.', 'أنشئ نسخة محمولة قبل التغييرات الكبيرة.'],
  ),
];
