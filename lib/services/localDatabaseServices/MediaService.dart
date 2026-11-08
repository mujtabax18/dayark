import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import '../db/drift_database.dart';

import '../../models/MediaCollection.dart';
import '../../models/MediaEditHistory.dart';
import '../../models/MediaFile.dart';
import '../database_service.dart';
import '../media/MediaStorageService.dart';

class MediaLibraryStats {
  const MediaLibraryStats({
    required this.total,
    required this.images,
    required this.videos,
    required this.audio,
    required this.pdfs,
    required this.favorites,
    required this.totalBytes,
  });

  final int total;
  final int images;
  final int videos;
  final int audio;
  final int pdfs;
  final int favorites;
  final int totalBytes;
}

class MediaService {
  MediaService(
    this._databaseService, {
    MediaStorageService? storageService,
  }) : _storageService = storageService ?? MediaStorageService();

  final DatabaseService _databaseService;
  final MediaStorageService _storageService;

  Future<int> addMedia(MediaFile media) async {
    // Older callers may still pass a picker/cache path directly. Copy it into
    // app-owned storage first so it survives cache cleanup and is always part
    // of portable backups.
    var storedMedia = media;
    if (!await _storageService.isManagedPath(media.originalPath)) {
      final source = File(media.originalPath);
      if (!await source.exists()) {
        throw FileSystemException(
          'The selected media file is missing.',
          media.originalPath,
        );
      }
      final asset = await _storageService.importOriginal(
        source,
        preferredName: media.title,
      );
      storedMedia = media.copyWith(
        filePath: asset.path,
        originalPath: asset.path,
        clearEditedPath: true,
        mediaType: asset.mediaType,
        mimeType: asset.mimeType,
        extension: asset.extension,
        fileSize: asset.fileSize,
        checksum: asset.checksum,
        version: 1,
        updatedAt: DateTime.now().toIso8601String(),
      );
    }

    final db = await _databaseService.database;
    final map = storedMedia.toMap()..remove('id');
    final id = await db.insert('media_files', map);
    await _insertHistory(
      db,
      MediaEditHistory(
        mediaId: id,
        action: 'imported',
        version: storedMedia.version,
        sourcePath: storedMedia.originalPath,
        outputPath: storedMedia.filePath,
        metadataJson: jsonEncode({'media_type': storedMedia.mediaType}),
        createdAt: storedMedia.createdAt,
      ),
    );
    return id;
  }

  Future<MediaFile> importFile(
    File source, {
    String? preferredName,
  }) async {
    final asset = await _storageService.importOriginal(
      source,
      preferredName: preferredName,
    );
    final now = DateTime.now().toIso8601String();
    final media = MediaFile(
      filePath: asset.path,
      originalPath: asset.path,
      mediaType: asset.mediaType,
      title: p.basenameWithoutExtension(asset.fileName),
      mimeType: asset.mimeType,
      extension: asset.extension,
      fileSize: asset.fileSize,
      checksum: asset.checksum,
      createdAt: now,
      updatedAt: now,
    );
    final id = await addMedia(media);
    return media.copyWith(id: id);
  }

  Future<List<MediaFile>> importFiles(Iterable<File> files) async {
    final imported = <MediaFile>[];
    for (final file in files) {
      imported.add(await importFile(file));
    }
    return imported;
  }

