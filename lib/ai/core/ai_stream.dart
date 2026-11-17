import '../models/ai_models.dart';
import '../models/ai_request.dart';
import 'ai_cancellation.dart';

/// Deltas are provisional. Only a terminal response establishes success.
class AiStreamEvent {
  const AiStreamEvent.delta(this.text) : response = null, isActivity = false;
  const AiStreamEvent.completed(AiResponse value)
    : response = value,
      text = '',
      isActivity = false;

  /// Model activity without exposing reasoning text or adding it to history.
  const AiStreamEvent.activity()
    : text = '',
      response = null,
      isActivity = true;
  final String text;
  final bool isActivity;
  final AiResponse? response;
}

abstract interface class AiStreamingProvider {
  Stream<AiStreamEvent> stream(
    AiRequest request, {
    required AiCancellationToken cancellationToken,
  });
}
