import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:path/path.dart' as p;
import 'package:metersystem/services/runtime/app_storage_paths.dart';

Future<String?> resolveDatabasePath({
  required String legacyFileName,
  required String driftFileName,
}) async {
  final documents = await getApplicationDocumentsDirectory();
  final preferred = File(p.join(documents.path, driftFileName));

  // Never probe legacy/Release paths from a Debug run. The Debug database
  // is a fresh file in dayark_debug, not a copy of production data.
  if (kDebugMode) return preferred.path;

  // Once Drift has created its database, always keep using it.
  if (await preferred.exists()) return preferred.path;

  // Preserve the existing sqflite database in-place on upgrades. This is safer
  // than copying because SQLite may have a WAL/SHM pair next to the database.
  final candidates = <String>{
    p.join(documents.path, legacyFileName),
    p.join(documents.parent.path, 'databases', legacyFileName), // Android
    p.join(documents.parent.path, 'Library', 'LocalDatabase', legacyFileName),
    p.join(documents.parent.path, 'Library', legacyFileName),
  };

  try {
    final support = await getApplicationSupportDirectory();
    candidates.addAll({
      p.join(support.path, legacyFileName),
      p.join(support.parent.path, legacyFileName),
      p.join(support.parent.path, 'LocalDatabase', legacyFileName),
      p.join(support.parent.path, 'databases', legacyFileName),
    });
  } catch (_) {
    // Some targets may not expose a separate support directory.
  }

  try {
    final library = await getLibraryDirectory();
    candidates.addAll({
      p.join(library.path, legacyFileName),
      p.join(library.path, 'LocalDatabase', legacyFileName),
      p.join(library.path, 'Application Support', legacyFileName),
    });
  } catch (_) {
    // getLibraryDirectory is only available on supported Apple targets.
  }

  for (final candidate in candidates) {
    if (await File(candidate).exists()) return candidate;
  }

  return preferred.path;
}
