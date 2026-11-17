import 'dart:convert';
import 'dart:io';

import 'package:metersystem/ai/ai.dart';

/// Runs fixed multilingual prompts against an installed GGUF without downloading.
/// dart run tool/ai/benchmark_release.dart /path/model.gguf /path/results.json
/// Results require human quality review; successful generation alone is not a pass.
Future<void> main(List<String> args) async {
  if (args.length != 2 || !File(args.first).existsSync()) {
    stderr.writeln(
      'Usage: dart run tool/ai/benchmark_release.dart installed.gguf results.json',
    );
    exitCode = 64;
    return;
  }
  final provider = OfflineAiProvider(
    models: [
      AiLocalModel(
        id: 'release-benchmark',
        path: args.first,
        contextSize: 4096,
      ),
    ],
  );
  final assistant = AiOrchestrator(
    gateway: AiGateway(
      providers: [provider],
      retryPolicy: AiRetryPolicy.localInference(),
    ),
  );
  final cases = [
    ('English', 'Explain in two short sentences why a daily plan is useful.'),
    (
      'Urdu',
      'دو مختصر جملوں میں بتائیں کہ روزانہ کی منصوبہ بندی کیوں مفید ہے۔',
    ),
    (
      'Roman Urdu',
      'Do chhotay jumlon mein batao ke rozana ki planning kyun faidemand hai.',
    ),
  ];
  final results = <Map<String, Object?>>[];
  try {
    for (final item in cases) {
      final watch = Stopwatch()..start();
      try {
        final response = await assistant.send(
          selection: AiModelSelection(
            providerId: provider.id,
            modelId: 'release-benchmark',
          ),
          message: AiMessage(role: AiRole.user, text: item.$2),
          settings: AiSettings(
            maxOutputTokens: 192,
            contextWindowTokens: 4096,
            temperature: .2,
            responseLanguage: item.$1,
          ),
        );
        watch.stop();
        results.add({
          'language': item.$1,
          'prompt': item.$2,
          'answer': response.message.text,
          'elapsedMs': watch.elapsedMilliseconds,
          'outputTokens': response.usage.outputTokens,
          'qualityReview': 'pending',
        });
      } on AiException catch (error) {
        watch.stop();
        results.add({
          'language': item.$1,
          'prompt': item.$2,
          'elapsedMs': watch.elapsedMilliseconds,
          'error': error.code.name,
          'qualityReview': 'blocked',
        });
        exitCode = 1;
      }
    }
  } finally {
    await provider.dispose();
  }
  final output = File(args[1]);
  await output.parent.create(recursive: true);
  await output.writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'timeUtc': DateTime.now().toUtc().toIso8601String(),
      'platform': Platform.operatingSystem,
      'modelPath': File(args.first).absolute.path,
      'modelBytes': await File(args.first).length(),
      'includesColdLoad': true,
      'releaseAccepted': false,
      'results': results,
    }),
  );
  stdout.writeln(
    'Benchmark saved to ${output.path}. Review language, accuracy and latency before acceptance.',
  );
}
