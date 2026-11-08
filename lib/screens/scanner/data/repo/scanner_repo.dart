import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../../../services/db/drift_database.dart';

import '../../../../services/database_service.dart';
import '../../services/scan_storage_service.dart';
import '../models/scan_model.dart';

class ScannerService {
  ScannerService(
    this._databaseService, {
    ScanStorageService? storageService,
  }) : _storageService = storageService ?? ScanStorageService();

  final DatabaseService _databaseService;
  final ScanStorageService _storageService;

  Future<ScanEntry> importScan(
    File source, {
    required int groupId,
    String title = '',
  }) async {
    final asset = await _storageService.importOriginal(source, groupId: groupId);
    final now = DateTime.now().toIso8601String();
    final entry = ScanEntry(
      originalPath: asset.path,
      editedPath: asset.path,
      createdAt: now,
      updatedAt: now,
      groupId: groupId,
      title: title,
      fileSize: asset.fileSize,
      checksum: asset.checksum,
    );
    final id = await insertScan(entry);
    final saved = entry.copyWith(id: id);
    final db = await _databaseService.database;
    await db.insert('scan_edit_history', {
      'scan_id': id,
      'action': 'import',
      'version': 1,
      'source_path': source.path,
      'output_path': asset.path,
      'metadata_json': jsonEncode({
        'managed_copy': true,
        'file_size': asset.fileSize,
        'checksum': asset.checksum,
      }),
      'created_at': now,
    });
    return saved;
  }

  Future<List<ScanEntry>> importScans(
    Iterable<File> files, {
    required int groupId,
  }) async {
    final imported = <ScanEntry>[];
    for (final file in files) {
      imported.add(await importScan(file, groupId: groupId));
    }
    return imported;
  }

  Future<int> insertScan(ScanEntry entry) async {
    final db = await _databaseService.database;
    final result = await db.rawQuery(
      entry.groupId == null
          ? '''
              SELECT COALESCE(MAX(sort_id), -1) + 1 AS next_sort
              FROM scans
              WHERE group_id IS NULL
            '''
          : '''
              SELECT COALESCE(MAX(sort_id), -1) + 1 AS next_sort
              FROM scans
              WHERE group_id = ?
            ''',
      entry.groupId == null ? const [] : [entry.groupId],
    );
    final nextSortId = _asInt(result.first['next_sort']) ?? 0;
    final map = entry.copyWith(sortId: nextSortId).toMap()..remove('id');
    return db.insert('scans', map);
  }

  Future<List<ScanEntry>> fetchAllScans({int? groupId}) async {
    final db = await _databaseService.database;
    final data = await db.query(
      'scans',
      where: groupId != null ? 'group_id = ?' : null,
      whereArgs: groupId != null ? [groupId] : null,
      orderBy: groupId == null
          ? 'is_favorite DESC, updated_at DESC, created_at DESC'
          : 'sort_id ASC, id ASC',
    );
    return data.map(ScanEntry.fromMap).toList(growable: false);
  }

