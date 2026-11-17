import '../core/ai_stream.dart';
import '../memory/memory_context_service.dart';
import '../rag/context_builder.dart';
import '../core/ai_attachments.dart';
import '../core/ai_cancellation.dart';
import '../core/ai_error.dart';
import '../core/ai_gateway.dart';
import '../core/ai_orchestrator.dart';
import '../core/ai_provider.dart';
import '../models/ai_models.dart';
import '../providers/http/http_ai_provider.dart';
import 'ai_preferences.dart';
import 'ai_local_models_factory.dart';
import 'ai_settings_store.dart';

/// Resolves saved selection and permissions for the existing, single chat workflow.
/// The caller retains conversation history and the model manager's offline provider.
class AiConfiguredAssistant {
  const AiConfiguredAssistant(this.store, {this.memory});
  final MemoryContextService? memory;
  final AiSettingsStore store;

  Future<AiResponse> send({
    required AiMessage message,
    Iterable<AiMessage> history = const [],
    AiProvider? offline,
    String? profileId,
    bool containsPrivateContext = false,
    AiCancellationToken? cancellationToken,
  }) async {
    AiResponse? response;
    await for (final event in stream(
      message: message,
      history: history,
      offline: offline,
      profileId: profileId,
      containsPrivateContext: containsPrivateContext,
      cancellationToken: cancellationToken,
    )) {
      response = event.response ?? response;
    }
    return response!;
  }

  Stream<AiStreamEvent> stream({
    required AiMessage message,
    Iterable<AiMessage> history = const [],
    AiProvider? offline,
    String? profileId,
    bool containsPrivateContext = false,
    AiCancellationToken? cancellationToken,
  }) async* {
    final preferences = store.load();
    final profile = profileId == null
        ? preferences.selectedProfile
        : preferences.profiles.where((p) => p.id == profileId).firstOrNull;
    if (profile == null) {
      throw const AiException(
        AiErrorCode.providerUnavailable,
        'Choose an AI profile in settings.',
      );
    }
    final preparedMessage = prepareAiAttachments([message]).single;
    final preparedHistory = prepareAiAttachments(history);
    final AiBuiltContext? context;
    try {
      context = await memory?.build(
        message: preparedMessage,
        history: preparedHistory,
        settings: preferences.settings,
      );
    } on StateError catch (error) {
      throw AiException(AiErrorCode.invalidRequest, error.message);
    }
    cancellationToken?.throwIfCancelled();
    final local = profile.kind == AiProviderKind.offline && offline == null
        ? await sharedAiLocalModels()
        : null;
    if (local?.busy ?? false) {
      throw const AiException(
        AiErrorCode.providerUnavailable,
        'Local model maintenance is in progress.',
      );
    }
    final provider = profile.createProvider(
      credentials: () => store.credential(profile.id),
      offline: offline ?? local?.provider,
    );
    try {
      final events =
          AiOrchestrator(
            gateway: AiGateway(
              providers: [provider],
              retryPolicy:
                  profile.kind == AiProviderKind.ollama ||
                      profile.kind == AiProviderKind.offline
                  ? AiRetryPolicy.localInference()
                  : null,
            ),
          ).stream(
            selection: AiModelSelection(
              providerId: provider.id,
              modelId: profile.modelId,
            ),
            message: preparedMessage,
            history: context?.history ?? preparedHistory,
            retrievedContext: context?.excerpts ?? '',
            settings: settingsForCapabilities(
              preferences.settings,
              provider.capabilitiesFor(profile.modelId),
              // Reasoning and the answer share Ollama's prediction budget. Let
              // local chat finish naturally; Stop remains available.
              applyOutputLimit: profile.kind != AiProviderKind.ollama,
            ),
            allowRemoteProcessing: preferences.allowOnlineProcessing,
            containsPrivateContext:
                containsPrivateContext ||
                (context?.excerpts.isNotEmpty ?? false),
            allowPrivateContextOnline: preferences.allowPrivateContextOnline,
            cancellationToken: cancellationToken,
          );
      await for (final event in events) {
        final response = event.response;
        if (response != null && (context?.hits.isNotEmpty ?? false)) {
          yield AiStreamEvent.completed(
            AiResponse(
              selection: response.selection,
              message: AiMessage(
                role: AiRole.assistant,
                text: response.message.text + context!.references,
                attachments: response.message.attachments,
                containsPrivateContext: response.message.containsPrivateContext,
              ),
              usage: response.usage,
              finishReason: response.finishReason,
            ),
          );
        } else {
          yield event;
        }
      }
    } finally {
      if (provider is HttpAiProvider) provider.close();
    }
  }
}
