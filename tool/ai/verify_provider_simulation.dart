import 'dart:io';

import 'package:metersystem/ai/ai.dart';
import 'package:metersystem/ai/providers/http/http_ai_provider.dart';

/// Runs real Dio adapters against the local Postman simulation, never vendors.
/// Start the simulation as documented in lib/ai/README.md, then:
/// dart run tool/ai/verify_provider_simulation.dart [http://127.0.0.1:4017/]
Future<void> main(List<String> args) async {
  final base = Uri.parse(args.isEmpty ? 'http://127.0.0.1:4017/' : args.single);
  if (!['localhost', '127.0.0.1', '::1'].contains(base.host)) {
    throw ArgumentError('Verification must target a loopback stand-in.');
  }
  const key = 'synthetic-test-key';
  final providers = <HttpAiProvider>[
    OpenAiProvider(baseUrl: base.resolve('openai/v1/'), credentials: () => key),
    GeminiProvider(
      baseUrl: base.resolve('gemini/v1beta/'),
      credentials: () => key,
    ),
    AnthropicProvider(
      baseUrl: base.resolve('anthropic/v1/'),
      credentials: () => key,
    ),
    OllamaProvider(baseUrl: base.resolve('ollama/api/')),
    CompatibleApiProvider(baseUrl: base.resolve('compatible/v1/')),
  ];
  final gateway = AiGateway(
    providers: providers,
    retryPolicy: AiRetryPolicy(maxAttempts: 1),
  );
  final orchestrator = AiOrchestrator(gateway: gateway);
  final history = <AiMessage>[];
  try {
    for (final provider in providers) {
      final connection = await gateway.testConnection(
        providerId: provider.id,
        allowRemoteProcessing: true,
      );
      if (!connection.isConnected) throw connection.error!;
      final models = await gateway.listModels(
        providerId: provider.id,
        allowRemoteProcessing: true,
      );
      if (models.models.isEmpty) {
        throw StateError('Expected discovered models.');
      }
      final message = AiMessage(
        role: AiRole.user,
        text: 'Continue in Urdu: اردو سوال',
      );
      final response = await orchestrator.send(
        selection: AiModelSelection(
          providerId: provider.id,
          modelId: 'test-chat',
        ),
        message: message,
        history: history,
        allowRemoteProcessing: true,
      );
      if (response.message.text != 'Hello — اردو جواب' ||
          response.usage.inputTokens != 12 ||
          response.usage.outputTokens != 5) {
        throw StateError('Provider response/usage was not normalized.');
      }
      history.addAll([message, response.message]);
      stdout.writeln(
        '${provider.id}: connection, discovery, generation and continued history passed',
      );
    }
  } finally {
    for (final provider in providers) {
      provider.close();
    }
  }
}
