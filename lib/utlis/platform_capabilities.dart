import 'package:flutter/foundation.dart';

/// Capabilities that are intentionally limited by the current platform.
///
/// `cunning_document_scanner` is used only on Android and iOS. Desktop and
/// web builds may still open the document library to view/manage existing
/// scans, but they must never expose or invoke camera scanning.
bool get documentScannerCaptureSupported {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

bool get isDesktopAppPlatform {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows;
}