  Future<MediaFile?> getMediaById(int id) async {
    final db = await _databaseService.database;
    final rows = await db.query('media_files',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _repairLegacyMedia(db, MediaFile.fromMap(rows.first));
  }

  Future<List<MediaFile>> getAllMedia({
    bool includeDeleted = false,
    String? mediaType,
    String search = '',
    bool favoritesOnly = false,
    int? collectionId,
  }) async {
    final db = await _databaseService.database;
    final where = <String>[];
    final args = <Object?>[];

    if (!includeDeleted) where.add('is_deleted = 0');
    if (mediaType != null && mediaType != 'all') {
      where.add('media_type = ?');
      args.add(mediaType);
    }
    if (favoritesOnly) where.add('is_favorite = 1');
    if (collectionId != null) {
      where.add('EXISTS (SELECT 1 FROM media_collection_items mci '
          'WHERE mci.media_id = media_files.id AND mci.collection_id = ?)');
      args.add(collectionId);
    }
    if (search.trim().isNotEmpty) {
      where.add('(title LIKE ? OR extension LIKE ? OR media_type LIKE ?)');
      final value = '%${search.trim()}%';
      args.addAll([value, value, value]);
    }

    final rows = await db.query(
      'media_files',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: collectionId == null
          ? 'is_favorite DESC, updated_at DESC, id DESC'
          : '(SELECT mci.sort_order FROM media_collection_items mci '
              'WHERE mci.media_id = media_files.id '
              'AND mci.collection_id = $collectionId) ASC, '
              'is_favorite DESC, updated_at DESC, id DESC',
    );

    final result = <MediaFile>[];
    for (final row in rows) {
      final repaired = await _repairLegacyMedia(db, MediaFile.fromMap(row));
      if (repaired != null) result.add(repaired);
    }
    return result;
  }

  Future<List<MediaCollection>> getCollections() async {
    final db = await _databaseService.database;
    final rows = await db.rawQuery('''
      SELECT c.*,
        COUNT(CASE WHEN mf.is_deleted = 0 THEN 1 END) AS item_count
      FROM media_collections c
      LEFT JOIN media_collection_items mci ON mci.collection_id = c.id
      LEFT JOIN media_files mf ON mf.id = mci.media_id
      GROUP BY c.id
      ORDER BY c.sort_order ASC, c.name COLLATE NOCASE ASC, c.id ASC
    ''');
    return rows.map(MediaCollection.fromMap).toList(growable: false);
  }

  Future<List<MediaFile>> getCollectionPreview(
    int collectionId, {
    int limit = 4,
  }) async {
    final db = await _databaseService.database;
    final safeLimit = limit.clamp(1, 12).toInt();
    final rows = await db.rawQuery(
      '''
      SELECT mf.*
      FROM media_collection_items mci
      INNER JOIN media_files mf ON mf.id = mci.media_id
      WHERE mci.collection_id = ? AND mf.is_deleted = 0
      ORDER BY mci.sort_order ASC, mf.updated_at DESC, mf.id DESC
      LIMIT ?
      ''',
      [collectionId, safeLimit],
    );

    final result = <MediaFile>[];
    for (final row in rows) {
      final repaired = await _repairLegacyMedia(db, MediaFile.fromMap(row));
      if (repaired != null) result.add(repaired);
    }
    return result;
  }

  Future<List<MediaFile>> getLibraryPreview({int limit = 4}) async {
    final db = await _databaseService.database;
    final safeLimit = limit.clamp(1, 12).toInt();
    final rows = await db.query(
      'media_files',
      where: 'is_deleted = 0',
      orderBy: 'is_favorite DESC, updated_at DESC, id DESC',
      limit: safeLimit,
    );

    final result = <MediaFile>[];
    for (final row in rows) {
      final repaired = await _repairLegacyMedia(db, MediaFile.fromMap(row));
      if (repaired != null) result.add(repaired);
    }
    return result;
  }

  Future<int> createCollection(String name) async {
    final cleaned = name.trim();
    if (cleaned.isEmpty) {
      throw ArgumentError('Collection name cannot be empty.');
    }
    final db = await _databaseService.database;
    final maxRows = await db.rawQuery(
      'SELECT COALESCE(MAX(sort_order), -1) AS max_order FROM media_collections',
    );
    final nextOrder = _int(maxRows.first['max_order']) + 1;
    final now = DateTime.now().toIso8601String();
    return db.insert(
      'media_collections',
      {
        'name': cleaned,
        'sort_order': nextOrder,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> renameCollection(int id, String name) async {
    final cleaned = name.trim();
    if (cleaned.isEmpty) {
      throw ArgumentError('Collection name cannot be empty.');
    }
    final db = await _databaseService.database;
    await db.update(
      'media_collections',
      {'name': cleaned, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> deleteCollection(int id) async {
    final db = await _databaseService.database;
    await db.transaction((txn) async {
      await txn.delete(
        'media_collection_items',
        where: 'collection_id = ?',
        whereArgs: [id],
      );
      await txn.delete('media_collections', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<Set<int>> getCollectionIdsForMedia(int mediaId) async {
    final db = await _databaseService.database;
    final rows = await db.query(
      'media_collection_items',
      columns: const ['collection_id'],
      where: 'media_id = ?',
      whereArgs: [mediaId],
    );
    return rows
        .map((row) => _int(row['collection_id']))
        .where((id) => id > 0)
        .toSet();
  }

  Future<void> setMediaInCollection({
    required int mediaId,
    required int collectionId,
    required bool included,
  }) async {
    final db = await _databaseService.database;
    if (!included) {
      await db.delete(
        'media_collection_items',
        where: 'media_id = ? AND collection_id = ?',
        whereArgs: [mediaId, collectionId],
      );
      return;
    }

    final maxRows = await db.rawQuery(
      'SELECT COALESCE(MAX(sort_order), -1) AS max_order '
      'FROM media_collection_items WHERE collection_id = ?',
      [collectionId],
    );
    final nextOrder = _int(maxRows.first['max_order']) + 1;
    await db.insert(
      'media_collection_items',
      {
        'collection_id': collectionId,
        'media_id': mediaId,
        'sort_order': nextOrder,
        'added_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeMediaFromAllCollections(int mediaId) async {
    final db = await _databaseService.database;
    await db.delete(
      'media_collection_items',
      where: 'media_id = ?',
      whereArgs: [mediaId],
    );
  }

  Future<MediaFile> saveEditedVersion({
    required MediaFile media,
    required Uint8List bytes,
    String action = 'image_edit',
    Map<String, dynamic>? metadata,
  }) async {
    final mediaId = media.id;
    if (mediaId == null)
      throw StateError('Media must be saved before editing.');

    final nextVersion = media.version + 1;
    final asset = await _storageService.saveEditedBytes(
      bytes: bytes,
      mediaId: mediaId,
      version: nextVersion,
      extension: 'jpg',
    );
    final now = DateTime.now().toIso8601String();
    final db = await _databaseService.database;

    await db.transaction((txn) async {
      await txn.update(
        'media_files',
        {
          'file_path': asset.path,
          'edited_path': asset.path,
          'mime_type': asset.mimeType,
          'extension': asset.extension,
          'file_size': asset.fileSize,
          'checksum': asset.checksum,
          'version': nextVersion,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [mediaId],
      );
      await _insertHistory(
        txn,
        MediaEditHistory(
          mediaId: mediaId,
          action: action,
          version: nextVersion,
          sourcePath: media.currentPath,
          outputPath: asset.path,
          metadataJson: metadata == null ? null : jsonEncode(metadata),
          createdAt: now,
        ),
      );
    });

    return media.copyWith(
      filePath: asset.path,
      editedPath: asset.path,
      mimeType: asset.mimeType,
      extension: asset.extension,
      fileSize: asset.fileSize,
      checksum: asset.checksum,
      version: nextVersion,
      updatedAt: now,
    );
  }

  /// Stores a rendered video, edited PDF, or any other non-image revision in
  /// app-owned media storage while preserving version history.
  Future<MediaFile> saveEditedFileVersion({
    required MediaFile media,
    required File outputFile,
    required String action,
    Map<String, dynamic>? metadata,
  }) async {
    final mediaId = media.id;
    if (mediaId == null)
      throw StateError('Media must be saved before editing.');
    if (!await outputFile.exists()) {
      throw FileSystemException(
          'The edited output is missing.', outputFile.path);
    }

    final nextVersion = media.version + 1;
    final asset = await _storageService.copyVersion(
      source: outputFile,
      mediaId: mediaId,
      version: nextVersion,
    );
    final now = DateTime.now().toIso8601String();
    final db = await _databaseService.database;

    await db.transaction((txn) async {
      await txn.update(
        'media_files',
        {
          'file_path': asset.path,
          'edited_path': asset.path,
          'media_type': asset.mediaType,
          'mime_type': asset.mimeType,
          'extension': asset.extension,
          'file_size': asset.fileSize,
          'checksum': asset.checksum,
          'version': nextVersion,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [mediaId],
      );
      await _insertHistory(
        txn,
        MediaEditHistory(
          mediaId: mediaId,
          action: action,
          version: nextVersion,
          sourcePath: media.currentPath,
          outputPath: asset.path,
          metadataJson: metadata == null ? null : jsonEncode(metadata),
          createdAt: now,
        ),
      );
    });

    return media.copyWith(
      filePath: asset.path,
      editedPath: asset.path,
      mediaType: asset.mediaType,
      mimeType: asset.mimeType,
      extension: asset.extension,
      fileSize: asset.fileSize,
      checksum: asset.checksum,
      version: nextVersion,
      updatedAt: now,
    );
  }

  Future<MediaFile> restoreVersion(
    MediaFile media,
    MediaEditHistory history,
  ) async {
    final source = File(history.outputPath);
    if (!await source.exists()) {
      throw FileSystemException(
          'That history version is missing.', history.outputPath);
    }
    final id = media.id;
    if (id == null) throw StateError('Media has no database id.');

    final nextVersion = media.version + 1;
    final asset = await _storageService.copyVersion(
      source: source,
      mediaId: id,
      version: nextVersion,
    );
    final now = DateTime.now().toIso8601String();
    final db = await _databaseService.database;
    await db.transaction((txn) async {
      await txn.update(
        'media_files',
        {
          'file_path': asset.path,
          'edited_path': asset.path,
          'mime_type': asset.mimeType,
          'extension': asset.extension,
          'file_size': asset.fileSize,
          'checksum': asset.checksum,
          'version': nextVersion,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await _insertHistory(
        txn,
        MediaEditHistory(
          mediaId: id,
          action: 'restore_version',
          version: nextVersion,
          sourcePath: history.outputPath,
          outputPath: asset.path,
          metadataJson: jsonEncode({'restored_from_version': history.version}),
          createdAt: now,
        ),
      );
    });

    return media.copyWith(
      filePath: asset.path,
      editedPath: asset.path,
      mimeType: asset.mimeType,
      extension: asset.extension,
      fileSize: asset.fileSize,
      checksum: asset.checksum,
      version: nextVersion,
      updatedAt: now,
    );
  }

  Future<void> renameMedia(int id, String title) async {
    final cleaned = title.trim();
    if (cleaned.isEmpty) return;
    final db = await _databaseService.database;
    await db.update(
      'media_files',
      {'title': cleaned, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> toggleFavorite(MediaFile media) async {
    if (media.id == null) return;
    final db = await _databaseService.database;
    await db.update(
      'media_files',
      {
        'is_favorite': media.isFavorite ? 0 : 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [media.id],
    );
  }

  Future<void> moveToTrash(MediaFile media) async {
    if (media.id == null) return;
    final now = DateTime.now().toIso8601String();
    final db = await _databaseService.database;
    await db.transaction((txn) async {
      await txn.update(
        'media_files',
        {'is_deleted': 1, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [media.id],
      );
      await _insertHistory(
        txn,
        MediaEditHistory(
          mediaId: media.id!,
          action: 'moved_to_trash',
          version: media.version,
          sourcePath: media.currentPath,
          outputPath: media.currentPath,
          createdAt: now,
        ),
      );
    });
  }

  Future<void> restoreFromTrash(MediaFile media) async {
    if (media.id == null) return;
    final db = await _databaseService.database;
    await db.update(
      'media_files',
      {'is_deleted': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [media.id],
    );
  }

  Future<void> permanentDelete(MediaFile media) async {
    final id = media.id;
    if (id == null) return;
    final history = await getHistory(id);
    final db = await _databaseService.database;
    await db.transaction((txn) async {
      await txn.delete(
        'media_collection_items',
        where: 'media_id = ?',
        whereArgs: [id],
      );
      await txn
          .delete('media_edit_history', where: 'media_id = ?', whereArgs: [id]);
      await txn.delete('media_files', where: 'id = ?', whereArgs: [id]);
    });

    final paths = <String>{
      media.originalPath,
      media.filePath,
      if (media.editedPath != null) media.editedPath!,
      ...history.expand((item) => [item.sourcePath, item.outputPath]),
    };
    for (final path in paths) {
      await _storageService.deleteIfManaged(path);
    }
  }

  /// Backward-compatible method. It now safely removes the record only.
  Future<int> deleteMedia(int id) async {
    final media = await getMediaById(id);
    if (media == null) return 0;
    await moveToTrash(media);
    return 1;
  }

  Future<MediaFile> duplicateMedia(MediaFile media) async {
    final source = File(media.currentPath);
    if (!await source.exists()) {
      throw FileSystemException('Media file is missing.', media.currentPath);
    }
    return importFile(source,
        preferredName: '${media.title}_copy.${media.extension ?? 'bin'}');
  }

  Future<List<MediaEditHistory>> getHistory(int mediaId) async {
    final db = await _databaseService.database;
    final rows = await db.query(
      'media_edit_history',
      where: 'media_id = ?',
      whereArgs: [mediaId],
      orderBy: 'version DESC, id DESC',
    );
    return rows.map(MediaEditHistory.fromMap).toList(growable: false);
  }

  Future<MediaLibraryStats> getStats() async {
    final db = await _databaseService.database;
    final rows = await db.rawQuery('''
      SELECT
        COUNT(*) AS total,
        SUM(CASE WHEN media_type = 'image' THEN 1 ELSE 0 END) AS images,
        SUM(CASE WHEN media_type = 'video' THEN 1 ELSE 0 END) AS videos,
        SUM(CASE WHEN media_type = 'audio' THEN 1 ELSE 0 END) AS audio,
        SUM(CASE WHEN media_type = 'pdf' THEN 1 ELSE 0 END) AS pdfs,
        SUM(CASE WHEN is_favorite = 1 THEN 1 ELSE 0 END) AS favorites,
        COALESCE(SUM(file_size), 0) AS total_bytes
      FROM media_files
      WHERE is_deleted = 0
    ''');
    final row = rows.first;
    return MediaLibraryStats(
      total: _int(row['total']),
      images: _int(row['images']),
      videos: _int(row['videos']),
      audio: _int(row['audio']),
      pdfs: _int(row['pdfs']),
      favorites: _int(row['favorites']),
      totalBytes: _int(row['total_bytes']),
    );
  }

  Future<int> addGeneratedAudio({
    required File file,
    required String title,
    String action = 'tts_generated',
  }) async {
    final media = await importFile(file, preferredName: p.basename(file.path));
    if (media.id != null) {
      final db = await _databaseService.database;
      await db.update(
        'media_files',
        {'title': title, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [media.id],
      );
      await _insertHistory(
        db,
        MediaEditHistory(
          mediaId: media.id!,
          action: action,
          version: 1,
          sourcePath: media.currentPath,
          outputPath: media.currentPath,
          metadataJson: jsonEncode({'offline_generated': true}),
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      // The generated file has already been copied into immutable app-owned
      // original storage. Remove the provisional TTS output to avoid keeping a
      // duplicate file that is not referenced by the database.
      await _storageService.deleteIfManaged(file.path);
    }
    return media.id ?? 0;
  }

  Future<MediaFile?> _repairLegacyMedia(Database db, MediaFile media) async {
    final current = File(media.currentPath);
    if (await current.exists()) return media;

    final original = File(media.originalPath);
    if (await original.exists()) {
      final repaired = media.copyWith(
        filePath: original.path,
        clearEditedPath: true,
        updatedAt: DateTime.now().toIso8601String(),
      );
      if (media.id != null) {
        await db.update(
          'media_files',
          {
            'file_path': original.path,
            'edited_path': null,
            'updated_at': repaired.updatedAt,
          },
          where: 'id = ?',
          whereArgs: [media.id],
        );
      }
      return repaired;
    }

    // Do not delete the row. A future restore may bring the file back.
    return null;
  }

  Future<void> _insertHistory(
    DatabaseExecutor db,
    MediaEditHistory history,
  ) async {
    final map = history.toMap()..remove('id');
    await db.insert('media_edit_history', map);
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
