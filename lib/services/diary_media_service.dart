import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:metersystem/services/runtime/app_storage_paths.dart';

class DiaryMediaService {
  const DiaryMediaService._();

  static Future<String> persistPickedImage(XFile pickedFile) async {
    final source = File(pickedFile.path);
    if (!await source.exists()) {
      throw StateError('The selected image is no longer available.');
    }

    final directory = await _mediaDirectory();
    final extension = p.extension(pickedFile.path).isEmpty
        ? '.jpg'
        : p.extension(pickedFile.path).toLowerCase();
    final fileName =
        'diary_${DateTime.now().microsecondsSinceEpoch}$extension';
    final destination = File(p.join(directory.path, fileName));
    await source.copy(destination.path);
    return destination.path;
  }

  static Future<Directory> drawingDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, 'diary_drawings'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  static Future<Directory> _mediaDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, 'diary_media'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  static Future<void> deleteIfOwned(String? path) async {
    if (path == null || path.trim().isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists() &&
          (path.contains('diary_media') || path.contains('diary_drawings'))) {
        await file.delete();
      }
    } catch (_) {
      // Media cleanup should never block saving or deleting an entry.
    }
  }
}
