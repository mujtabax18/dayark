import 'dart:convert';

import 'package:intl/intl.dart';

class MoodEntry {
  const MoodEntry({
    this.id,
    required this.dateTime,
    required this.moodEmoji,
    this.trigger,
    this.notes,
    this.title = '',
    this.gratitude,
    this.tags = const [],
    this.imagePaths = const [],
    this.drawingPath,
    this.reminderAt,
    this.reminderEnabled = false,
    this.isFavorite = false,
    this.accentColorValue = 0xFF6C63FF,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String dateTime;
  final String moodEmoji;
  final String? trigger;
  final String? notes;
  final String title;
  final String? gratitude;
  final List<String> tags;
  final List<String> imagePaths;
  final String? drawingPath;
  final String? reminderAt;
  final bool reminderEnabled;
  final bool isFavorite;
  final int accentColorValue;
  final String? createdAt;
  final String? updatedAt;

  DateTime get entryDateTime => _parseDate(dateTime);

  DateTime? get reminderDateTime {
    final value = reminderAt;
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }

  String get effectiveTitle {
    if (title.trim().isNotEmpty) return title.trim();
    final body = notes?.trim() ?? '';
    if (body.isEmpty) return 'Untitled entry';
    return body.length > 46 ? '${body.substring(0, 46)}…' : body;
  }

  int get wordCount {
    final content = [title, notes ?? '', gratitude ?? '']
        .join(' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
    if (content.isEmpty) return 0;
    return content.split(' ').length;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'dateTime': entryDateTime.toIso8601String(),
      'moodEmoji': moodEmoji,
      'trigger': _nullableText(trigger),
      'notes': _nullableText(notes),
      'title': title.trim(),
      'gratitude': _nullableText(gratitude),
      'tags': jsonEncode(tags),
      'imagePaths': jsonEncode(imagePaths),
      'drawingPath': _nullableText(drawingPath),
      'reminderAt': reminderDateTime?.toIso8601String(),
      'reminderEnabled': reminderEnabled ? 1 : 0,
      'isFavorite': isFavorite ? 1 : 0,
      'accentColorValue': accentColorValue,
      'createdAt': createdAt ?? DateTime.now().toIso8601String(),
      'updatedAt': updatedAt ?? DateTime.now().toIso8601String(),
    };
  }

  factory MoodEntry.fromMap(Map<String, dynamic> map) {
    final rawDate = map['dateTime']?.toString() ?? '';
    final normalizedDate = _parseDate(rawDate).toIso8601String();

    return MoodEntry(
      id: _asInt(map['id']),
      dateTime: normalizedDate,
      moodEmoji: _nonEmpty(map['moodEmoji']?.toString(), fallback: '😊'),
      trigger: _nullableText(map['trigger']?.toString()),
      notes: _nullableText(map['notes']?.toString()),
      title: map['title']?.toString() ?? '',
      gratitude: _nullableText(map['gratitude']?.toString()),
      tags: _decodeStringList(map['tags']),
      imagePaths: _decodeStringList(map['imagePaths']),
      drawingPath: _nullableText(map['drawingPath']?.toString()),
      reminderAt: _nullableText(map['reminderAt']?.toString()),
      reminderEnabled: _asBool(map['reminderEnabled']),
      isFavorite: _asBool(map['isFavorite']),
      accentColorValue:
          _asInt(map['accentColorValue']) ?? MoodEntry._fallbackColor,
      createdAt: _nullableText(map['createdAt']?.toString()),
      updatedAt: _nullableText(map['updatedAt']?.toString()),
    );
  }

  static const int _fallbackColor = 0xFF6C63FF;

  MoodEntry copyWith({
    int? id,
    String? dateTime,
    String? moodEmoji,
    String? trigger,
    bool clearTrigger = false,
    String? notes,
    bool clearNotes = false,
    String? title,
    String? gratitude,
    bool clearGratitude = false,
    List<String>? tags,
    List<String>? imagePaths,
    String? drawingPath,
    bool clearDrawingPath = false,
    String? reminderAt,
    bool clearReminderAt = false,
    bool? reminderEnabled,
    bool? isFavorite,
    int? accentColorValue,
    String? createdAt,
    String? updatedAt,
  }) {
    return MoodEntry(
      id: id ?? this.id,
      dateTime: dateTime ?? this.dateTime,
      moodEmoji: moodEmoji ?? this.moodEmoji,
      trigger: clearTrigger ? null : (trigger ?? this.trigger),
      notes: clearNotes ? null : (notes ?? this.notes),
      title: title ?? this.title,
      gratitude: clearGratitude ? null : (gratitude ?? this.gratitude),
      tags: tags ?? this.tags,
      imagePaths: imagePaths ?? this.imagePaths,
      drawingPath:
          clearDrawingPath ? null : (drawingPath ?? this.drawingPath),
      reminderAt: clearReminderAt ? null : (reminderAt ?? this.reminderAt),
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      isFavorite: isFavorite ?? this.isFavorite,
      accentColorValue: accentColorValue ?? this.accentColorValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime _parseDate(String raw) {
    if (raw.trim().isEmpty) return DateTime.now();

    final iso = DateTime.tryParse(raw);
    if (iso != null) return iso;

    const legacyPatterns = <String>[
      'dd-MM-yyyy h:mm a',
      'dd-MM-yyyy hh:mm a',
      'dd/MM/yyyy h:mm a',
      'yyyy-MM-dd HH:mm:ss.SSS',
    ];

    for (final pattern in legacyPatterns) {
      try {
        return DateFormat(pattern).parse(raw);
      } catch (_) {
        // Try the next legacy format.
      }
    }
    return DateTime.now();
  }

  static List<String> _decodeStringList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    final text = raw.toString().trim();
    if (text.isEmpty) return const [];
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        return decoded
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
    } catch (_) {
      return text
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }

  static String _nonEmpty(String? value, {required String fallback}) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }

  static String? _nullableText(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
