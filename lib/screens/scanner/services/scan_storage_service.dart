import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:metersystem/services/runtime/app_storage_paths.dart';

class StoredScanAsset {
  const StoredScanAsset({
    required this.path,
    required this.fileSize,
    required this.checksum,
  });

  final String path;
  final int fileSize;
  final String checksum;
}

class ScanStorageService {
  Future<Directory> _root() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(documents.path, 'HomeHelperScans'));
    await directory.create(recursive: true);
    return directory;
  }

  Future<StoredScanAsset> importOriginal(
    File source, {
    int? groupId,
  }) async {
    if (!await source.exists()) {
      throw FileSystemException('The selected scan image is missing.', source.path);
    }
    final root = await _root();
    final directory = Directory(p.join(root.path, 'originals'));
    await directory.create(recursive: true);
    final extension = _safeExtension(source.path);
    final name = 'scan_${groupId ?? 0}_${DateTime.now().microsecondsSinceEpoch}$extension';
    final destination = File(p.join(directory.path, name));
    await source.copy(destination.path);
    return _describe(destination);
  }

  Future<StoredScanAsset> saveEditedBytes({
    required Uint8List bytes,
    required int scanId,
    required int version,
    String extension = '.jpg',
  }) async {
    final root = await _root();
    final directory = Directory(p.join(root.path, 'edits', 'scan_$scanId'));
    await directory.create(recursive: true);
    final normalized = extension.startsWith('.') ? extension : '.$extension';
    final destination = File(
      p.join(
        directory.path,
        'scan_${scanId}_v${version}_${DateTime.now().microsecondsSinceEpoch}$normalized',
      ),
    );
    await destination.writeAsBytes(bytes, flush: true);
    return _describe(destination);
  }

  Future<StoredScanAsset> copyEditedFile({
    required File source,
    required int scanId,
    required int version,
  }) async {
    final bytes = await source.readAsBytes();
    return saveEditedBytes(
      bytes: bytes,
      scanId: scanId,
      version: version,
      extension: _safeExtension(source.path),
    );
  }

  Future<Directory> exportDirectory() async {
    final root = await _root();
    final directory = Directory(p.join(root.path, 'exports'));
    await directory.create(recursive: true);
    return directory;
  }

  Future<bool> isManagedPath(String path) async {
    if (path.trim().isEmpty) return false;

    final documents = await getApplicationDocumentsDirectory();
    final normalizedPath = p.normalize(File(path).absolute.path);
    final managedRoots = <String>[
      p.join(documents.path, 'HomeHelperScans'),
      p.join(documents.path, 'HomeHelperRestored'),
    ].map((value) => p.normalize(Directory(value).absolute.path));

    return managedRoots.any(
      (root) => normalizedPath == root || p.isWithin(root, normalizedPath),
    );
  }

  Future<void> deleteIfManaged(String? path) async {
    if (path == null || path.trim().isEmpty) return;
    if (!await isManagedPath(path)) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<StoredScanAsset> describe(File file) async {
    if (!await file.exists()) {
      throw FileSystemException(
        'The scan image is missing.',
        file.path,
      );
    }
    return _describe(file);
  }

  Future<StoredScanAsset> _describe(File file) async {
    final bytes = await file.readAsBytes();
    return StoredScanAsset(
      path: file.path,
      fileSize: bytes.length,
      checksum: sha256.convert(bytes).toString(),
    );
  }

  String _safeExtension(String path) {
    final extension = p.extension(path).toLowerCase();
    const allowed = {'.jpg', '.jpeg', '.png', '.webp', '.bmp'};
    return allowed.contains(extension) ? extension : '.jpg';
  }
}
