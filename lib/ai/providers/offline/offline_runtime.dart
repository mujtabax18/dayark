import '../../core/ai_stream.dart';
import '../../core/ai_cancellation.dart';
import '../../models/ai_models.dart';
import '../../models/ai_request.dart';

class AiLocalModel {
  AiLocalModel({
    required this.id,
    required this.path,
    String? name,
    this.contextSize = 4096,
  }) : name = name ?? id {
    if (id.trim().isEmpty ||
        path.trim().isEmpty ||
        contextSize < 1 ||
        !path.toLowerCase().endsWith('.gguf') ||
        path.contains('://')) {
      throw ArgumentError(
        'A local GGUF file, ID and positive context size are required.',
      );
    }
  }
  final String id;
  final String name;
  final String path;
  final int contextSize;
}

/// Narrow runtime seam for native engine integration and deterministic tests.
abstract interface class AiOfflineRuntime {
  Future<void> load(AiLocalModel model, AiCancellationToken token);
  Future<AiResponse> generate(AiRequest request, AiCancellationToken token);
  Future<void> dispose();
}

abstract interface class AiStreamingOfflineRuntime {
  Stream<AiStreamEvent> stream(AiRequest request, AiCancellationToken token);
}
