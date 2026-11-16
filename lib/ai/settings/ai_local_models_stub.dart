import '../model_manager/model_catalogue.dart';
import 'ai_local_models.dart';

Future<AiLocalModels> sharedAiLocalModels() async => _UnsupportedModels();

class _UnsupportedModels extends AiLocalModels {
  @override
  get provider => null;
  @override
  get hardware => null;
  @override
  List<AiLocalInstallation> get installed => const [];
  @override
  bool get busy => false;
  @override
  double? get progress => null;
  @override
  String? get loadedId => null;
  @override
  String get status => 'Local GGUF models require the desktop or mobile app.';
  @override
  String? get benchmark => null;
  @override
  bool get supported => false;
  @override
  Future<void> refresh() async {}
  @override
  Future<void> install(AiCatalogueModel model) async =>
      throw UnsupportedError(status);
  @override
  Future<void> load(String id) async => throw UnsupportedError(status);
  @override
  Future<void> unload() async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> measure(String id) async => throw UnsupportedError(status);
  @override
  void cancel() {}
}
