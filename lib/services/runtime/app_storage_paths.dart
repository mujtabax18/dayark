import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as path_provider;

// Keep all other path_provider declarations available to callers, but route
// application-owned storage through our environment-aware directory helpers.
export 'package:path_provider/path_provider.dart'
    hide getApplicationDocumentsDirectory,
         getApplicationSupportDirectory,
         getTemporaryDirectory;

/// Debug runs must never read, upgrade, overwrite, or clean up the Release
/// application's data. Every Debug build starts with its own empty storage.
/// Release/Profile use exactly the original path_provider directories.
const String debugStorageFolder = 'dayark_debug';

Future<Directory> _scoped(Future<Directory> Function() provider) async {
  final original = await provider();
  if (!kDebugMode) return original;
  final isolated = Directory(p.join(original.path, debugStorageFolder));
  if (!await isolated.exists()) await isolated.create(recursive: true);
  return isolated;
}

Future<Directory> getApplicationDocumentsDirectory() =>
    _scoped(path_provider.getApplicationDocumentsDirectory);

Future<Directory> getApplicationSupportDirectory() =>
    _scoped(path_provider.getApplicationSupportDirectory);

Future<Directory> getTemporaryDirectory() =>
    _scoped(path_provider.getTemporaryDirectory);
