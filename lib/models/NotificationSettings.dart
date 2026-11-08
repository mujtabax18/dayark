// lib/models/notification_settings.dart
import 'dart:convert';

import 'package:flutter/material.dart';

class NotificationSettings {
  final int? id;
  final String featureName;
  final bool isActive;
  final String
      intervalType; // 'minutes', 'hours', 'days', 'weeks', 'months', 'years'
  final int intervalValue;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final List<int> blockedDays; // 1 (Monday) to 7 (Sunday)
  final List<int> blockedDates; // 1-31
  final List<int> blockedMonths; // 1-12
  final DateTime createdAt;
  final DateTime updatedAt;

  NotificationSettings({
    this.id,
    required this.featureName,
    this.isActive = true,
    this.intervalType = 'days',
    this.intervalValue = 1,
    this.startTime,
    this.endTime,
    this.blockedDays = const [],
    this.blockedDates = const [],
    this.blockedMonths = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'feature_name': featureName,
      'is_active': isActive ? 1 : 0,
      'interval_type': intervalType,
      'interval_value': intervalValue,
      'start_time':
          startTime != null ? '${startTime!.hour}:${startTime!.minute}' : null,
      'end_time':
          endTime != null ? '${endTime!.hour}:${endTime!.minute}' : null,
      'blocked_days': jsonEncode(blockedDays),
      'blocked_dates': jsonEncode(blockedDates),
      'blocked_months': jsonEncode(blockedMonths),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory NotificationSettings.fromMap(Map<String, dynamic> map) {
    TimeOfDay? parseTime(String? timeString) {
      if (timeString == null) return null;
      final parts = timeString.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    return NotificationSettings(
      id: map['id'],
      featureName: map['feature_name'],
      isActive: map['is_active'] == 1,
      intervalType: map['interval_type'],
      intervalValue: map['interval_value'],
      startTime: parseTime(map['start_time']),
      endTime: parseTime(map['end_time']),
      blockedDays: List<int>.from(jsonDecode(map['blocked_days'] ?? '[]')),
      blockedDates: List<int>.from(jsonDecode(map['blocked_dates'] ?? '[]')),
      blockedMonths: List<int>.from(jsonDecode(map['blocked_months'] ?? '[]')),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  NotificationSettings copyWith({
    int? id,
    String? featureName,
    bool? isActive,
    String? intervalType,
    int? intervalValue,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    List<int>? blockedDays,
    List<int>? blockedDates,
    List<int>? blockedMonths,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationSettings(
      id: id ?? this.id,
      featureName: featureName ?? this.featureName,
      isActive: isActive ?? this.isActive,
      intervalType: intervalType ?? this.intervalType,
      intervalValue: intervalValue ?? this.intervalValue,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      blockedDays: blockedDays ?? this.blockedDays,
      blockedDates: blockedDates ?? this.blockedDates,
      blockedMonths: blockedMonths ?? this.blockedMonths,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
