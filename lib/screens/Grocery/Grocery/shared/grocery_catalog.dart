import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class GroceryIconOption {
  final String key;
  final String label;
  final FaIconData icon;

  const GroceryIconOption({
    required this.key,
    required this.label,
    required this.icon,
  });
}

class GroceryCatalog {
  GroceryCatalog._();

  static const icons = <GroceryIconOption>[
    GroceryIconOption(
      key: 'basket-shopping',
      label: 'Groceries',
      icon: FontAwesomeIcons.basketShopping,
    ),
    GroceryIconOption(
      key: 'cart-shopping',
      label: 'Shopping',
      icon: FontAwesomeIcons.cartShopping,
    ),
    GroceryIconOption(
      key: 'house',
      label: 'Home',
      icon: FontAwesomeIcons.house,
    ),
    GroceryIconOption(
      key: 'apple-whole',
      label: 'Fruit',
      icon: FontAwesomeIcons.appleWhole,
    ),
    GroceryIconOption(
      key: 'carrot',
      label: 'Vegetables',
      icon: FontAwesomeIcons.carrot,
    ),
    GroceryIconOption(
      key: 'bread-slice',
      label: 'Bakery',
      icon: FontAwesomeIcons.breadSlice,
    ),
    GroceryIconOption(
      key: 'bottle-water',
      label: 'Drinks',
      icon: FontAwesomeIcons.bottleWater,
    ),
    GroceryIconOption(
      key: 'utensils',
      label: 'Kitchen',
      icon: FontAwesomeIcons.utensils,
    ),
    GroceryIconOption(
      key: 'soap',
      label: 'Cleaning',
      icon: FontAwesomeIcons.soap,
    ),
    GroceryIconOption(
      key: 'shirt',
      label: 'Laundry',
      icon: FontAwesomeIcons.shirt,
    ),
    GroceryIconOption(
      key: 'box-open',
      label: 'Supplies',
      icon: FontAwesomeIcons.boxOpen,
    ),
    GroceryIconOption(
      key: 'list-check',
      label: 'Checklist',
      icon: FontAwesomeIcons.listCheck,
    ),
    GroceryIconOption(
      key: 'calendar-check',
      label: 'Monthly',
      icon: FontAwesomeIcons.calendarCheck,
    ),
    GroceryIconOption(
      key: 'broom',
      label: 'Chore',
      icon: FontAwesomeIcons.broom,
    ),
    GroceryIconOption(
      key: 'bell',
      label: 'Alert',
      icon: FontAwesomeIcons.bell,
    ),
    GroceryIconOption(
      key: 'clock',
      label: 'Timed',
      icon: FontAwesomeIcons.clock,
    ),
  ];

  static const colors = <int>[
    0xFF2E7D32,
    0xFF1565C0,
    0xFF6A1B9A,
    0xFFEF6C00,
    0xFFC62828,
    0xFF00838F,
    0xFF455A64,
    0xFFAD1457,
    0xFF5D4037,
    0xFF283593,
  ];

  static FaIconData iconFor(String? key) {
    final normalized = key?.trim();
    return icons
        .firstWhere(
          (entry) => entry.key == normalized,
          orElse: () => icons.first,
        )
        .icon;
  }

  static String labelForIcon(String? key) {
    final normalized = key?.trim();
    return icons
        .firstWhere(
          (entry) => entry.key == normalized,
          orElse: () => icons.first,
        )
        .label;
  }

  static Color colorFrom(dynamic value, {Color fallback = const Color(0xFF2E7D32)}) {
    if (value is int) return Color(value);
    if (value is num) return Color(value.toInt());
    final parsed = int.tryParse(value?.toString() ?? '');
    return parsed == null ? fallback : Color(parsed);
  }

  static DateTime? dateTimeFrom(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  static bool boolFrom(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value?.toString() == '1' || value?.toString().toLowerCase() == 'true';
  }

  static String statusLabel(String? status) {
    switch (status) {
      case 'completed':
        return 'Completed';
      case 'archived':
        return 'Archived';
      case 'skipped':
        return 'Skipped';
      case 'in_progress':
        return 'In progress';
      default:
        return 'Pending';
    }
  }
}
