import '../core/ai_capabilities.dart';
import '../core/ai_error.dart';
import 'ai_models.dart';

class AiModelInfo {
  const AiModelInfo({
    required this.selection,
    required this.name,
    required this.capabilities,
    this.inputTokenLimit,
    this.outputTokenLimit,
  });
  final AiModelSelection selection;
  final String name;
  final AiCapabilities capabilities;
  final int? inputTokenLimit;
  final int? outputTokenLimit;
}

/// A provider page. Pass nextCursor back unchanged; null means the last page.
class AiModelPage {
  AiModelPage({required Iterable<AiModelInfo> models, this.nextCursor})
    : models = List.unmodifiable(models);
  final List<AiModelInfo> models;
  final String? nextCursor;
}

class AiConnectionResult {
  const AiConnectionResult.connected() : error = null;
  const AiConnectionResult.failed(AiException failure) : error = failure;
  final AiException? error;
  bool get isConnected => error == null;
}
