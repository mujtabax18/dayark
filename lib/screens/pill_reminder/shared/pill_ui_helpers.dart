import 'dart:convert';

import 'package:flutter/material.dart';

class PillUi {
  PillUi._();

  static Color colorFromHex(
    dynamic value, {
    Color fallback = const Color(0xFF6C63FF),
  }) {
    final raw = value?.toString().replaceAll('#', '').trim() ?? '';
    if (raw.length != 6 && raw.length != 8) return fallback;
    final normalized = raw.length == 6 ? 'FF$raw' : raw;
    return Color(int.tryParse(normalized, radix: 16) ?? fallback.value);
  }

  static String colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color surface(BuildContext context, {bool elevated = false}) {
    final scheme = Theme.of(context).colorScheme;
    return elevated ? scheme.surfaceContainer : scheme.surfaceContainerLow;
  }

  static Color subtleSurface(BuildContext context) {
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  static Color tintedSurface(
    BuildContext context,
    Color color, {
    double opacity = .10,
  }) {
    final base = surface(context);
    final adjustedOpacity = isDark(context)
        ? (opacity * 1.45).clamp(0.0, 1.0).toDouble()
        : opacity;
    return Color.alphaBlend(color.withOpacity(adjustedOpacity), base);
  }

  static BoxDecoration cardDecoration(
    BuildContext context, {
    Color? color,
    Color? borderColor,
    double radius = 24,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: color ?? surface(context),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? scheme.outlineVariant.withOpacity(.75),
      ),
    );
  }

  static Color readableOn(Color color) {
    return ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : const Color(0xFF111318);
  }

  static IconData iconForType(dynamic typeName) {
    switch (typeName?.toString().toLowerCase()) {
      case 'capsule':
        return Icons.medication_outlined;
      case 'syrup':
        return Icons.local_drink_outlined;
      case 'injection':
        return Icons.vaccines_outlined;
      case 'drops':
        return Icons.water_drop_outlined;
      case 'inhaler':
        return Icons.air_outlined;
      case 'cream':
        return Icons.sanitizer_outlined;
      case 'powder':
        return Icons.science_outlined;
      case 'tablet':
      default:
        return Icons.medication_liquid_outlined;
    }
  }

  static String statusLabel(dynamic status) {
    switch (status?.toString().toUpperCase()) {
      case 'TAKEN':
        return 'Taken';
      case 'MISSED':
        return 'Missed';
      case 'SKIPPED':
        return 'Skipped';
      default:
        return 'Pending';
    }
  }

  static Color statusColor(BuildContext context, String status) {
    final dark = isDark(context);
    switch (status.toUpperCase()) {
      case 'TAKEN':
        return dark ? const Color(0xFF55D6A0) : const Color(0xFF16865E);
      case 'MISSED':
        return dark ? const Color(0xFFFF7C86) : const Color(0xFFD83B4B);
      case 'SKIPPED':
        return dark ? const Color(0xFFFFC65A) : const Color(0xFFC47A00);
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  static IconData statusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'TAKEN':
        return Icons.check_circle_outline_rounded;
      case 'MISSED':
        return Icons.cancel_outlined;
      case 'SKIPPED':
        return Icons.remove_circle_outline_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  static String prettyTime(BuildContext context, dynamic value) {
    final parts = value?.toString().split(':') ?? const <String>[];
    if (parts.length < 2) return value?.toString() ?? '';
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return value?.toString() ?? '';
    return TimeOfDay(hour: hour, minute: minute).format(context);
  }

  static String dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static DateTime dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static String shortWeekday(DateTime date) {
    return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][
      date.weekday - 1
    ];
  }

  static String longWeekday(DateTime date) {
    return const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][date.weekday - 1];
  }

  static String monthName(int month) {
    return const [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ][month - 1];
  }

  static String sectionDateLabel(DateTime date) {
    final today = dateOnly(DateTime.now());
    final value = dateOnly(date);
    if (value == today) return 'Today';
    if (value == today.add(const Duration(days: 1))) return 'Tomorrow';
    if (value == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${longWeekday(value)}, ${value.day} ${monthName(value.month)}';
  }

  static String doseLabel(Map<String, dynamic> pill) {
    final quantity = (pill['dose_quantity'] as num?)?.toDouble() ?? 1;
    final quantityText = quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toStringAsFixed(1);
    final type = pill['pill_type_name']?.toString().toLowerCase() ?? 'dose';
    final plural = quantity == 1 ? type : '${type}s';
    return '$quantityText $plural';
  }

  static String strengthLabel(Map<String, dynamic> pill) {
    final value = pill['dosage_value'];
    final unit = pill['dosage_type_name'];
    if (value == null || unit == null) return '';
    final number = (value as num).toDouble();
    final text = number == number.roundToDouble()
        ? number.toInt().toString()
        : number.toStringAsFixed(1);
    return '$text $unit';
  }

  static String scheduleLabel(Map<String, dynamic> pill) {
    final type = pill['rule_type']?.toString().toUpperCase();
    final times = _decodeStringList(pill['times']);
    final timeCount = times.length;
    final suffix = timeCount == 1 ? 'once a day' : '$timeCount times a day';

    switch (type) {
      case 'ONCE':
        return 'One-time dose';
      case 'WEEKLY':
        final days = _decodeIntList(pill['days_of_week']);
        if (days.isEmpty) return 'Weekly';
        final labels = days
            .where((day) => day >= 1 && day <= 7)
            .map(
              (day) => const [
                'Mon',
                'Tue',
                'Wed',
                'Thu',
                'Fri',
                'Sat',
                'Sun',
              ][day - 1],
            )
            .join(', ');
        return labels.isEmpty ? 'Weekly' : 'Weekly · $labels';
      case 'MONTHLY':
        final days = _decodeIntList(pill['days_of_month']);
        return days.isEmpty ? 'Monthly' : 'Monthly on day ${days.join(', ')}';
      case 'INTERVAL':
        final interval = pill['interval_days'] ?? 1;
        return 'Every $interval days';
      case 'DAILY':
      default:
        return 'Daily · $suffix';
    }
  }

  static List<String> _decodeStringList(dynamic value) {
    if (value == null) return const [];
    try {
      return List<String>.from(jsonDecode(value.toString()));
    } catch (_) {
      return const [];
    }
  }

  static List<int> _decodeIntList(dynamic value) {
    if (value == null) return const [];
    try {
      return List<int>.from(jsonDecode(value.toString()));
    } catch (_) {
      return const [];
    }
  }
}