  Future<ScanEntry?> fetchScan(int id) async {
    final db = await _databaseService.database;
    final rows = await db.query(
      'scans',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : ScanEntry.fromMap(rows.first);
  }

  Future<ScanEntry> saveEditedVersion({
    required ScanEntry scan,
    required Uint8List bytes,
    String action = 'image_edit',
    Map<String, dynamic>? metadata,
  }) async {
    final scanId = scan.id;
    if (scanId == null) throw StateError('Scan must be saved before editing.');
    final nextVersion = scan.version + 1;
    final asset = await _storageService.saveEditedBytes(
      bytes: bytes,
      scanId: scanId,
      version: nextVersion,
    );
    final now = DateTime.now().toIso8601String();
    final db = await _databaseService.database;
    await db.transaction((txn) async {
      await txn.update(
        'scans',
        {
          'edited_path': asset.path,
          'file_size': asset.fileSize,
          'checksum': asset.checksum,
          'version': nextVersion,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [scanId],
      );
      await txn.insert('scan_edit_history', {
        'scan_id': scanId,
        'action': action,
        'version': nextVersion,
        'source_path': scan.currentPath,
        'output_path': asset.path,
        'metadata_json': metadata == null ? null : jsonEncode(metadata),
        'created_at': now,
      });
    });
    return scan.copyWith(
      editedPath: asset.path,
      fileSize: asset.fileSize,
      checksum: asset.checksum,
      version: nextVersion,
      updatedAt: now,
    );
  }

  Future<ScanEntry> resetToOriginal(ScanEntry scan) async {
    final id = scan.id;
    if (id == null) return scan;
    final now = DateTime.now().toIso8601String();
    final file = File(scan.originalPath);
    if (!await file.exists()) {
      throw FileSystemException(
        'The original scan image is missing.',
        scan.originalPath,
      );
    }
    final asset = await _storageService.describe(file);
    final db = await _databaseService.database;
    await db.transaction((txn) async {
      await txn.update(
        'scans',
        {
          'edited_path': scan.originalPath,
          'file_size': asset.fileSize,
          'checksum': asset.checksum,
          'version': scan.version + 1,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.insert('scan_edit_history', {
        'scan_id': id,
        'action': 'reset_to_original',
        'version': scan.version + 1,
        'source_path': scan.currentPath,
        'output_path': scan.originalPath,
        'created_at': now,
      });
    });
    return scan.copyWith(
      editedPath: scan.originalPath,
      fileSize: asset.fileSize,
      checksum: asset.checksum,
      version: scan.version + 1,
      updatedAt: now,
    );
  }

  Future<void> updateDetails(
    ScanEntry scan, {
    String? title,
    String? notes,
    String? ocrText,
  }) async {
    if (scan.id == null) return;
    final db = await _databaseService.database;
    await db.update(
      'scans',
      {
        if (title != null) 'title': title.trim(),
        if (notes != null) 'notes': notes.trim(),
        if (ocrText != null) 'ocr_text': ocrText.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [scan.id],
    );
  }

  Future<void> toggleFavorite(ScanEntry scan) async {
    if (scan.id == null) return;
    final db = await _databaseService.database;
    await db.update(
      'scans',
      {
        'is_favorite': scan.isFavorite ? 0 : 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [scan.id],
    );
  }

  Future<int> deleteScan(int id) async {
    final scan = await fetchScan(id);
    final db = await _databaseService.database;
    final history = await db.query(
      'scan_edit_history',
      columns: ['source_path', 'output_path'],
      where: 'scan_id = ?',
      whereArgs: [id],
    );
    final deleted = await db.transaction((txn) async {
      await txn.delete('scan_edit_history', where: 'scan_id = ?', whereArgs: [id]);
      return txn.delete('scans', where: 'id = ?', whereArgs: [id]);
    });
    final paths = <String>{
      if (scan != null) scan.originalPath,
      if (scan != null) scan.editedPath,
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
    return deleted;
  }

  Future<ScanEntry> duplicateScan(ScanEntry scan) async {
    final source = File(scan.currentPath);
    if (!await source.exists()) {
      throw FileSystemException('The scan image is missing.', scan.currentPath);
    }
    final groupId = scan.groupId;
    if (groupId == null) {
      throw StateError('The scan is not assigned to a document group.');
    }
    return importScan(
      source,
      groupId: groupId,
      title: scan.title.isEmpty ? '' : '${scan.title} copy',
    );
  }

  Future<void> clearScans() async {
    final scans = await fetchAllScans();
    for (final scan in scans) {
      if (scan.id != null) await deleteScan(scan.id!);
    }
  }

  Future<void> updateScanOrder(
    int groupId,
    List<ScanEntry> orderedScans,
  ) async {
    final db = await _databaseService.database;
    await db.transaction((txn) async {
      for (var index = 0; index < orderedScans.length; index++) {
        final id = orderedScans[index].id;
        if (id == null) continue;
        await txn.update(
          'scans',
          {
            'sort_id': index,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ? AND group_id = ?',
          whereArgs: [id, groupId],
        );
      }
    });
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
