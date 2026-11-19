import '../../core/ai_stream.dart';
import '../../core/ai_cancellation.dart';
import '../../models/ai_models.dart';
import '../../models/ai_request.dart';

class AiLocalModel {
  AiLocalModel({
    required this.id,
    required this.path,
    String? name,
    this.contextSize,
    this.nativeContextSize,
    this.architecture,
    this.fileType,
    this.estimatedMemoryBytes,
    this.gpuLayers,
    this.performance,
  }) : name = name ?? id {
    if (id.trim().isEmpty ||
        path.trim().isEmpty ||
        (contextSize != null && contextSize! < 1) ||
        !path.toLowerCase().endsWith('.gguf') ||
        path.contains('://')) {
      throw ArgumentError(
        'A local GGUF file and ID are required; context size must be positive when supplied.',
      );
    }
  }
  final String id;
  final String name;
  final String path;
  /// Null requests automatic GGUF and hardware detection on native load.
  final int? contextSize;
  final int? nativeContextSize, fileType, estimatedMemoryBytes, gpuLayers;
  final String? architecture;
  AiLocalPerformance? performance;
  int? activeContextSize;
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

/// Numeric-only measurements from successful ordinary inference.
class AiLocalPerformance {
  const AiLocalPerformance({required this.contextSize, this.tokensPerSecond, this.peakProcessRssBytes, this.loadMilliseconds});
  final int contextSize;
  final double? tokensPerSecond;
  final int? peakProcessRssBytes, loadMilliseconds;
}
