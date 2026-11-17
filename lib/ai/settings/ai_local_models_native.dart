import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/ai_cancellation.dart';
import '../core/ai_error.dart';
import '../hardware/ai_hardware.dart';
import '../hardware/hardware_probe.dart';
import '../model_manager/local_model_manager.dart';
import '../model_manager/model_benchmark.dart';
import '../model_manager/model_catalogue.dart';
import '../providers/offline/offline_provider.dart';
import 'ai_local_models.dart';

Future<AiLocalModels>? _session;
Future<AiLocalModels> sharedAiLocalModels() =>
    _session ??= _create().catchError((Object error) {
      _session = null;
      throw error;
    });
Future<AiLocalModels> _create() async {
  final directory = Directory(
    p.join((await getApplicationSupportDirectory()).path, 'ai-models'),
  );
  await directory.create(recursive: true);
  final provider = OfflineAiProvider(models: []);
  final session = NativeAiLocalModels(
    AiLocalModelManager(directory: directory, provider: provider),
  );
  await session.refresh();
  return session;
}

class NativeAiLocalModels extends AiLocalModels {
  NativeAiLocalModels(this.manager, {this.hardwareProbe = detectAiHardware});
  final Future<AiHardwareReport> Function({required String storagePath})
  hardwareProbe;
  final AiLocalModelManager manager;
  @override
  OfflineAiProvider get provider => manager.provider;
  @override
  AiHardwareReport? hardware;
  @override
  List<AiLocalInstallation> installed = const [];
  @override
  bool busy = false;
  @override
  double? progress;
  @override
  String? loadedId;
  @override
  String? status;
  @override
  String? benchmark;
  AiCancellationToken? _token;
  @override
  bool get supported => hardware?.runtimeSupported != false;
  Future<void> _run(Future<void> Function(AiCancellationToken) action) async {
    if (busy) return;
    busy = true;
    status = null;
    progress = null;
    final token = _token = AiCancellationToken();
    notifyListeners();
    try {
      await action(token);
    } on AiException catch (error) {
      status = error.code == AiErrorCode.cancelled
          ? 'Operation cancelled.'
          : error.message;
    } catch (_) {
      status = 'Unable to complete model operation. Check model integrity, free storage and runtime support.';
    } finally {
      busy = false;
      _token = null;
      progress = null;
      notifyListeners();
    }
  }

  AiLocalInstallation _record(AiInstalledModel m) => AiLocalInstallation(
    id: m.model.id,
    name: m.model.name,
    bytes: m.bytes,
    revision: m.revision,
    sha256: m.sha256,
  );
  @override
  Future<void> refresh() => _run((token) async {
    hardware = await hardwareProbe(storagePath: manager.directory.path);
    loadedId = null; // Restore may unload the current native engine.
    final records = await manager.restore(cancellationToken: token);
    installed = records.map(_record).toList();
    status = 'Hardware and installed models refreshed.';
  });
  @override
  Future<void> install(AiCatalogueModel model) => _run((token) async {
    loadedId = null;
    final updates = Stopwatch()..start();
    var lastNotification = -100;
    final record = await manager.install(
      model,
      allowDownload: true,
      cancellationToken: token,
      onProgress: (received, total) {
        progress = received / total;
        if (received == total ||
            updates.elapsedMilliseconds - lastNotification >= 100) {
          lastNotification = updates.elapsedMilliseconds;
          notifyListeners();
        }
      },
    );
    loadedId = null;
    installed = [...installed.where((m) => m.id != model.id), _record(record)];
    hardware = await hardwareProbe(storagePath: manager.directory.path);
    status = '${model.name} installed and verified.';
  });
  @override
  Future<void> load(String id) => _run((token) async {
    loadedId = null;
    await manager.load(id, cancellationToken: token);
    loadedId = id;
    status = 'Model loaded.';
  });
  @override
  Future<void> unload() => _run((token) async {
    await manager.unload();
    loadedId = null;
    status = 'Model unloaded.';
  });
  @override
  Future<void> delete(String id) => _run((token) async {
    loadedId = null;
    await manager.delete(id, cancellationToken: token);
    loadedId = null;
    installed = installed.where((m) => m.id != id).toList();
    hardware = await hardwareProbe(storagePath: manager.directory.path);
    status = 'Model deleted.';
  });
  @override
  Future<void> measure(String id) => _run((token) async {
    loadedId = null;
    final result = await benchmarkLocalModel(
      provider: provider,
      modelId: id,
      cancellationToken: token,
    );
    loadedId = id;
    benchmark =
        '${result.outputTokensPerSecond?.toStringAsFixed(1) ?? 'Unknown'} tokens/s · '
        '${result.loadTime.inMilliseconds} ms load · ${(result.sampledPeakRssBytes / aiGiB).toStringAsFixed(2)} GiB process peak RAM';
    status = 'Benchmark complete. Model remains loaded.';
  });
  @override
  void cancel() => _token?.cancel();
}
