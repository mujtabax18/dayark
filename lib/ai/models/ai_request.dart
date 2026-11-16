import '../settings/ai_settings.dart';
import 'ai_models.dart';

class AiRequest {
  AiRequest({
    required this.selection,
    required Iterable<AiMessage> messages,
    AiSettings? settings,
    this.allowRemoteProcessing = false,
    this.containsPrivateContext = false,
    this.allowPrivateContextOnline = false,
  }) : messages = List.unmodifiable(messages),
       settings = settings ?? AiSettings() {
    if (this.messages.isEmpty) throw ArgumentError('Messages are required.');
  }
  final AiModelSelection selection;
  final List<AiMessage> messages;
  final AiSettings settings;

  /// Explicit authorization for this request, including its context/attachments.
  final bool allowRemoteProcessing;
  final bool containsPrivateContext;
  final bool allowPrivateContextOnline;
}
