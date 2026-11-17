import '../models/ai_models.dart';
import '../models/ai_request.dart';
import 'ai_cancellation.dart';

/// Deltas are provisional. Only a terminal response establishes success.
class AiStreamEvent {
  const AiStreamEvent.delta(this.text)
    : response = null,
      isActivity = false,
      thinking = null,
      diagnostic = null;
  const AiStreamEvent.completed(AiResponse value)
    : response = value,
      text = '',
      isActivity = false,
      thinking = null,
      diagnostic = null;

  /// Model activity without adding reasoning to the visible answer or history.
  const AiStreamEvent.activity({this.thinking, this.diagnostic})
    : text = '',
      response = null,
      isActivity = true;
  final String text;
  final bool isActivity;
  final AiResponse? response;

  /// Provider-supplied reasoning is kept out of the assistant answer and
  /// conversation context. Callers may retain a bounded copy for an explicit
  /// diagnostics view when a request fails.
  final String? thinking;

  /// Sanitized lifecycle metadata such as finish reason and token counts.
  final String? diagnostic;
}

abstract interface class AiStreamingProvider {
  Stream<AiStreamEvent> stream(
    AiRequest request, {
    required AiCancellationToken cancellationToken,
  });
}
