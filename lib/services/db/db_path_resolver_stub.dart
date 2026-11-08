Future<String?> resolveDatabasePath({
  required String legacyFileName,
  required String driftFileName,
}) async {
  // Web databases are stored by drift through OPFS / IndexedDB, so there is
  // no native file-system path to provide here.
  return null;
}
