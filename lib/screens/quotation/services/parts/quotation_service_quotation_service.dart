part of '../quotation_service.dart';

class QuotationService {
  QuotationService(this._databaseService);

  final DatabaseService _databaseService;

  Future<List<Quotation>> getAll({
    String search = '',
    String? category,
    bool favoritesOnly = false,
    bool onlineOnly = false,
    QuotationSort sort = QuotationSort.newest,
  }) async {
    final db = await _databaseService.database;
    final where = <String>[];
    final args = <Object?>[];

    final query = search.trim();
    if (query.isNotEmpty) {
      where.add('(text LIKE ? OR author LIKE ? OR category LIKE ?)');
      final pattern = '%$query%';
      args.addAll([pattern, pattern, pattern]);
    }

    final selectedCategory = category?.trim() ?? '';
    if (selectedCategory.isNotEmpty && selectedCategory != 'All') {
      where.add('category = ?');
      args.add(selectedCategory);
    }

    if (favoritesOnly) {
      where.add('is_favorite = 1');
    }

    if (onlineOnly) {
      where.add("remote_uid IS NOT NULL AND TRIM(remote_uid) != ''");
    }

    final rows = await db.query(
      'quotations',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: _orderBy(sort),
    );
    return rows.map(Quotation.fromMap).toList(growable: false);
  }

  String _orderBy(QuotationSort sort) {
    switch (sort) {
      case QuotationSort.mostUsed:
        return 'usage_count DESC, is_favorite DESC, updated_at DESC, id DESC';
      case QuotationSort.alphabetical:
        return 'text COLLATE NOCASE ASC, id DESC';
      case QuotationSort.newest:
        return 'is_favorite DESC, updated_at DESC, created_at DESC, id DESC';
    }
  }

