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
    bool containsPrivateContext = false,
    AiCancellationToken? cancellationToken,
  }) async {
    final preferences = store.load();
    final profile = preferences.selectedProfile;
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
      return await AiOrchestrator(gateway: AiGateway(providers: [provider]))
          .send(
            selection: AiModelSelection(
              providerId: provider.id,
              modelId: profile.modelId,
            ),
            message: message,
            history: history,
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
