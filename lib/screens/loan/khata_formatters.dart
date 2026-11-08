import 'package:intl/intl.dart';

import '../../models/currency_setting.dart';

class KhataFormatters {
  KhataFormatters._();

  static final NumberFormat _amount = NumberFormat('#,##0.##');
  static final DateFormat _shortDate = DateFormat('dd MMM yyyy');
  static final DateFormat _dateTime = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _month = DateFormat('MMM yy');

  static String money(double value, {String currencyCode = 'PKR'}) {
    final preset = CurrencySetting.presetByCode(currencyCode);
    final symbol = preset?.symbol ?? currencyCode.trim();
    return '$symbol ${_amount.format(value)}';
  }

  static String compactMoney(double value, {String currencyCode = 'PKR'}) {
    final absolute = value.abs();
    final sign = value < 0 ? '-' : '';
    if (absolute >= 10000000) {
      return '$sign${money(absolute / 10000000, currencyCode: currencyCode)} Cr';
    }
    if (absolute >= 100000) {
      return '$sign${money(absolute / 100000, currencyCode: currencyCode)} L';
    }
    if (absolute >= 1000) {
      return '$sign${money(absolute / 1000, currencyCode: currencyCode)} K';
    }
    return money(value, currencyCode: currencyCode);
  }

  static String date(String? value) {
    final parsed = value == null ? null : DateTime.tryParse(value);
    return parsed == null ? 'Not set' : _shortDate.format(parsed);
  }

  static String dateTime(String? value) {
    final parsed = value == null ? null : DateTime.tryParse(value);
    return parsed == null ? 'Unknown' : _dateTime.format(parsed);
  }

  static String month(String monthKey) {
    final parsed = DateTime.tryParse('$monthKey-01');
    return parsed == null ? monthKey : _month.format(parsed);
  }

  static String titleCase(String value) {
    if (value.trim().isEmpty) return '';
    return value
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  static String dueLabel(DateTime? dueDate, {required bool settled}) {
    if (settled) return 'Settled';
    if (dueDate == null) return 'No due date';

    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedDue = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final difference = normalizedDue.difference(normalizedToday).inDays;

    if (difference == 0) return 'Due today';
    if (difference == 1) return 'Due tomorrow';
    if (difference > 1) return 'Due in $difference days';
    if (difference == -1) return '1 day overdue';
    return '${difference.abs()} days overdue';
  }
}
