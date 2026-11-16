import '../models/ai_models.dart';
import '../models/ai_request.dart';
import 'ai_cancellation.dart';

/// Deltas are provisional. Only a terminal response establishes success.
class AiStreamEvent {
  const AiStreamEvent.delta(this.text) : response = null;
  const AiStreamEvent.completed(AiResponse value) : response = value, text = '';
  final String text;
  final AiResponse? response;
}

abstract interface class AiStreamingProvider {
  Stream<AiStreamEvent> stream(
    AiRequest request, {
    required AiCancellationToken cancellationToken,
  });
}
