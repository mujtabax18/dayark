import '../models/ai_provider_models.dart';
import 'ai_cancellation.dart';
import 'ai_provider.dart';

/// Optional extension keeps Part 1 providers source-compatible.
abstract interface class AiManagedProvider implements AiProvider {
  Future<AiModelPage> listModels({
    String? cursor,
    required AiCancellationToken cancellationToken,
  });

  /// Tests authentication/reachability without sending conversation contents.
  /// Offline implementations actually load the selected local model.
  Future<void> checkConnection({
    String? modelId,
    required AiCancellationToken cancellationToken,
  });
}
