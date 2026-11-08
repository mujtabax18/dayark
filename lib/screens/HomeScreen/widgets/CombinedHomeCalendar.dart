import 'package:flutter/material.dart';

import '../../../services/database_service.dart';
import '../../../services/localDatabaseServices/HomeCalendarService.dart';
import '../../../services/localDatabaseServices/HomeFeaturesService.dart';

class CombinedHomeCalendar extends StatefulWidget {
  const CombinedHomeCalendar({super.key});

  @override
  State<CombinedHomeCalendar> createState() => _CombinedHomeCalendarState();
}

class _CombinedHomeCalendarState extends State<CombinedHomeCalendar> {
  late final HomeCalendarService _calendarService;
  late final HomeFeatureService _featureService;

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateTime.now();
  bool _visible = true;
  bool _loading = true;
  bool _initialized = false;
  List<HomeCalendarEvent> _events = const [];

  @override
  void initState() {
    super.initState();
    final database = DatabaseService();
    _calendarService = HomeCalendarService(database);
    _featureService = HomeFeatureService(database);
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final visible = await _featureService.isCombinedCalendarVisible();
    final events = visible
        ? await _calendarService.getEventsForMonth(_month)
        : const <HomeCalendarEvent>[];
    if (!mounted) return;
    setState(() {
      _visible = visible;
      _events = events;
      _loading = false;
      _initialized = true;
    });
  }

  Future<void> _setVisible(bool value) async {
    await _featureService.setCombinedCalendarVisible(value);
    if (!mounted) return;
    setState(() => _visible = value);
    if (value) await _load();
  }

  Future<void> _changeMonth(int offset) async {
    final next = DateTime(_month.year, _month.month + offset);
    setState(() {
      _month = next;
      _selectedDate = DateTime(next.year, next.month, 1);
    });
    await _load();
  }

  List<HomeCalendarEvent> _eventsFor(DateTime date) => _events
      .where((event) =>
          event.date.year == date.year &&
          event.date.month == date.month &&
          event.date.day == date.day)
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    if (!_initialized) return const SizedBox.shrink();

    if (!_visible) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => _setVisible(true),
          icon: const Icon(Icons.calendar_month_outlined),
          label: const Text('Show combined calendar'),
        ),
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selectedEvents = _eventsFor(_selectedDate);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Combined calendar',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Hide calendar',
                onPressed: () => _setVisible(false),
                icon: const Icon(Icons.visibility_off_outlined),
              ),
            ],
          ),
          Text(
            'Diary, habits, chores, groceries, loans and medicine in one view.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                onPressed: _loading ? null : () => _changeMonth(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  _monthLabel(_month),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: _loading ? null : () => _changeMonth(1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const _WeekHeader(),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 34),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            _MonthGrid(
              month: _month,
              selectedDate: _selectedDate,
              eventCountFor: (date) => _eventsFor(date).length,
              onSelected: (date) => setState(() => _selectedDate = date),
            ),
          const SizedBox(height: 10),
          Text(
            _dayLabel(_selectedDate),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          if (!_loading && selectedEvents.isEmpty)
            Text(
              'Nothing scheduled for this day.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            ...selectedEvents.take(6).map(
                  (event) => _EventRow(event: event),
                ),
          if (selectedEvents.length > 6)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+${selectedEvents.length - 6} more',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _monthLabel(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  static String _dayLabel(DateTime date) {
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return '${weekdays[date.weekday - 1]}, ${date.day} ${_monthLabel(date).split(' ').first}';
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        );
    return Row(
      children: const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
          .map((day) => Expanded(child: Center(child: Text(day))))
          .toList()
          .map((widget) => DefaultTextStyle.merge(style: style, child: widget))
          .toList(),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selectedDate,
    required this.eventCountFor,
    required this.onSelected,
  });

  final DateTime month;
  final DateTime selectedDate;
  final int Function(DateTime date) eventCountFor;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1;
    final total = ((leading + days + 6) ~/ 7) * 7;
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.05,
      ),
      itemCount: total,
      itemBuilder: (context, index) {
        final day = index - leading + 1;
        if (day < 1 || day > days) return const SizedBox.shrink();
        final date = DateTime(month.year, month.month, day);
        final selected = _sameDay(date, selectedDate);
        final isToday = _sameDay(date, today);
        final count = eventCountFor(date);

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onSelected(date),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: selected ? scheme.primaryContainer : null,
              borderRadius: BorderRadius.circular(12),
              border: isToday && !selected
                  ? Border.all(color: scheme.primary)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontWeight: selected || isToday
                        ? FontWeight.w800
                        : FontWeight.w500,
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                if (count > 0)
                  Container(
                    constraints: const BoxConstraints(minWidth: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 8,
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final HomeCalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(_iconFor(event.type), size: 17, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (event.subtitle?.isNotEmpty == true)
                  Text(
                    event.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(HomeCalendarEventType type) {
    switch (type) {
      case HomeCalendarEventType.diary:
        return Icons.menu_book_outlined;
      case HomeCalendarEventType.habit:
        return Icons.track_changes_outlined;
      case HomeCalendarEventType.chore:
        return Icons.cleaning_services_outlined;
      case HomeCalendarEventType.grocery:
        return Icons.shopping_basket_outlined;
      case HomeCalendarEventType.loan:
        return Icons.account_balance_wallet_outlined;
      case HomeCalendarEventType.medicine:
        return Icons.medication_outlined;
    }
  }
}
