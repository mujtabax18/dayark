part of '../quotation_service.dart';

class QuotationImportResult {
  const QuotationImportResult({
    this.inserted = 0,
    this.updated = 0,
    this.skipped = 0,
  });

  final int inserted;
  final int updated;
  final int skipped;

  int get processed => inserted + updated + skipped;

  QuotationImportResult operator +(QuotationImportResult other) {
    return QuotationImportResult(
      inserted: inserted + other.inserted,
      updated: updated + other.updated,
      skipped: skipped + other.skipped,
    );
  }
}

class QuotationLibraryStats {
  const QuotationLibraryStats({
    required this.total,
    required this.favorites,
    required this.used,
    required this.online,
    required this.categories,
    required this.totalUses,
  });

  final int total;
  final int favorites;
  final int used;
  final int online;
  final int categories;
  final int totalUses;
}

class DuplicateQuotationException implements Exception {
  const DuplicateQuotationException();

  @override
  String toString() => 'This quotation already exists in your library.';
}

