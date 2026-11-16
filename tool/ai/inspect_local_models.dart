import 'dart:io';

import 'package:metersystem/ai/ai.dart';
import 'package:metersystem/ai/model_manager/native_models.dart';

/// No network traffic. Optional second argument benchmarks an installed GGUF.
/// dart run tool/ai/inspect_local_models.dart /model/destination [model.gguf]
Future<void> main(List<String> args) async {
  if (args.isEmpty || args.length > 2) {
    throw ArgumentError(
      'Provide the model destination directory and optionally a local GGUF path.',
    );
  }
  final hardware = await detectAiHardware(storagePath: args.first);
  String gib(int? bytes) =>
      bytes == null ? 'unknown' : '${(bytes / aiGiB).toStringAsFixed(2)} GiB';
  stdout.writeln(
    '${hardware.platform}: ${hardware.cpu} (${hardware.logicalCores} logical cores)',
  );
  stdout.writeln(
    'RAM: ${gib(hardware.availableMemoryBytes)} available / ${gib(hardware.totalMemoryBytes)} total',
  );
  stdout.writeln('Destination storage: ${gib(hardware.freeStorageBytes)} free');
  stdout.writeln(
    'GPU: ${hardware.gpu ?? 'unknown'}; VRAM: ${gib(hardware.vramBytes)}',
  );
  for (final note in hardware.notes) {
    stdout.writeln(note);
  }
  for (final recommendation in const AiModelRecommender().recommend(
    hardware,
    AiModelCatalogue.candidates(),
  )) {
    stdout.writeln(
      '${recommendation.model.name}: ${recommendation.fit.name} — ${recommendation.reasons.join(' ')}',
    );
  }
  if (args.length == 2) {
    final provider = OfflineAiProvider(
      models: [AiLocalModel(id: 'benchmark', path: args[1])],
    );
    try {
      final result = await benchmarkLocalModel(
        provider: provider,
        modelId: 'benchmark',
      );
      stdout.writeln(
        'Load: ${result.loadTime.inMilliseconds} ms; generation: ${result.elapsed.inMilliseconds} ms',
      );
      stdout.writeln(
        'Output: ${result.outputTokens ?? 'unknown'} tokens; ${result.outputTokensPerSecond?.toStringAsFixed(2) ?? 'unknown'} tokens/s',
      );
      stdout.writeln(
        'Process RSS: ${gib(result.rssBeforeBytes)} before, ${gib(result.rssAfterBytes)} after, ${gib(result.sampledPeakRssBytes)} sampled peak',
      );
    } finally {
      await provider.dispose();
    }
  }
}
