import 'package:flutter/services.dart';

Future<String?> getInitialFile() async {
  try {
    const platform = MethodChannel('file_handler');
    final String? filePath = await platform.invokeMethod('getInitialFile');
    return filePath;
  } on PlatformException catch (e) {
    print("Failed to get initial file: $e");
    return null;
  }
}
