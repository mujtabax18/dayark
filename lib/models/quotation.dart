class Quotation {
  const Quotation({
    this.id,
    required this.text,
    this.author = '',
    this.category = 'General',
    this.source = 'manual',
    this.isFavorite = false,
    this.isUsed = false,
    this.usageCount = 0,
    this.backgroundStyle = 'sunrise',
    this.textAlign = 'center',
    this.fontSize = 30,
    this.showAuthor = true,
    required this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String text;
  final String author;
  final String category;
  final String source;
  final bool isFavorite;
  final bool isUsed;
  final int usageCount;
  final String backgroundStyle;
  final String textAlign;
  final double fontSize;
  final bool showAuthor;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text.trim(),
      'author': author.trim(),
      'category': category.trim().isEmpty ? 'General' : category.trim(),
      'source': source,
      'is_favorite': isFavorite ? 1 : 0,
      'is_used': isUsed ? 1 : 0,
      'usage_count': usageCount,
      'background_style': backgroundStyle,
      'text_align': textAlign,
      'font_size': fontSize,
      'show_author': showAuthor ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': (updatedAt ?? createdAt).toIso8601String(),
    };
  }

  factory Quotation.fromMap(Map<String, dynamic> map) {
    final createdAt = _parseDate(map['created_at']) ?? DateTime.now();
    return Quotation(
      id: _asInt(map['id']),
      text: map['text']?.toString() ?? '',
      author: map['author']?.toString() ?? '',
      category: _nonEmpty(map['category']?.toString(), fallback: 'General'),
      source: _nonEmpty(map['source']?.toString(), fallback: 'manual'),
      isFavorite: _asBool(map['is_favorite']),
      isUsed: _asBool(map['is_used']),
      usageCount: _asInt(map['usage_count']) ?? 0,
      backgroundStyle:
          _nonEmpty(map['background_style']?.toString(), fallback: 'sunrise'),
      textAlign: _nonEmpty(map['text_align']?.toString(), fallback: 'center'),
      fontSize: _asDouble(map['font_size']) ?? 30,
      showAuthor: map.containsKey('show_author')
          ? _asBool(map['show_author'])
          : true,
      createdAt: createdAt,
      updatedAt: _parseDate(map['updated_at']),
    );
  }

  Quotation copyWith({
    int? id,
    String? text,
    String? author,
    String? category,
    String? source,
    bool? isFavorite,
    bool? isUsed,
    int? usageCount,
    String? backgroundStyle,
    String? textAlign,
    double? fontSize,
    bool? showAuthor,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Quotation(
      id: id ?? this.id,
      text: text ?? this.text,
      author: author ?? this.author,
      category: category ?? this.category,
      source: source ?? this.source,
      isFavorite: isFavorite ?? this.isFavorite,
      isUsed: isUsed ?? this.isUsed,
      usageCount: usageCount ?? this.usageCount,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      textAlign: textAlign ?? this.textAlign,
      fontSize: fontSize ?? this.fontSize,
      showAuthor: showAuthor ?? this.showAuthor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get shareText {
    final authorText = author.trim().isEmpty ? '' : '\n— ${author.trim()}';
    return '“${text.trim()}”$authorText';
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == '1' || normalized == 'true' || normalized == 'yes';
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static String _nonEmpty(String? value, {required String fallback}) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? fallback : normalized;
  }
}
