import 'package:flutter/material.dart';

import '../utlis/widgets/color_helper.dart';

class ExpenseCategoryData {
  final int id;
  final String title;
  final String? colorHex;
  final bool hidden;
  final double totalIn;
  final double totalOut;

  /// ✅ NEW (optional, defaults to empty)
  final List<ExpenseItemData> items;

  ExpenseCategoryData({
    required this.id,
    required this.title,
    required this.colorHex,
    required this.hidden,
    required this.totalIn,
    required this.totalOut,
    List<ExpenseItemData>? items,
  }) : items = items ?? [];

  double get net => totalIn - totalOut;

  Color get color {
    if (colorHex == null || colorHex!.isEmpty) {
      return Colors.grey;
    }
    try {
      final hex = colorHex!
          .replaceAll('#', '')
          .replaceAll('0x', '')
          .replaceAll('0X', '');
      final value = hex.length == 6 ? 'FF$hex' : hex;
      return Color(int.parse(value, radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  /// ⚠️ fromMap STILL WORKS (items ignored)
  factory ExpenseCategoryData.fromMap(Map<String, dynamic> map) {
    return ExpenseCategoryData(
      id: map['id'],
      title: map['title'],
      colorHex: map['color'],
      hidden: map['hidden'] == 1,
      totalIn: (map['total_in'] ?? 0).toDouble(),
      totalOut: (map['total_out'] ?? 0).toDouble(),
    );
  }
}

class ExpenseCategory {
  final int id;
  final String title;
  final String? colorHex;
  final bool hidden;

  ExpenseCategory({
    required this.id,
    required this.title,
    required this.colorHex,
    required this.hidden,
  });

  Color get color => colorFromHex(colorHex) ?? Colors.grey;
}

class ExpenseItemData {
  final int id;
  final String name;
  final String date;
  final double price;
  final String inOrOut;
  final String? notes;
  final int? closingId;

  ExpenseItemData({
    required this.id,
    required this.name,
    required this.date,
    required this.price,
    required this.inOrOut,
    this.notes,
    this.closingId,
  });

  factory ExpenseItemData.fromMap(Map<String, dynamic> map) {
    return ExpenseItemData(
      id: map['item_id'] as int,
      name: map['item_name'] as String,
      date: map['item_date'] as String,
      price: (map['item_price'] as num?)?.toDouble() ?? 0,
      inOrOut: map['item_in_or_out'] as String,
      notes: map['item_notes'] as String?,
      closingId: map['item_closing_id'] as int?,
    );
  }
}
