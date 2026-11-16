import '../../core/ai_cancellation.dart';
import '../../core/ai_error.dart';
import '../../models/ai_models.dart';
import '../../models/ai_request.dart';
import 'offline_runtime.dart';

AiOfflineRuntime createOfflineRuntime() => _UnsupportedRuntime();

class _UnsupportedRuntime implements AiOfflineRuntime {
  Never _unsupported() => throw const AiException(
    AiErrorCode.unsupportedCapability,
    'Embedded GGUF inference requires a supported native platform.',
  );
  @override
  Future<void> load(AiLocalModel model, AiCancellationToken token) async =>
      _unsupported();
  @override
  Future<AiResponse> generate(
    AiRequest request,
    AiCancellationToken token,
  ) async => _unsupported();
  @override
  Future<void> dispose() async {}
}
