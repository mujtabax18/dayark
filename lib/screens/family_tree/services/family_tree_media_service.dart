import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:metersystem/services/runtime/app_storage_paths.dart';
import 'package:uuid/uuid.dart';

class FamilyTreeMediaService {
  FamilyTreeMediaService._();

  static const _uuid = Uuid();

  static Future<Directory> _treeDirectory(int treeId) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, 'family_trees', '$treeId'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  static Future<String> copyImage({
    required int treeId,
    required String sourcePath,
    required String category,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw StateError('The selected image is no longer available.');
    }

    final root = await _treeDirectory(treeId);
    final targetDir = Directory(p.join(root.path, category));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final extension = p.extension(source.path).isEmpty ? '.jpg' : p.extension(source.path);
    final target = File(p.join(targetDir.path, '${_uuid.v4()}$extension'));
    await source.copy(target.path);
    return target.path;
  }

  static Future<void> deleteFile(String? path) async {
    if (path == null || path.trim().isEmpty) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<void> deleteTreeDirectory(int treeId) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, 'family_trees', '$treeId'));
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
