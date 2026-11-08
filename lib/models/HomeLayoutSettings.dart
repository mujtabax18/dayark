enum HomePageStyle {
  detailed,
  quickLinks,
  compact,
  glance,
}

extension HomePageStyleX on HomePageStyle {
  String get storageValue => switch (this) {
        HomePageStyle.detailed => 'detailed',
        HomePageStyle.quickLinks => 'quick_links',
        HomePageStyle.compact => 'compact',
        HomePageStyle.glance => 'glance',
      };

  String get label => switch (this) {
        HomePageStyle.detailed => 'Full',
        HomePageStyle.quickLinks => 'Minimal',
        HomePageStyle.compact => 'Compact',
        HomePageStyle.glance => 'Modern glance',
      };

  String get description => switch (this) {
        HomePageStyle.detailed =>
          'Summaries, quotation and module shortcuts.',
        HomePageStyle.quickLinks =>
          'A compact quotation and navigation shortcuts only.',
        HomePageStyle.compact =>
          'Small summaries, quotation and navigation shortcuts.',
        HomePageStyle.glance =>
          'Today-at-a-glance first, quotation, quick access and a cleaner dashboard flow.',
      };

  static HomePageStyle fromStorage(String? value) {
    return switch (value) {
      'quick_links' => HomePageStyle.quickLinks,
      'compact' => HomePageStyle.compact,
      'glance' => HomePageStyle.glance,
      _ => HomePageStyle.detailed,
    };
  }
}

enum HomeSummaryStyle {
  cards,
  compact,
  glance,
}

extension HomeSummaryStyleX on HomeSummaryStyle {
  String get storageValue => switch (this) {
        HomeSummaryStyle.cards => 'cards',
        HomeSummaryStyle.compact => 'compact',
        HomeSummaryStyle.glance => 'glance',
      };

  String get label => switch (this) {
        HomeSummaryStyle.cards => 'Cards',
        HomeSummaryStyle.compact => 'Compact carousel',
        HomeSummaryStyle.glance => 'At a glance',
      };

  String get description => switch (this) {
        HomeSummaryStyle.cards =>
          'Large cards with the most detail and two supporting values.',
        HomeSummaryStyle.compact =>
          'Small swipeable cards that use less vertical space.',
        HomeSummaryStyle.glance =>
          'One horizontal summary panel inspired by the new Home design.',
      };

  static HomeSummaryStyle fromStorage(String? value) {
    return switch (value) {
      'compact' => HomeSummaryStyle.compact,
      'glance' => HomeSummaryStyle.glance,
      _ => HomeSummaryStyle.cards,
    };
  }
}

enum HomeCreateStyle {
  floating,
  dock,
}

extension HomeCreateStyleX on HomeCreateStyle {
  String get storageValue => switch (this) {
        HomeCreateStyle.floating => 'floating',
        HomeCreateStyle.dock => 'dock',
      };

  String get label => switch (this) {
        HomeCreateStyle.floating => 'Floating buttons',
        HomeCreateStyle.dock => 'Create new dock',
      };

  String get description => switch (this) {
        HomeCreateStyle.floating =>
          'Keep Settings and + as floating buttons when navigation is hidden.',
        HomeCreateStyle.dock =>
          'Show a bottom Create new panel with shortcuts and a large + button.',
      };

  static HomeCreateStyle fromStorage(String? value) {
    return switch (value) {
      'dock' => HomeCreateStyle.dock,
      _ => HomeCreateStyle.floating,
    };
  }
}

abstract final class HomeQuickActionId {
  static const expense = 'expense';
  static const meterReading = 'meter_reading';
  static const habit = 'habit';
  static const grocery = 'grocery';
  static const pill = 'pill';
  static const loan = 'loan';
  static const invoice = 'invoice';
  static const quotation = 'quotation';
  static const media = 'media';
  static const diary = 'diary';
  static const scan = 'scan';
}

class HomeLayoutSettings {
  const HomeLayoutSettings({
    this.style = HomePageStyle.detailed,
    this.summaryStyle = HomeSummaryStyle.cards,
    this.createStyle = HomeCreateStyle.floating,
    this.summaryOrder = defaultSummaryOrder,
    this.visibleSummaryIds = defaultVisibleSummaryIds,
    this.quickActionOrder = defaultQuickActionOrder,
    this.visibleQuickActionIds = defaultVisibleQuickActionIds,
    this.visibleQuickAccessIds = defaultVisibleQuickAccessIds,
    this.showQuote = true,
    this.showNavigationBar = false,
  });

  // Count-based summaries (Diary, Invoices, Media and Scanner) are included so
  // the new glance panel can mirror the supplied dashboard reference.
  static const List<int> defaultSummaryOrder = <int>[
    3,
    8,
    6,
    5,
    1,
    2,
    9,
    11,
    10,
    12,
  ];
  static const Set<int> summaryFeatureIds = <int>{
    1,
    2,
    3,
    5,
    6,
    8,
    9,
    10,
    11,
    12,
  };
  static const Set<int> defaultVisibleSummaryIds = summaryFeatureIds;

