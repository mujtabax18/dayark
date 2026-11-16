/// Standalone AI foundation. No provider is registered or activated by default.
library;

export 'core/ai_cancellation.dart';
export 'core/ai_capabilities.dart';
export 'core/ai_error.dart';
export 'core/ai_gateway.dart';
export 'core/ai_orchestrator.dart';
export 'core/ai_provider.dart';
export 'models/ai_models.dart';
export 'models/ai_request.dart';
export 'prompts/prompt_manager.dart';
export 'settings/ai_settings.dart';
export 'core/ai_managed_provider.dart';
export 'models/ai_provider_models.dart';
export 'providers/http/ai_http_transport.dart' show AiCredentialLoader;
export 'providers/http/openai_provider.dart';
export 'providers/http/gemini_provider.dart';
export 'providers/http/anthropic_provider.dart';
export 'providers/http/ollama_provider.dart';
export 'providers/http/compatible_provider.dart';
export 'providers/offline/offline_provider.dart';
export 'providers/offline/offline_runtime.dart';
export 'hardware/ai_hardware.dart';
export 'hardware/hardware_probe.dart';
export 'model_manager/model_catalogue.dart';
export 'model_manager/native_models_stub.dart'
    if (dart.library.io) 'model_manager/native_models.dart';
