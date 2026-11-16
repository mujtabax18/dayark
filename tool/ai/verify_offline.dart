import 'dart:io';

import 'package:metersystem/ai/ai.dart';

/// Manual native smoke test, with an already-installed GGUF. Never downloads.
/// dart run tool/ai/verify_offline.dart /absolute/path/to/instruct.gguf
Future<void> main(List<String> args) async {
  if (args.length != 1) throw ArgumentError('Provide a local GGUF model path.');
  final provider = OfflineAiProvider(
    models: [
      AiLocalModel(id: 'smoke-test', path: args.single, contextSize: 2048),
    ],
  );
  final gateway = AiGateway(
    providers: [provider],
    retryPolicy: AiRetryPolicy(
      maxAttempts: 1,
      attemptTimeout: const Duration(minutes: 3),
    ),
  );
  try {
    final connection = await gateway.testConnection(providerId: 'offline');
    if (!connection.isConnected) throw connection.error!;
    final reply = await AiOrchestrator(gateway: gateway).send(
      selection: AiModelSelection(providerId: 'offline', modelId: 'smoke-test'),
      message: AiMessage(
        role: AiRole.user,
        text: 'Say hello in one short sentence.',
      ),
      settings: AiSettings(maxOutputTokens: 32),
    );
    stdout.writeln(reply.message.text);
    stdout.writeln('Embedded offline generation passed.');
  } finally {
    await provider.dispose();
  }
}
