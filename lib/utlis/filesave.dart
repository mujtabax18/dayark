import 'dart:io';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';



import 'package:permission_handler/permission_handler.dart';

class FileSaver {
  static Future<void> saveAndSharePdf(Uint8List bytes, String fileName) async {
    // Request storage permission
    // final status = await Permission.storage.request();
    // if (!status.isGranted) {
    //   throw Exception('Storage permission not granted');
    // }

    // Use downloads directory instead
    final directory = Directory('/storage/emulated/0/Download');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)]);
  }

  static Future<void> saveAndShareCsv(String content, String fileName) async {
    // Request storage permission
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      throw Exception('Storage permission not granted');
    }

    // Use downloads directory instead
    final directory = Directory('/storage/emulated/0/Download');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final file = File('${directory.path}/$fileName');
    await file.writeAsString(content);
    await Share.shareXFiles([XFile(file.path)]);
  }
}