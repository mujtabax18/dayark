import '../core/ai_stream.dart';
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
  const AiConfiguredAssistant(this.store);
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
      yield* AiOrchestrator(
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
        message: prepareAiAttachments([message]).single,
        history: prepareAiAttachments(history),
        settings: settingsForCapabilities(
          preferences.settings,
          provider.capabilitiesFor(profile.modelId),
        ),
        allowRemoteProcessing: preferences.allowOnlineProcessing,
        containsPrivateContext: containsPrivateContext,
        allowPrivateContextOnline: preferences.allowPrivateContextOnline,
        cancellationToken: cancellationToken,
      );
    } finally {
      if (provider is HttpAiProvider) provider.close();
    }
  }
}
