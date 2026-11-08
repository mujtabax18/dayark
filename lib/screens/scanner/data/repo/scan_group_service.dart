import '../../../../services/db/drift_database.dart';

import '../../../../services/database_service.dart';
import '../../services/scan_storage_service.dart';
import '../models/ScanGroupPreview.dart';
import '../models/scan_group_model.dart';
import '../models/scan_model.dart';

class ScanGroupService {
  ScanGroupService(
    this._databaseService, {
    ScanStorageService? storageService,
  }) : _storageService = storageService ?? ScanStorageService();

  final DatabaseService _databaseService;
  final ScanStorageService _storageService;

  Future<int> createGroup(ScanGroup group) async {
    final db = await _databaseService.database;
    final map = group.toMap()..remove('id');
    return db.insert('scan_groups', map);
  }

  Future<List<ScanGroup>> fetchAllGroups() async {
    final db = await _databaseService.database;
    final data = await db.query(
      'scan_groups',
      orderBy: 'is_favorite DESC, updated_at DESC, created_at DESC',
    );
    return data.map(ScanGroup.fromMap).toList(growable: false);
  }

  Future<ScanGroup?> fetchGroup(int id) async {
    final db = await _databaseService.database;
    final rows = await db.query(
      'scan_groups',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : ScanGroup.fromMap(rows.first);
  }

  Future<int> updateGroup(ScanGroup group) async {
    if (group.id == null) return 0;
    final db = await _databaseService.database;
    final map = group
        .copyWith(updatedAt: DateTime.now().toIso8601String())
        .toMap()
      ..remove('id');
    return db.update(
      'scan_groups',
      map,
      where: 'id = ?',
      whereArgs: [group.id],
    );
  }

  Future<void> toggleFavorite(int groupId) async {
    final group = await fetchGroup(groupId);
    if (group == null) return;
    await updateGroup(group.copyWith(isFavorite: !group.isFavorite));
  }

  /// Backward-compatible delete API. Scanner groups now own their managed
  /// page assets, so deleting a group must remove its pages and edit history.
  Future<int> deleteGroup(int id) async {
    final group = await fetchGroup(id);
    if (group == null) return 0;
    await deleteGroupWithScans(id);
    return 1;
  }

  Future<List<ScanGroupPreview>> fetchGroupPreviews({
    String search = '',
    bool favoritesOnly = false,
    String sort = 'updated',
  }) async {
    final db = await _databaseService.database;
    final where = <String>[];
    final args = <Object?>[];
    if (search.trim().isNotEmpty) {
      where.add('''
        (
          g.title LIKE ? OR
          g.tags LIKE ? OR
          EXISTS (
            SELECT 1
            FROM scans search_scan
            WHERE search_scan.group_id = g.id
              AND (
                search_scan.title LIKE ? OR
                search_scan.notes LIKE ? OR
                search_scan.ocr_text LIKE ?
              )
          )
        )
      ''');
      final value = '%${search.trim()}%';
      args.addAll([value, value, value, value, value]);
    }
    if (favoritesOnly) where.add('g.is_favorite = 1');
    final orderBy = switch (sort) {
      'name' => 'g.title COLLATE NOCASE ASC',
      'pages' => 'page_count DESC, g.updated_at DESC',
      'oldest' => 'g.created_at ASC',
      _ => 'g.is_favorite DESC, g.updated_at DESC, g.created_at DESC',
    };
    final result = await db.rawQuery('''
      SELECT
        g.id,
        g.title,
        g.created_at,
        g.updated_at,
        g.is_favorite,
        g.tags,
        COUNT(s.id) AS page_count,
        COALESCE(SUM(s.file_size), 0) AS total_bytes,
        (
          SELECT COALESCE(NULLIF(s2.edited_path, ''), s2.original_path)
          FROM scans s2
          WHERE s2.group_id = g.id
          ORDER BY s2.sort_id ASC, s2.id ASC
          LIMIT 1
        ) AS thumbnail
      FROM scan_groups g
      LEFT JOIN scans s ON s.group_id = g.id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      GROUP BY g.id
      HAVING COUNT(s.id) > 0
      ORDER BY $orderBy
    ''', args);

    return result.map((row) {
      return ScanGroupPreview(
        id: _asInt(row['id']),
        title: row['title']?.toString() ?? 'Scanned document',
        thumbnailPath: row['thumbnail']?.toString() ?? '',
        pageCount: _asInt(row['page_count']),
        totalBytes: _asInt(row['total_bytes']),
        isFavorite: _asBool(row['is_favorite']),
        createdAt: row['created_at']?.toString() ?? '',
        updatedAt: row['updated_at']?.toString() ?? '',
        tags: row['tags']?.toString() ?? '',
      );
    }).toList(growable: false);
  }

  Future<void> deleteGroupWithScans(int groupId) async {
    final db = await _databaseService.database;
    final scanRows = await db.query(
      'scans',
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    final scans = scanRows.map(ScanEntry.fromMap).toList(growable: false);
    final scanIds = scans.map((scan) => scan.id).whereType<int>().toList();
    final history = scanIds.isEmpty
        ? const <Map<String, Object?>>[]
        : await db.query(
            'scan_edit_history',
            columns: ['source_path', 'output_path'],
            where: 'scan_id IN (${List.filled(scanIds.length, '?').join(',')})',
            whereArgs: scanIds,
          );
    await db.transaction((txn) async {
      if (scanIds.isNotEmpty) {
        await txn.delete(
          'scan_edit_history',
          where: 'scan_id IN (${List.filled(scanIds.length, '?').join(',')})',
          whereArgs: scanIds,
        );
      }
      await txn.delete('scans', where: 'group_id = ?', whereArgs: [groupId]);
      await txn.delete('scan_groups', where: 'id = ?', whereArgs: [groupId]);
    });
    final paths = <String>{
      ...scans.expand((scan) => [scan.originalPath, scan.editedPath]),
      ...history.expand(
        (row) => [
          row['source_path']?.toString() ?? '',
          row['output_path']?.toString() ?? '',
        ],
      ),
    };
    for (final path in paths) {
      await _storageService.deleteIfManaged(path);
    }
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value?.toString().toLowerCase() == 'true';
  }
}
