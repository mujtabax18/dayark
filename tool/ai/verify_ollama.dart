import 'dart:io';

import 'package:metersystem/ai/ai.dart';

/// Local-only smoke test. Uses the actual gateway, prompts and Ollama adapter.
/// dart run tool/ai/verify_ollama.dart [model-id]
Future<void> main(List<String> args) async {
  final model = args.isEmpty ? 'qwen3.5:2b' : args.single;
  final provider = OllamaProvider();
  final gateway = AiGateway(
    providers: [provider],
    retryPolicy: AiRetryPolicy.localInference(),
  );
  final watch = Stopwatch()..start();
  AiResponse? result;
  var first = true;
  try {
    await for (final event in AiOrchestrator(gateway: gateway).stream(
      selection: AiModelSelection(providerId: provider.id, modelId: model),
      message: AiMessage(
        role: AiRole.user,
        text: 'Reply with a single short greeting.',
      ),
      settings: AiSettings(
        maxOutputTokens: 128,
        contextWindowTokens: 4096,
        temperature: .2,
        thinking: false,
      ),
      allowRemoteProcessing: true,
    )) {
      if (first) {
        stdout.writeln('First model activity: ${watch.elapsedMilliseconds} ms');
        first = false;
      }
      result = event.response ?? result;
    }
    if (result == null || result.message.text.trim().isEmpty) {
      throw StateError('No complete reply.');
    }
    stdout.writeln(
      'Model: $model\nReply: ${result.message.text}\nElapsed: ${watch.elapsedMilliseconds} ms\nFinish: ${result.finishReason}',
    );
  } finally {
    provider.close();
  }
}
