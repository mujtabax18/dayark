import '../database_service.dart';

enum HomeCalendarEventType {
  diary,
  habit,
  chore,
  grocery,
  loan,
  medicine,
}

class HomeCalendarEvent {
  const HomeCalendarEvent({
    required this.date,
    required this.title,
    required this.type,
    this.subtitle,
    this.entityId,
  });

  final DateTime date;
  final String title;
  final HomeCalendarEventType type;
  final String? subtitle;
  final int? entityId;
}

class HomeCalendarService {
  HomeCalendarService(this._databaseService);

  final DatabaseService _databaseService;

  Future<List<HomeCalendarEvent>> getEventsForMonth(DateTime month) async {
    final db = await _databaseService.database;
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final events = <HomeCalendarEvent>[];

    if (await _tableExists('mood_entries')) {
      final rows = await db.query(
        'mood_entries',
        where: 'dateTime >= ? AND dateTime < ?',
        whereArgs: [start.toIso8601String(), end.toIso8601String()],
      );
      for (final row in rows) {
        final date = _parseDate(row['dateTime']);
        if (date == null) continue;
        events.add(HomeCalendarEvent(
          date: date,
          title: _text(row['title'], fallback: 'Diary entry'),
          subtitle: _textOrNull(row['moodEmoji']),
          type: HomeCalendarEventType.diary,
          entityId: _id(row['id']),
        ));
      }
    }

    if (await _tableExists('household_chores')) {
      final rows = await db.query(
        'household_chores',
        where: 'due_at IS NOT NULL AND due_at >= ? AND due_at < ?',
        whereArgs: [start.toIso8601String(), end.toIso8601String()],
      );
      for (final row in rows) {
        final date = _parseDate(row['due_at']);
        if (date == null) continue;
        events.add(HomeCalendarEvent(
          date: date,
          title: _text(row['title'], fallback: 'Chore'),
          subtitle: _textOrNull(row['status']),
          type: HomeCalendarEventType.chore,
          entityId: _id(row['id']),
        ));
      }
    }

    if (await _tableExists('grocery_titles')) {
      final rows = await db.query('grocery_titles');
      for (final row in rows) {
        final date = _parseDate(row['due_at']) ?? _parseDate(row['plan_date']);
        if (date == null || !_sameMonth(date, month)) continue;
        events.add(HomeCalendarEvent(
          date: date,
          title: _text(row['title'], fallback: 'Grocery list'),
          subtitle: 'Grocery',
          type: HomeCalendarEventType.grocery,
          entityId: _id(row['id']),
        ));
      }
    }

    if (await _tableExists('loans')) {
      final rows = await db.query(
        'loans',
        where: 'due_date IS NOT NULL AND due_date >= ? AND due_date < ?',
        whereArgs: [_dateKey(start), _dateKey(end)],
      );
      for (final row in rows) {
        final date = _parseDate(row['due_date']);
        if (date == null) continue;
        events.add(HomeCalendarEvent(
          date: date,
          title: _text(row['entity_name'], fallback: 'Loan due'),
          subtitle: 'Loan due',
          type: HomeCalendarEventType.loan,
          entityId: _id(row['id']),
        ));
      }
    }

    if (await _tableExists('reminder_occurrences') &&
        await _tableExists('pills')) {
      final rows = await db.rawQuery('''
        SELECT ro.id, ro.scheduled_date, ro.scheduled_time, ro.status,
               p.name AS pill_name
        FROM reminder_occurrences ro
        INNER JOIN pills p ON p.id = ro.pill_id
        WHERE ro.scheduled_date >= ? AND ro.scheduled_date < ?
        ORDER BY ro.scheduled_date, ro.scheduled_time
      ''', [_dateKey(start), _dateKey(end)]);
      for (final row in rows) {
        final date = _parseDate(row['scheduled_date']);
        if (date == null) continue;
        events.add(HomeCalendarEvent(
          date: date,
          title: _text(row['pill_name'], fallback: 'Medicine'),
          subtitle: _text(row['scheduled_time'], fallback: 'Medicine reminder'),
          type: HomeCalendarEventType.medicine,
          entityId: _id(row['id']),
        ));
      }
    }

    if (await _tableExists('habits')) {
      final rows = await db.query(
        'habits',
        where: 'is_active = 1',
      );
      final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
      for (final row in rows) {
        final createdAt = _parseDate(row['created_at']);
        final archivedAt = _parseDate(row['archived_at']);
        final repeatDays = _parseRepeatDays(row['repeat_days']);
        for (var day = 1; day <= daysInMonth; day++) {
          final date = DateTime(month.year, month.month, day);
          if (createdAt != null && _dateOnly(date).isBefore(_dateOnly(createdAt))) {
            continue;
          }
          if (archivedAt != null && _dateOnly(date).isAfter(_dateOnly(archivedAt))) {
            continue;
          }
          if (!repeatDays.contains(date.weekday)) continue;
          final deadlineHour = _int(row['deadline_hour'], fallback: 23);
          final deadlineMinute = _int(row['deadline_minute'], fallback: 59);
          events.add(HomeCalendarEvent(
            date: DateTime(
              date.year,
              date.month,
              date.day,
              deadlineHour,
              deadlineMinute,
            ),
            title: _text(row['title'], fallback: 'Habit'),
            subtitle: 'Habit',
            type: HomeCalendarEventType.habit,
            entityId: _id(row['id']),
          ));
        }
      }
    }

    events.sort((a, b) => a.date.compareTo(b.date));
    return events;
  }

  Future<bool> _tableExists(String table) async {
    final db = await _databaseService.database;
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
      [table],
    );
    return rows.isNotEmpty;
  }

  static bool _sameMonth(DateTime date, DateTime month) =>
      date.year == month.year && date.month == month.month;

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime? _parseDate(Object? value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static int? _id(Object? value) => value is num ? value.toInt() : int.tryParse('$value');

  static int _int(Object? value, {required int fallback}) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

  static String _text(Object? value, {required String fallback}) {
    final raw = value?.toString().trim() ?? '';
    return raw.isEmpty ? fallback : raw;
  }

  static String? _textOrNull(Object? value) {
    final raw = value?.toString().trim() ?? '';
    return raw.isEmpty ? null : raw;
  }

  static Set<int> _parseRepeatDays(Object? value) {
    final raw = value?.toString() ?? '';
    final parsed = raw
        .split(',')
        .map((item) => int.tryParse(item.trim()))
        .whereType<int>()
        .where((day) => day >= 1 && day <= 7)
        .toSet();
    return parsed.isEmpty ? <int>{1, 2, 3, 4, 5, 6, 7} : parsed;
  }

  static String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
