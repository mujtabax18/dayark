import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:metersystem/services/runtime/app_storage_paths.dart';

class StoredMediaAsset {
  const StoredMediaAsset({
    required this.path,
    required this.fileName,
    required this.extension,
    required this.mimeType,
    required this.mediaType,
    required this.fileSize,
    required this.checksum,
  });

  final String path;
  final String fileName;
  final String extension;
  final String mimeType;
  final String mediaType;
  final int fileSize;
  final String checksum;
}

class MediaStorageService {
  static const String rootFolderName = 'HomeHelperMedia';

  Future<Directory> rootDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(base.path, rootFolderName));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<StoredMediaAsset> importOriginal(
    File source, {
    String? preferredName,
  }) async {
    if (!await source.exists()) {
      throw FileSystemException('Selected media file does not exist.', source.path);
    }

    final root = await rootDirectory();
    final originals = Directory(p.join(root.path, 'originals'));
    await originals.create(recursive: true);

    final sourceName = preferredName?.trim().isNotEmpty == true
        ? preferredName!.trim()
        : p.basename(source.path);
    final extension = _normalizedExtension(sourceName, source.path);
    final cleanBase = _safeName(p.basenameWithoutExtension(sourceName));
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final fileName = '${cleanBase}_$stamp.$extension';
    final destination = File(p.join(originals.path, fileName));

    await source.copy(destination.path);
    return describe(destination);
  }

  Future<StoredMediaAsset> saveEditedBytes({
    required Uint8List bytes,
    required int mediaId,
    required int version,
    String extension = 'jpg',
  }) async {
    if (bytes.isEmpty) {
      throw const FormatException('The editor returned an empty file.');
    }

    final root = await rootDirectory();
    final edits = Directory(p.join(root.path, 'edits', 'media_$mediaId'));
    await edits.create(recursive: true);

    final safeExtension = extension.replaceAll('.', '').toLowerCase();
    final file = File(
      p.join(
        edits.path,
        'version_${version}_${DateTime.now().microsecondsSinceEpoch}.$safeExtension',
      ),
    );
    await file.writeAsBytes(bytes, flush: true);
    return describe(file);
  }

  Future<StoredMediaAsset> copyVersion({
    required File source,
    required int mediaId,
    required int version,
  }) async {
    final bytes = await source.readAsBytes();
    return saveEditedBytes(
      bytes: bytes,
      mediaId: mediaId,
      version: version,
      extension: p.extension(source.path).replaceFirst('.', ''),
    );
  }

  Future<StoredMediaAsset> createTtsOutput({
    required String extension,
  }) async {
    final root = await rootDirectory();
    final tts = Directory(p.join(root.path, 'tts'));
    await tts.create(recursive: true);
    final file = File(
      p.join(
        tts.path,
        'tts_${DateTime.now().microsecondsSinceEpoch}.${extension.replaceAll('.', '')}',
      ),
    );

    // The TTS engine writes this file later. Return a provisional descriptor.
    return StoredMediaAsset(
      path: file.path,
      fileName: p.basename(file.path),
      extension: p.extension(file.path).replaceFirst('.', ''),
      mimeType: extension.toLowerCase() == 'caf' ? 'audio/x-caf' : 'audio/wav',
      mediaType: 'audio',
      fileSize: 0,
      checksum: '',
    );
  }

  Future<StoredMediaAsset> describe(File file) async {
    final bytes = await file.readAsBytes();
    final mimeType = lookupMimeType(file.path, headerBytes: bytes.take(32).toList()) ??
        'application/octet-stream';
    return StoredMediaAsset(
      path: file.path,
      fileName: p.basename(file.path),
      extension: p.extension(file.path).replaceFirst('.', '').toLowerCase(),
      mimeType: mimeType,
      mediaType: mediaTypeFromMime(mimeType, file.path),
      fileSize: bytes.length,
      checksum: sha256.convert(bytes).toString(),
    );
  }

  String mediaTypeFromMime(String mimeType, String path) {
    if (mimeType.startsWith('image/')) return 'image';
    if (mimeType.startsWith('video/')) return 'video';
    if (mimeType.startsWith('audio/')) return 'audio';
    if (mimeType == 'application/pdf' || p.extension(path).toLowerCase() == '.pdf') {
      return 'pdf';
    }
    return 'file';
  }

  Future<bool> isManagedPath(String path) async {
    if (path.trim().isEmpty) return false;
    final root = await rootDirectory();
    return p.isWithin(p.normalize(root.path), p.normalize(path));
  }

  Future<void> deleteIfManaged(String? path) async {
    if (path == null || path.trim().isEmpty) return;
    final root = await rootDirectory();
    final normalizedRoot = p.normalize(root.path);
    final normalizedPath = p.normalize(path);
    if (!p.isWithin(normalizedRoot, normalizedPath)) return;

    final file = File(normalizedPath);
    if (await file.exists()) await file.delete();
  }

  String _normalizedExtension(String name, String path) {
    final fromName = p.extension(name).replaceFirst('.', '').toLowerCase();
    if (fromName.isNotEmpty) return fromName;
    final fromPath = p.extension(path).replaceFirst('.', '').toLowerCase();
    return fromPath.isEmpty ? 'bin' : fromPath;
  }

  String _safeName(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return cleaned.isEmpty ? 'media' : cleaned;
  }
}
