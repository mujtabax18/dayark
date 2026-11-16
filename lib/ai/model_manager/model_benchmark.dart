import 'dart:async';
import 'dart:io';

import '../core/ai_cancellation.dart';
import '../models/ai_models.dart';
import '../models/ai_request.dart';
import '../providers/offline/offline_provider.dart';
import '../settings/ai_settings.dart';

class AiModelBenchmarkResult {
  const AiModelBenchmarkResult({
    required this.selection,
    required this.loadTime,
    required this.elapsed,
    required this.outputTokens,
    required this.rssBeforeBytes,
    required this.rssAfterBytes,
    required this.sampledPeakRssBytes,
  });
  final AiModelSelection selection;
  final Duration loadTime, elapsed;
  final int? outputTokens;

  /// Process-wide resident memory, not model-only allocations or GPU memory.
  final int rssBeforeBytes, rssAfterBytes, sampledPeakRssBytes;

  /// End-to-end generation throughput includes prompt evaluation.
  double? get outputTokensPerSecond =>
      outputTokens == null || elapsed.inMicroseconds == 0
      ? null
      : outputTokens! * Duration.microsecondsPerSecond / elapsed.inMicroseconds;
}

/// Explicit local benchmark; never downloads or calls an online provider.
/// The model stays loaded on completion. Prompts may be English, Urdu or Roman Urdu.
Future<AiModelBenchmarkResult> benchmarkLocalModel({
  required OfflineAiProvider provider,
  required String modelId,
  String prompt = 'Explain in three sentences how to plan a productive day.',
  int maxOutputTokens = 128,
  AiCancellationToken? cancellationToken,
}) async {
  final token = cancellationToken ?? AiCancellationToken();
  final request = AiRequest(
    selection: AiModelSelection(providerId: provider.id, modelId: modelId),
    messages: [AiMessage(role: AiRole.user, text: prompt)],
    settings: AiSettings(temperature: 0, maxOutputTokens: maxOutputTokens),
  );
  final before = ProcessInfo.currentRss;
  var peak = before;
  void sample() {
    final rss = ProcessInfo.currentRss;
    if (rss > peak) peak = rss;
  }

  final sampling = Timer.periodic(
    const Duration(milliseconds: 25),
    (_) => sample(),
  );
  try {
    final load = Stopwatch()..start();
    await provider.loadModel(modelId, cancellationToken: token);
    load.stop();
    sample();
    final inference = Stopwatch()..start();
    final response = await provider.generate(request, cancellationToken: token);
    inference.stop();
    sample();
    return AiModelBenchmarkResult(
      selection: request.selection,
      loadTime: load.elapsed,
      elapsed: inference.elapsed,
      outputTokens: response.usage.outputTokens,
      rssBeforeBytes: before,
      rssAfterBytes: ProcessInfo.currentRss,
      sampledPeakRssBytes: peak,
    );
  } finally {
    sampling.cancel();
  }
}