  static const List<String> defaultQuickActionOrder = <String>[
    HomeQuickActionId.expense,
    HomeQuickActionId.diary,
    HomeQuickActionId.habit,
    HomeQuickActionId.grocery,
    HomeQuickActionId.meterReading,
    HomeQuickActionId.pill,
    HomeQuickActionId.loan,
    HomeQuickActionId.invoice,
    HomeQuickActionId.quotation,
    HomeQuickActionId.media,
    HomeQuickActionId.scan,
  ];

  static const Set<String> quickActionIds = <String>{
    HomeQuickActionId.expense,
    HomeQuickActionId.meterReading,
    HomeQuickActionId.habit,
    HomeQuickActionId.grocery,
    HomeQuickActionId.pill,
    HomeQuickActionId.loan,
    HomeQuickActionId.invoice,
    HomeQuickActionId.quotation,
    HomeQuickActionId.media,
    HomeQuickActionId.diary,
    HomeQuickActionId.scan,
  };

  static const Set<String> defaultVisibleQuickActionIds = quickActionIds;

  static const Set<int> quickAccessFeatureIds = <int>{
    1,
    2,
    3,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
  };
  static const Set<int> defaultVisibleQuickAccessIds = quickAccessFeatureIds;

  final HomePageStyle style;
  final HomeSummaryStyle summaryStyle;
  final HomeCreateStyle createStyle;
  final List<int> summaryOrder;
  final Set<int> visibleSummaryIds;
  final List<String> quickActionOrder;
  final Set<String> visibleQuickActionIds;
  final Set<int> visibleQuickAccessIds;
  final bool showQuote;
  final bool showNavigationBar;

  List<int> get orderedVisibleSummaryIds => summaryOrder
      .where((id) => visibleSummaryIds.contains(id))
      .toList(growable: false);

  List<String> get orderedVisibleQuickActionIds => quickActionOrder
      .where((id) => visibleQuickActionIds.contains(id))
      .toList(growable: false);

  HomeLayoutSettings copyWith({
    HomePageStyle? style,
    HomeSummaryStyle? summaryStyle,
    HomeCreateStyle? createStyle,
    List<int>? summaryOrder,
    Set<int>? visibleSummaryIds,
    List<String>? quickActionOrder,
    Set<String>? visibleQuickActionIds,
    Set<int>? visibleQuickAccessIds,
    bool? showQuote,
    bool? showNavigationBar,
  }) {
    return HomeLayoutSettings(
      style: style ?? this.style,
      summaryStyle: summaryStyle ?? this.summaryStyle,
      createStyle: createStyle ?? this.createStyle,
      summaryOrder: summaryOrder ?? this.summaryOrder,
      visibleSummaryIds: visibleSummaryIds ?? this.visibleSummaryIds,
      quickActionOrder: quickActionOrder ?? this.quickActionOrder,
      visibleQuickActionIds:
          visibleQuickActionIds ?? this.visibleQuickActionIds,
      visibleQuickAccessIds:
          visibleQuickAccessIds ?? this.visibleQuickAccessIds,
      showQuote: showQuote ?? this.showQuote,
      showNavigationBar: showNavigationBar ?? this.showNavigationBar,
    );
  }

  static List<int> normalizeSummaryOrder(Iterable<int> values) {
    final normalized = <int>[];
    for (final id in values) {
      if (summaryFeatureIds.contains(id) && !normalized.contains(id)) {
        normalized.add(id);
      }
    }
    for (final id in defaultSummaryOrder) {
      if (!normalized.contains(id)) normalized.add(id);
    }
    return List<int>.unmodifiable(normalized);
  }

  static Set<int> normalizeVisibleSummaryIds(Iterable<int> values) {
    return Set<int>.unmodifiable(
      values.where(summaryFeatureIds.contains),
    );
  }

  static List<String> normalizeQuickActionOrder(Iterable<String> values) {
    final normalized = <String>[];
    for (final id in values) {
      if (quickActionIds.contains(id) && !normalized.contains(id)) {
        normalized.add(id);
      }
    }
    for (final id in defaultQuickActionOrder) {
      if (!normalized.contains(id)) normalized.add(id);
    }
    return List<String>.unmodifiable(normalized);
  }

  static Set<String> normalizeVisibleQuickActionIds(Iterable<String> values) {
    return Set<String>.unmodifiable(
      values.where(quickActionIds.contains),
    );
  }

  static Set<int> normalizeVisibleQuickAccessIds(Iterable<int> values) {
    return Set<int>.unmodifiable(
      values.where(quickAccessFeatureIds.contains),
    );
  }
}
