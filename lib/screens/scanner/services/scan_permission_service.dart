import 'package:permission_handler/permission_handler.dart';

class ScanPermissionService {
  static Future<bool> requestCamera() async {
    final status = await Permission.camera.request();
    return status.isGranted || status.isLimited;
  }

  static Future<void> openSettings() => openAppSettings();
}
