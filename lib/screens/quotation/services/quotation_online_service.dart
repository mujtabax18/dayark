import 'dart:async';
import 'dart:convert';
import 'dart:io';

class OnlineQuotationCategory {
  const OnlineQuotationCategory({
    required this.id,
    required this.name,
    required this.count,
    required this.file,
    required this.sha256,
  });

  final String id;
  final String name;
  final int count;
  final String file;
  final String sha256;

  factory OnlineQuotationCategory.fromJson(Map<String, dynamic> json) {
    return OnlineQuotationCategory(
      id: json['id']?.toString().trim() ?? '',
      name: json['name']?.toString().trim() ?? '',
      count: _asInt(json['count']),
      file: json['file']?.toString().trim() ?? '',
      sha256: json['sha256']?.toString().trim() ?? '',
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class OnlineQuotationCatalog {
  const OnlineQuotationCatalog({
    required this.schemaVersion,
    required this.contentVersion,
    required this.updatedAt,
    required this.totalQuotations,
    required this.totalCategories,
    required this.categories,
  });

  final int schemaVersion;
  final String contentVersion;
  final DateTime? updatedAt;
  final int totalQuotations;
  final int totalCategories;
  final List<OnlineQuotationCategory> categories;

  factory OnlineQuotationCatalog.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'];
    return OnlineQuotationCatalog(
      schemaVersion: _asInt(json['schema_version']),
      contentVersion: json['content_version']?.toString().trim() ?? '',
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      totalQuotations: _asInt(json['total_quotations']),
      totalCategories: _asInt(json['total_categories']),
      categories: rawCategories is List
          ? rawCategories
              .whereType<Map>()
              .map(
                (item) => OnlineQuotationCategory.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where(
                (item) =>
                    item.id.isNotEmpty &&
                    item.name.isNotEmpty &&
                    item.file.isNotEmpty,
              )
              .toList(growable: false)
          : const [],
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class QuotationOnlineException implements Exception {
  const QuotationOnlineException(this.message);

  final String message;

  @override
  String toString() => message;
}

class QuotationOnlineService {
  const QuotationOnlineService();

  static const String repositoryUrl =
      'https://github.com/mujtabax18/ai-quotations';

  static const String rawBaseUrl =
      'https://raw.githubusercontent.com/mujtabax18/ai-quotations/main/';

  static const Duration _timeout = Duration(seconds: 20);

  Future<OnlineQuotationCatalog> fetchCatalog() async {
    final decoded = await _getJson('${rawBaseUrl}catalog.json');
    if (decoded is! Map) {
      throw const QuotationOnlineException(
        'The online quotation catalog has an invalid format.',
      );
    }

    final catalog = OnlineQuotationCatalog.fromJson(
      Map<String, dynamic>.from(decoded),
    );

    if (catalog.categories.isEmpty) {
      throw const QuotationOnlineException(
        'No quotation categories are available online.',
      );
    }
    return catalog;
  }

  Future<List<Map<String, dynamic>>> fetchCategory(
    OnlineQuotationCategory category,
  ) async {
    final safeFile = category.file.trim();
    if (safeFile.isEmpty ||
        safeFile.startsWith('/') ||
        safeFile.contains('..') ||
        Uri.tryParse(safeFile)?.hasScheme == true) {
      throw const QuotationOnlineException(
        'The selected category has an invalid download path.',
      );
    }

    final decoded = await _getJson('$rawBaseUrl$safeFile');
    if (decoded is! List) {
      throw QuotationOnlineException(
        '${category.name} returned an invalid quotation file.',
      );
    }

    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => (item['text']?.toString().trim() ?? '').isNotEmpty)
        .toList(growable: false);
  }

  Future<dynamic> _getJson(String url) async {
    final uri = Uri.parse(url);
    final client = HttpClient()
      ..connectionTimeout = _timeout
      ..userAgent = 'DayArk-QuotationLibrary/1.0';

    try {
      final request = await client.getUrl(uri).timeout(_timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');

      final response = await request.close().timeout(_timeout);
      final body = await utf8.decoder.bind(response).join().timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw QuotationOnlineException(
          'Quotation server returned HTTP ${response.statusCode}.',
        );
      }

      try {
        return jsonDecode(body);
      } on FormatException {
        throw const QuotationOnlineException(
          'The quotation server returned invalid JSON.',
        );
      }
    } on TimeoutException {
      throw const QuotationOnlineException(
        'The quotation request timed out. Check your internet connection.',
      );
    } on SocketException {
      throw const QuotationOnlineException(
        'Unable to reach the quotation repository. Check your internet connection.',
      );
    } finally {
      client.close(force: true);
    }
  }
}