  Future<List<String>> getCategories() async {
    final db = await _databaseService.database;
    final rows = await db.rawQuery('''
SELECT DISTINCT category
FROM quotations
WHERE category IS NOT NULL AND TRIM(category) != ''
ORDER BY category COLLATE NOCASE
''');
    return rows
        .map((row) => row['category']?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  Future<int> save(Quotation quote) async {
    final db = await _databaseService.database;
    final now = DateTime.now();
    final normalized = quote.copyWith(
      category: quote.category.trim().isEmpty ? 'General' : quote.category.trim(),
      updatedAt: now,
    );

    final duplicateId = await _findContentDuplicate(
      db,
      text: normalized.text,
      author: normalized.author,
      category: normalized.category,
      excludingId: normalized.id,
    );
    if (duplicateId != null) {
      throw const DuplicateQuotationException();
    }

    if (normalized.id == null) {
      final values = normalized.copyWith(createdAt: now).toMap()..remove('id');
      return db.insert(
        'quotations',
        values,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }

    final values = normalized.toMap()..remove('id');
    await db.update(
      'quotations',
      values,
      where: 'id = ?',
      whereArgs: [normalized.id],
    );
    return normalized.id!;
  }

  /// Keeps the original API used by the prompt builder, but now silently
  /// de-duplicates repeated generated/imported quotations.
  Future<void> saveMany(List<Quotation> quotes) async {
    await importMany(quotes);
  }

  Future<QuotationImportResult> importMany(List<Quotation> quotes) async {
    if (quotes.isEmpty) return const QuotationImportResult();
    final db = await _databaseService.database;
    final now = DateTime.now();

    var inserted = 0;
    var skipped = 0;

    await db.transaction((txn) async {
      for (final quote in quotes) {
        final category =
            quote.category.trim().isEmpty ? 'General' : quote.category.trim();

        final duplicateId = await _findContentDuplicate(
          txn,
          text: quote.text,
          author: quote.author,
          category: category,
        );
        if (duplicateId != null) {
          skipped++;
          continue;
        }

        final values = quote
            .copyWith(
              createdAt: quote.createdAt,
              updatedAt: now,
              category: category,
            )
            .toMap()
          ..remove('id');

        await txn.insert(
          'quotations',
          values,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        inserted++;
      }
    });

    return QuotationImportResult(inserted: inserted, skipped: skipped);
  }

  Future<QuotationImportResult> importOnlineCategory({
    required String categoryId,
    required String categoryName,
    required String catalogVersion,
    required List<Map<String, dynamic>> quotations,
  }) async {
    if (quotations.isEmpty) return const QuotationImportResult();

    final db = await _databaseService.database;
    final now = DateTime.now().toIso8601String();

    var inserted = 0;
    var updated = 0;
    var skipped = 0;

    await db.transaction((txn) async {
      for (final raw in quotations) {
        final text = raw['text']?.toString().trim() ?? '';
        if (text.isEmpty) {
          skipped++;
          continue;
        }

        final remoteUid = raw['uid']?.toString().trim() ?? '';
        final author = raw['author']?.toString().trim() ?? '';
        final rawCategory = raw['category']?.toString().trim() ?? '';
        final category = rawCategory.isEmpty ? categoryName : rawCategory;

        Map<String, Object?>? existing;

        if (remoteUid.isNotEmpty) {
          final byUid = await txn.query(
            'quotations',
            columns: [
              'id',
              'text',
              'author',
              'category',
              'is_favorite',
              'is_used',
              'usage_count',
              'remote_uid',
            ],
            where: 'remote_uid = ?',
            whereArgs: [remoteUid],
            limit: 1,
          );
          if (byUid.isNotEmpty) existing = byUid.first;
        }

        existing ??= await _findContentDuplicateRow(
          txn,
          text: text,
          author: author,
          category: category,
        );

        final values = <String, Object?>{
          'text': text,
          'author': author,
          'category': category.isEmpty ? 'General' : category,
          'remote_uid': remoteUid.isEmpty ? null : remoteUid,
          'remote_category_id': categoryId,
          'remote_catalog_version': catalogVersion,
          'remote_updated_at': raw['updated_at']?.toString(),
          'imported_at': now,
          'updated_at': now,
        };

        if (existing != null) {
          final existingId = existing['id'] as int;

          // Preserve local user state. If this exact content already existed
          // locally, attach its remote identity instead of inserting a copy.
          final changed =
              existing['text']?.toString() != text ||
              existing['author']?.toString() != author ||
              existing['category']?.toString() != category ||
              (remoteUid.isNotEmpty &&
                  existing['remote_uid']?.toString() != remoteUid);

          await txn.update(
            'quotations',
            values,
            where: 'id = ?',
            whereArgs: [existingId],
          );

          if (changed) {
            updated++;
          } else {
            skipped++;
          }
          continue;
        }

        final rawCreatedAt = raw['created_at']?.toString().trim() ?? '';
        values.addAll({
          'source': 'online',
          'background_style':
              _nonEmpty(raw['background_style'], fallback: 'sunrise'),
          'text_align': _nonEmpty(raw['text_align'], fallback: 'center'),
          'font_size': _asDouble(raw['font_size'], fallback: 30),
          'show_author': _asBoolInt(raw['show_author'], fallback: 1),
          'is_favorite': 0,
          'is_used': 0,
          'usage_count': 0,
          'created_at': rawCreatedAt.isNotEmpty ? rawCreatedAt : now,
        });

        await txn.insert(
          'quotations',
          values,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        inserted++;
      }
    });

    return QuotationImportResult(
      inserted: inserted,
      updated: updated,
      skipped: skipped,
    );
  }

  Future<Map<String, int>> getOnlineCategoryCounts() async {
    final db = await _databaseService.database;
    final rows = await db.rawQuery('''
SELECT remote_category_id, COUNT(*) AS total
FROM quotations
WHERE remote_uid IS NOT NULL
  AND TRIM(remote_uid) != ''
  AND remote_category_id IS NOT NULL
  AND TRIM(remote_category_id) != ''
GROUP BY remote_category_id
''');

    return {
      for (final row in rows)
        if ((row['remote_category_id']?.toString().trim() ?? '').isNotEmpty)
          row['remote_category_id']!.toString():
              (row['total'] as num?)?.toInt() ?? 0,
    };
  }

  Future<QuotationLibraryStats> getLibraryStats() async {
    final db = await _databaseService.database;
    final rows = await db.rawQuery('''
SELECT
  COUNT(*) AS total,
  SUM(CASE WHEN is_favorite = 1 THEN 1 ELSE 0 END) AS favorites,
  SUM(CASE WHEN is_used = 1 THEN 1 ELSE 0 END) AS used,
  SUM(CASE WHEN remote_uid IS NOT NULL AND TRIM(remote_uid) != '' THEN 1 ELSE 0 END) AS online,
  COUNT(DISTINCT category) AS categories,
  COALESCE(SUM(usage_count), 0) AS total_uses
FROM quotations
''');
    final row = rows.isEmpty ? const <String, Object?>{} : rows.first;

    int value(String key) => (row[key] as num?)?.toInt() ?? 0;

    return QuotationLibraryStats(
      total: value('total'),
      favorites: value('favorites'),
      used: value('used'),
      online: value('online'),
      categories: value('categories'),
      totalUses: value('total_uses'),
    );
  }

  Future<int> removeOnlineCategory(String categoryId) async {
    final db = await _databaseService.database;
    return db.transaction((txn) async {
      final removed = await txn.delete(
        'quotations',
        where: "remote_category_id = ? AND source = 'online'",
        whereArgs: [categoryId],
      );

      // A local/manual quotation may have matched an online quotation during
      // import. Keep that local row and only detach its remote sync metadata.
      await txn.update(
        'quotations',
        {
          'remote_uid': null,
          'remote_category_id': null,
          'remote_catalog_version': null,
          'remote_updated_at': null,
          'imported_at': null,
        },
        where: "remote_category_id = ? AND source != 'online'",
        whereArgs: [categoryId],
      );

      return removed;
    });
  }

  Future<int> removeAllOnline() async {
    final db = await _databaseService.database;
    return db.transaction((txn) async {
      final removed = await txn.delete(
        'quotations',
        where: "source = 'online'",
      );

      await txn.update(
        'quotations',
        {
          'remote_uid': null,
          'remote_category_id': null,
          'remote_catalog_version': null,
          'remote_updated_at': null,
          'imported_at': null,
        },
        where: "remote_uid IS NOT NULL AND source != 'online'",
      );

      return removed;
    });
  }

  Future<int> deleteCategory(String category) async {
    final value = category.trim();
    if (value.isEmpty || value == 'All') return 0;
    final db = await _databaseService.database;
    return db.delete(
      'quotations',
      where: 'category = ?',
      whereArgs: [value],
    );
  }

  Future<void> resetUsageHistory() async {
    final db = await _databaseService.database;
    await db.update(
      'quotations',
      {
        'is_used': 0,
        'usage_count': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> delete(int id) async {
    final db = await _databaseService.database;
    await db.delete('quotations', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> toggleFavorite(Quotation quote) async {
    if (quote.id == null) return;
    final db = await _databaseService.database;
    await db.update(
      'quotations',
      {
        'is_favorite': quote.isFavorite ? 0 : 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [quote.id],
    );
  }

  Future<void> registerUse(Quotation quote) async {
    if (quote.id == null) return;
    final db = await _databaseService.database;
    await db.update(
      'quotations',
      {
        'is_used': 1,
        'usage_count': quote.usageCount + 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [quote.id],
    );
  }

  Future<Quotation?> getRandom({String? category, bool onlineOnly = false}) async {
    final db = await _databaseService.database;
    final selected = category?.trim() ?? '';
    final where = <String>[];
    final args = <Object?>[];

    if (selected.isNotEmpty && selected != 'All') {
      where.add('category = ?');
      args.add(selected);
    }
    if (onlineOnly) {
      where.add("remote_uid IS NOT NULL AND TRIM(remote_uid) != ''");
    }

    final rows = await db.query(
      'quotations',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'RANDOM()',
      limit: 1,
    );
    return rows.isEmpty ? null : Quotation.fromMap(rows.first);
  }

  Future<int?> _findContentDuplicate(
    DatabaseExecutor db, {
    required String text,
    required String author,
    required String category,
    int? excludingId,
  }) async {
    final row = await _findContentDuplicateRow(
      db,
      text: text,
      author: author,
      category: category,
      excludingId: excludingId,
    );
    return row?['id'] as int?;
  }

  Future<Map<String, Object?>?> _findContentDuplicateRow(
    DatabaseExecutor db, {
    required String text,
    required String author,
    required String category,
    int? excludingId,
  }) async {
    final where = StringBuffer('''
LOWER(TRIM(text)) = LOWER(TRIM(?))
AND LOWER(TRIM(COALESCE(author, ''))) = LOWER(TRIM(?))
AND LOWER(TRIM(category)) = LOWER(TRIM(?))
''');
    final args = <Object?>[text, author, category];

    if (excludingId != null) {
      where.write(' AND id != ?');
      args.add(excludingId);
    }

    final rows = await db.query(
      'quotations',
      where: where.toString(),
      whereArgs: args,
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  String _nonEmpty(Object? value, {required String fallback}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  double _asDouble(Object? value, {required double fallback}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int _asBoolInt(Object? value, {required int fallback}) {
    if (value == true || value == 1 || value?.toString() == '1') return 1;
    if (value == false || value == 0 || value?.toString() == '0') return 0;
    return fallback;
  }
}
