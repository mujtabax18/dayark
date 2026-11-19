import '../core/ai_stream.dart';
import '../memory/memory_context_service.dart';
import '../rag/context_builder.dart';
import '../core/ai_input_preparation.dart';
import '../core/ai_attachments.dart';
import '../core/ai_cancellation.dart';
import '../core/ai_error.dart';
import '../core/ai_gateway.dart';
import '../core/ai_orchestrator.dart';
import '../core/ai_provider.dart';
import '../models/ai_models.dart';
import '../providers/http/http_ai_provider.dart';
import 'ai_preferences.dart';
import 'ai_settings.dart';
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
    void Function(List<AiMessage>)? onPreparedMessages,
  }) async {
    AiResponse? response;
    await for (final event in stream(
      message: message,
      history: history,
      offline: offline,
      profileId: profileId,
      containsPrivateContext: containsPrivateContext,
      cancellationToken: cancellationToken,
      onPreparedMessages: onPreparedMessages,
    )) {
      response = event.response ?? response;
    }
    return response!;
  }

  Stream<AiStreamEvent> stream({
    required AiMessage message,
    Iterable<AiMessage> history = const [],
    AiProvider? offline,
    AiSettings? settingsOverride,
    String? profileId,
    bool containsPrivateContext = false,
    AiCancellationToken? cancellationToken,
    void Function(List<AiMessage>)? onPreparedMessages,
  }) async* {
    final preferences = store.load();
    final settings = settingsOverride ?? preferences.settings;
    final profile = profileId == null
        ? preferences.selectedProfile
        : preferences.profiles.where((p) => p.id == profileId).firstOrNull;
    if (profile == null) {
      throw const AiException(
        AiErrorCode.providerUnavailable,
        'Choose an AI profile in settings.',
      );
    }
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
      final capabilities = provider.capabilitiesFor(profile.modelId);
      final preparedMessage = await prepareAiInput(message, capabilities);
      final nativeContext = profile.kind == AiProviderKind.offline;
      if (!nativeContext) checkAiInputBudget(preparedMessage, settings);
      final preparedHistory = <AiMessage>[];
      for (final previous in history) {
        cancellationToken?.throwIfCancelled();
        preparedHistory.add(await prepareAiInput(previous, capabilities));
      }
      // Enforce the binary request limit across current and historical turns.
      prepareAiAttachments([...preparedHistory, preparedMessage]);
      final AiBuiltContext? context;
      try {
        context = await memory?.build(
          message: preparedMessage,
          history: preparedHistory,
          settings: settings,
          deferToRuntime: nativeContext,
        );
      } on StateError catch (error) {
        throw AiException(AiErrorCode.invalidRequest, error.message);
      }
      cancellationToken?.throwIfCancelled();
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
              settings,
              provider.capabilitiesFor(profile.modelId),
              // Reasoning and the answer share Ollama's prediction budget. Let
              // local chat finish naturally; Stop remains available.
              applyContextWindow: !nativeContext,
              applyOutputLimit:
                  profile.kind != AiProviderKind.ollama &&
                  profile.kind != AiProviderKind.offline,
            ),
            allowRemoteProcessing: preferences.allowOnlineProcessing,
            containsPrivateContext:
                containsPrivateContext ||
                (context?.excerpts.isNotEmpty ?? false),
            allowPrivateContextOnline: preferences.allowPrivateContextOnline,
            cancellationToken: cancellationToken,
            onPreparedMessages: onPreparedMessages,
          );
      await for (final event in events) {
        final response = event.response;
        if (response != null &&
            !response.thinkingOnly &&
            (context?.hits.isNotEmpty ?? false)) {
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
