import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Photo rendering shared by desktop/mobile and Flutter Web.
/// On the web, native filesystem paths cannot be read. Photos must be backed
/// by a browser-accessible URL or a persisted data URI (upload/storage handled
/// by the repository layer, not by these presentation widgets).
class LifeArchiveMedia {
  const LifeArchiveMedia._();

  static bool canDisplay(String? path) {
    if (path == null || path.isEmpty) return false;
    if (_isUri(path)) return true;
    if (kIsWeb) return false;
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  static bool _isUri(String path) => path.startsWith('https://') ||
      path.startsWith('http://') || path.startsWith('blob:') ||
      path.startsWith('data:image/');

  static Uint8List? _decodeDataUri(String path) {
    try {
      return base64Decode(path.substring(path.indexOf(',') + 1));
    } catch (_) {
      return null;
    }
  }

  static ImageProvider? provider(String? path) {
    if (!canDisplay(path)) return null;
    if (_isUri(path!)) {
      if (path.startsWith('data:image/')) {
        final bytes = _decodeDataUri(path);
        return bytes == null ? null : MemoryImage(bytes);
      }
      return NetworkImage(path);
    }
    return FileImage(File(path!));
  }

  static Widget image(String path, {
    BoxFit? fit, int? cacheWidth, double? width, double? height,
    ImageErrorWidgetBuilder? errorBuilder,
  }) {
    final error = errorBuilder ?? (_, __, ___) =>
        const Center(child: Icon(Icons.broken_image_outlined));
    if (!canDisplay(path)) return Builder(builder: (context) =>
      error(context, StateError('Image unavailable'), null));
    if (kIsWeb || _isUri(path)) {
      final provider = LifeArchiveMedia.provider(path);
      if (provider == null) return const Center(child: Icon(Icons.broken_image_outlined));
      return Image(image: provider, fit: fit, width: width, height: height,
        errorBuilder: error);
    }
    return Image.file(File(path), fit: fit, cacheWidth: cacheWidth,
      width: width, height: height, errorBuilder: error);
  }
}

