import 'dart:io';

import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';

import '../data/models/scan_model.dart';

class ScanGalleryService {
  static Future<int> saveGroup({
    required String title,
    required List<ScanEntry> scans,
  }) async {
    final permission = await PhotoManager.requestPermissionExtend();

    if (!permission.isAuth) {
      throw Exception('Gallery permission denied');
    }

    final dateTime = DateFormat('dd MMM yyyy hh-mm a').format(DateTime.now());

    final albumName = '$title - $dateTime';
    final relativePath = 'Pictures/Scanned/$albumName';

    int savedCount = 0;

    for (final scan in scans) {
      final file = File(scan.currentPath);

      if (!file.existsSync()) continue;

      await PhotoManager.editor.saveImage(
        await file.readAsBytes(),
        filename: file.uri.pathSegments.last,
        title: file.uri.pathSegments.last,
        relativePath: relativePath,
      );

      savedCount++;
    }

    return savedCount;
  }
}
