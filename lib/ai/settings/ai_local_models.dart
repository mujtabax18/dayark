import 'package:flutter/foundation.dart';

import '../core/ai_provider.dart';
import '../hardware/ai_hardware.dart';
import '../model_manager/model_catalogue.dart';
import '../providers/offline/offline_runtime.dart';

class AiLocalInstallation {
  const AiLocalInstallation({
    required this.id,
    required this.name,
    required this.bytes,
    required this.revision,
    required this.sha256,
    this.detectedModel,
  });
  final String id, name, revision, sha256;
  final int bytes;
  final AiLocalModel? detectedModel;
}

/// Shared app session. Leaving Settings never frees an engine used by chat.
abstract class AiLocalModels extends ChangeNotifier {
  AiProvider? get provider;
  AiHardwareReport? get hardware;
  List<AiLocalInstallation> get installed;
  bool get busy;
  double? get progress;
  String? get loadedId;
  String? get downloadingId => null;
  int get downloadedBytes => 0;
  int? get downloadTotalBytes => null;
  String? get status;
  String? get benchmark;
  bool get supported;
  bool get supportsImport => false;
  Future<void> importFile(String path, {required String name}) => Future.error(
    UnsupportedError('Local GGUF import is unavailable on this platform.'),
  );
  Future<void> refresh();
  Future<void> install(AiCatalogueModel model);
  Future<void> load(String id);
  Future<void> unload();
  Future<void> delete(String id);
  Future<void> measure(String id);
  void cancel();
}
