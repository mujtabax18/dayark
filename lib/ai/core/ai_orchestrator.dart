import '../models/ai_models.dart';
import '../models/ai_request.dart';
import '../prompts/prompt_manager.dart';
import '../settings/ai_settings.dart';
import 'ai_cancellation.dart';
import 'ai_error.dart';
import 'ai_gateway.dart';

/// Stateless workflow: callers own history and append only successful responses.
/// Model switching uses the same supplied history, without a second chat system.
class AiOrchestrator {
  const AiOrchestrator({
    required this.gateway,
    this.promptManager = const PromptManager(),
  });
  final AiGateway gateway;
  final PromptManager promptManager;

  Future<AiResponse> send({
    required AiModelSelection selection,
    required AiMessage message,
    Iterable<AiMessage> history = const [],
    AiSettings? settings,
    bool allowRemoteProcessing = false,
    bool containsPrivateContext = false,
    bool allowPrivateContextOnline = false,
    AiCancellationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled();
    final effectiveSettings = settings ?? AiSettings();
    final List<AiMessage> messages;
    try {
      messages = promptManager.build(
        settings: effectiveSettings,
        history: history,
        message: message,
      );
    } on ArgumentError {
      throw const AiException(
        AiErrorCode.invalidRequest,
        'Expected a user message and user/assistant history.',
      );
    }
    return gateway.generate(
      AiRequest(
        selection: selection,
        messages: messages,
        settings: effectiveSettings,
        allowRemoteProcessing: allowRemoteProcessing,
        containsPrivateContext: containsPrivateContext,
        allowPrivateContextOnline: allowPrivateContextOnline,
      ),
      cancellationToken: cancellationToken,
    );
  }
}
