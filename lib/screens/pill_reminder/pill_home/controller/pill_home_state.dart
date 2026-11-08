class PillHomeState {
  PillHomeState({
    this.isLoading = false,
    DateTime? weekStart,
    this.selectedDate,
    this.statusFilter = 'ALL',
    this.profiles = const [],
    this.activeProfileId,
    this.weekOccurrences = const [],
    this.todayOccurrences = const [],
    this.upcomingOccurrences = const [],
    this.recentOccurrences = const [],
    this.lowStockPills = const [],
    this.todayStats = const {
      'PENDING': 0,
      'TAKEN': 0,
      'MISSED': 0,
      'SKIPPED': 0,
    },
    this.error,
  }) : weekStart = weekStart ?? _startOfWeek(DateTime.now());

  final bool isLoading;
  final DateTime weekStart;
  final DateTime? selectedDate;
  final String statusFilter;
  final List<Map<String, dynamic>> profiles;
  final int? activeProfileId;
  final List<Map<String, dynamic>> weekOccurrences;
  final List<Map<String, dynamic>> todayOccurrences;
  final List<Map<String, dynamic>> upcomingOccurrences;
  final List<Map<String, dynamic>> recentOccurrences;
  final List<Map<String, dynamic>> lowStockPills;
  final Map<String, int> todayStats;
  final String? error;

  List<Map<String, dynamic>> get visibleWeekOccurrences {
    return weekOccurrences.where((item) {
      final dateMatches = selectedDate == null ||
          item['scheduled_date'] == _dateKey(selectedDate!);
      final statusMatches = statusFilter == 'ALL' ||
          item['status']?.toString() == statusFilter;
      return dateMatches && statusMatches;
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> get groupedVisibleOccurrences {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final item in visibleWeekOccurrences) {
      final key = item['scheduled_date'] as String;
      groups.putIfAbsent(key, () => []).add(item);
    }
    return groups;
  }

  PillHomeState copyWith({
    bool? isLoading,
    DateTime? weekStart,
    DateTime? selectedDate,
    bool clearSelectedDate = false,
    String? statusFilter,
    List<Map<String, dynamic>>? profiles,
    int? activeProfileId,
    List<Map<String, dynamic>>? weekOccurrences,
    List<Map<String, dynamic>>? todayOccurrences,
    List<Map<String, dynamic>>? upcomingOccurrences,
    List<Map<String, dynamic>>? recentOccurrences,
    List<Map<String, dynamic>>? lowStockPills,
    Map<String, int>? todayStats,
    String? error,
  }) {
    return PillHomeState(
      isLoading: isLoading ?? this.isLoading,
      weekStart: weekStart ?? this.weekStart,
      selectedDate:
          clearSelectedDate ? null : (selectedDate ?? this.selectedDate),
      statusFilter: statusFilter ?? this.statusFilter,
      profiles: profiles ?? this.profiles,
      activeProfileId: activeProfileId ?? this.activeProfileId,
      weekOccurrences: weekOccurrences ?? this.weekOccurrences,
      todayOccurrences: todayOccurrences ?? this.todayOccurrences,
      upcomingOccurrences: upcomingOccurrences ?? this.upcomingOccurrences,
      recentOccurrences: recentOccurrences ?? this.recentOccurrences,
      lowStockPills: lowStockPills ?? this.lowStockPills,
      todayStats: todayStats ?? this.todayStats,
      error: error,
    );
  }

  static DateTime _startOfWeek(DateTime date) {
    final value = DateTime(date.year, date.month, date.day);
    return value.subtract(Duration(days: value.weekday - 1));
  }

  static String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
