import 'package:flutter_riverpod/legacy.dart';

import '../../../../services/localDatabaseServices/PillReminder_Service.dart';
import 'pill_home_state.dart';

class PillHomeController extends StateNotifier<PillHomeState> {
  PillHomeController(this._service) : super(PillHomeState()) {
    loadHome();
  }

  final PillReminderService _service;

  Future<void> loadHome() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.ensureOccurrencesGenerated(
        throughDate: state.weekStart.add(const Duration(days: 90)),
      );
      await _service.refreshMissedOccurrences();
      final profiles = await _service.getProfiles();
      final activeProfileId = await _service.getActiveProfileId();
      state = state.copyWith(
        profiles: profiles,
        activeProfileId: activeProfileId,
      );
      await _reloadData();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _reloadData() async {
    final today = _dateOnly(DateTime.now());
    final weekEnd = state.weekStart.add(const Duration(days: 6));
    await _service.ensureOccurrencesGenerated(
      throughDate: weekEnd.add(const Duration(days: 30)),
    );
    await _service.refreshMissedOccurrences();

    final results = await Future.wait<dynamic>([
      _service.getOccurrencesForRange(
        _dateKey(state.weekStart),
        _dateKey(weekEnd),
      ),
      _service.getOccurrencesForDate(_dateKey(today)),
      _service.getOccurrencesForRange(
        _dateKey(today.add(const Duration(days: 1))),
        _dateKey(today.add(const Duration(days: 30))),
      ),
      _service.getOccurrencesForRange(
        _dateKey(today.subtract(const Duration(days: 30))),
        _dateKey(today.subtract(const Duration(days: 1))),
      ),
      _service.getLowStockPills(),
      _service.getStatsForExactDate(_dateKey(today)),
    ]);

    state = state.copyWith(
      weekOccurrences:
          List<Map<String, dynamic>>.from(results[0] as List<dynamic>),
      todayOccurrences:
          List<Map<String, dynamic>>.from(results[1] as List<dynamic>),
      upcomingOccurrences:
          List<Map<String, dynamic>>.from(results[2] as List<dynamic>),
      recentOccurrences:
          List<Map<String, dynamic>>.from(results[3] as List<dynamic>).reversed.toList(),
      lowStockPills:
          List<Map<String, dynamic>>.from(results[4] as List<dynamic>),
      todayStats: Map<String, int>.from(results[5] as Map<dynamic, dynamic>),
      isLoading: false,
      error: null,
    );
  }

  Future<void> changeProfile(int profileId) async {
    await _service.setActiveProfile(profileId);
    state = state.copyWith(activeProfileId: profileId, clearSelectedDate: true);
    await loadHome();
  }

  void selectDate(DateTime date) {
    state = state.copyWith(selectedDate: _dateOnly(date));
  }

  void clearDateFilter() {
    state = state.copyWith(clearSelectedDate: true);
  }

  void changeStatusFilter(String status) {
    state = state.copyWith(statusFilter: status);
  }

  Future<void> moveWeek(int offset) async {
    final next = state.weekStart.add(Duration(days: offset * 7));
    state = state.copyWith(
      weekStart: next,
      clearSelectedDate: true,
      isLoading: true,
    );
    await _reloadData();
  }

  Future<void> goToCurrentWeek() async {
    final now = DateTime.now();
    final start = _dateOnly(now).subtract(Duration(days: now.weekday - 1));
    state = state.copyWith(
      weekStart: start,
      clearSelectedDate: true,
      isLoading: true,
    );
    await _reloadData();
  }

  Future<void> markOccurrence(int occurrenceId, String status) async {
    try {
      await _service.markOccurrence(
        occurrenceId: occurrenceId,
        status: status,
      );
      await _reloadData();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
