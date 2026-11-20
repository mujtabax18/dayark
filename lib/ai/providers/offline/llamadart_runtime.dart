import '../../core/ai_stream.dart';
import '../../performance/performance_profile.dart';

import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;

import 'package:llamadart/llamadart.dart';

import '../../core/ai_cancellation.dart';
import '../../hardware/hardware_probe.dart';
import '../../model_manager/gguf_metadata.dart';
import '../../core/ai_error.dart';
import '../../models/ai_models.dart';
import '../../models/ai_request.dart';
import 'offline_runtime.dart';

AiOfflineRuntime createOfflineRuntime() => LlamadartRuntime();

/// Lazy local llama.cpp runtime with partial GPU offload and CPU fallback.
/// Own one instance per OfflineAiProvider. No downloads or network fallback.
class LlamadartRuntime implements AiOfflineRuntime, AiStreamingOfflineRuntime {
  LlamadartRuntime({LlamaEngine? engine})
    // ignore: prefer_initializing_formals
    : _engine = engine;

  LlamaEngine? _engine;
  String? _path;
  int? _contextSize;
  int? _configuredContext, _configuredGpuLayers;
  AiLocalModel? _model;
  int? _loadMilliseconds;

  @override
  Future<void> load(AiLocalModel model, AiCancellationToken token) async {
    token.throwIfCancelled();
    if (_path == model.path &&
        _configuredContext == model.contextSize &&
        _configuredGpuLayers == model.gpuLayers) {
      _loadMilliseconds = 0; // Warm request; no native reload took place.
      model.activeContextSize = _contextSize;
      if (!identical(_model, model)) {
        model.performance ??= _model?.performance;
        _model = model;
      }
      return;
    }
    if (!await File(model.path).exists()) {
      throw const AiException(
        AiErrorCode.providerUnavailable,
        'Local AI model file was not found.',
      );
    }
    token.throwIfCancelled();
    final engine = _engine ??= LlamaEngine(LlamaBackend());
    _path = null;
    _contextSize = null;
    _model?.activeContextSize = null;
    _model = null;
    final loadTimer = Stopwatch()..start();
    try {
      // Direct integrations (including the inspection tool) may omit the
      // context. Resolve it from the actual GGUF, never a catalogue default.
      var configured = model.contextSize;
      if (configured == null) {
        final metadata = await GgufMetadata.read(model.path);
        token.throwIfCancelled();
        final hardware = await detectAiHardware(
          storagePath: File(model.path).parent.path,
        );
        configured = metadata.chooseContext(
          hardware.availableMemoryBytes,
          hardware.totalMemoryBytes,
        );
      }
      // RAM capacity is a ceiling, not a reason to allocate huge KV caches.
      final int requestedContext = math.min(
        configured,
        model.contextSize ??
            (Platform.isAndroid || Platform.isIOS ? 4096 : 8192),
      );
      token.throwIfCancelled();
      try {
        await engine.setModel(
          LlamaModel(ModelSource.path(model.path)),
          params: ModelParams(
            contextSize: requestedContext,
            device: (model.gpuLayers ?? 0) > 0
                ? ComputeDevice.auto
                : ComputeDevice.cpu,
            // Android auto otherwise selects CPU even with Vulkan bundled.
            preferredBackend: Platform.isAndroid
                ? GpuBackend.vulkan
                : GpuBackend.auto,
            // Offload budget is derived from measured device resources and model layers.
            gpuLayers: model.gpuLayers ?? 0,
          ),
        );
      } catch (_) {
        token.throwIfCancelled();
        // Retry on CPU, reducing context if allocation still fails. This is
        // best-effort: a native OS out-of-memory kill cannot be caught here.
        var context = requestedContext;
        while (true) {
          try {
            await engine.setModel(
              LlamaModel(ModelSource.path(model.path)),
              params: ModelParams(
                contextSize: context,
                device: ComputeDevice.cpu,
                gpuLayers: 0,
              ),
            );
            break;
          } catch (_) {
            token.throwIfCancelled();
            final minimum = math.min(requestedContext, 256);
            if (context <= minimum) rethrow;
            context = math.max(minimum, context ~/ 2);
          }
        }
      }
      token.throwIfCancelled();
      _contextSize = await engine.getContextSize();
      if (_contextSize! <= 0) throw StateError('Invalid runtime context');
      _path = model.path;
      _configuredContext = model.contextSize;
      _configuredGpuLayers = model.gpuLayers;
      model.activeContextSize = _contextSize;
      _model = model;
      _loadMilliseconds = loadTimer.elapsedMilliseconds;
    } on AiException {
      rethrow;
    } catch (_) {
      token.throwIfCancelled();
      throw const AiException(
        AiErrorCode.providerUnavailable,
        'Unable to load the local model. Check the GGUF file, runtime and available memory.',
      );
    }
  }

  @override
  Future<AiResponse> generate(
    AiRequest request,
    AiCancellationToken token,
  ) async {
    AiResponse? response;
    await for (final event in stream(request, token)) {
      response = event.response ?? response;
    }
    return response!;
  }

  @override
  Stream<AiStreamEvent> stream(
    AiRequest request,
    AiCancellationToken token,
  ) async* {
    token.throwIfCancelled();
    final engine = _engine;
    if (engine == null || _path == null) {
      throw const AiException(
        AiErrorCode.providerUnavailable,
        'No local AI model is loaded.',
      );
    }
    final remove = token.onCancel(engine.cancelGeneration);
    try {
      yield const AiStreamEvent.activity(diagnostic: 'Processing prompt…');
      final buffer = StringBuffer();
      var hasThinking = false;
      String? finish;
      AiUsage usage = const AiUsage();
      final system = request.messages
          .where((m) => m.role == AiRole.system)
          .map((m) => m.text)
          .join('\n\n');
      final messages = [
        if (system.isNotEmpty)
          LlamaChatMessage.fromText(role: LlamaChatRole.system, text: system),
        for (final message in request.messages.where(
          (m) => m.role != AiRole.system,
        ))
          LlamaChatMessage.fromText(
            role: message.role == AiRole.assistant
                ? LlamaChatRole.assistant
                : LlamaChatRole.user,
            text: message.text,
          ),
      ];
      final thinking = request.settings.thinking ?? false;
      final profile =
          AiPerformanceProfile.values
              .where((p) => p.name == request.settings.performanceProfile)
              .firstOrNull ??
          AiPerformanceProfile.custom;
      final profileContext = profile == AiPerformanceProfile.custom
          ? null
          : profile
                .apply(
                  request.settings,
                  mobile: Platform.isAndroid || Platform.isIOS,
                )
                .contextWindowTokens;
      final contextSize = math.min(
        _contextSize!,
        profileContext ?? request.settings.contextWindowTokens ?? _contextSize!,
      );
      final outputBudget = math.min(
        request.settings.maxOutputTokens ?? 512,
        math.max(1, contextSize ~/ 2),
      );
      LlamaChatTemplateResult? lastTemplate;
      final fitted = await fitLocalChatContext(
        messages,
        contextSize: contextSize,
        outputTokens: outputBudget,
        countTokens: (candidate) async {
          token.throwIfCancelled();
          final template = await engine.chatTemplate(
            candidate,
            enableThinking: thinking,
          );
          lastTemplate = template;
          return template.tokenCount ??
              (await engine.tokenize(template.prompt)).length;
        },
      );
      final template = lastTemplate!;
      final promptTokens =
          template.tokenCount ??
          (await engine.tokenize(template.prompt)).length;
      final remaining = contextSize - promptTokens;
      if (remaining <= 0) {
        throw const AiException(
          AiErrorCode.invalidRequest,
          'No context remains for the response.',
        );
      }
      final timer = Stopwatch()..start();
      var peakRss = ProcessInfo.currentRss;
      final rssWatch = Stopwatch()..start();
      await for (final chunk in engine.create(
        fitted,
        enableThinking: thinking,
        params: GenerationParams(
          reusePromptPrefix: true,
          temp: request.settings.temperature ?? 0.8,
          // Bound output by the actual remaining context; EOS or Stop can end earlier.
          maxTokens: math.min(outputBudget, remaining),
        ),
      )) {
        token.throwIfCancelled();
        if (rssWatch.elapsedMilliseconds >= 500) {
          peakRss = math.max(peakRss, ProcessInfo.currentRss);
          rssWatch.reset();
        }
        if (chunk.thinking.isNotEmpty) {
          hasThinking = true;
          yield AiStreamEvent.activity(thinking: chunk.thinking);
        }
        buffer.write(chunk.text);
        if (chunk.text.isNotEmpty) yield AiStreamEvent.delta(chunk.text);
        if (chunk.choices.isNotEmpty &&
            chunk.choices.first.finishReason != null) {
          finish = chunk.choices.first.finishReason;
        }
        if (chunk.usage != null) {
          usage = AiUsage(
            inputTokens: chunk.usage!.promptTokens,
            outputTokens: chunk.usage!.completionTokens,
          );
        }
      }
      token.throwIfCancelled();
      if (buffer.toString().trim().isEmpty && !hasThinking) {
        throw const AiException(
          AiErrorCode.invalidResponse,
          'Local model returned no text.',
        );
      }
      timer.stop();
      final model = _model;
      if (model != null) {
        final count = usage.outputTokens;
        final speed =
            count != null && count > 0 && timer.elapsedMicroseconds > 0
            ? count * Duration.microsecondsPerSecond / timer.elapsedMicroseconds
            : null;
        model.performance = AiLocalPerformance(
          contextSize: _contextSize!,
          tokensPerSecond: speed,
          peakProcessRssBytes: peakRss,
          loadMilliseconds: _loadMilliseconds,
        );
        try {
          await File('${model.path}.perf').writeAsString(
            jsonEncode({
              'contextSize': _contextSize!,
              'tokensPerSecond': speed,
              'peakProcessRssBytes': peakRss,
              'loadMilliseconds': _loadMilliseconds,
            }),
          );
        } catch (_) {
          /* Telemetry persistence must not fail chat. */
        }
      }
      yield AiStreamEvent.completed(
        AiResponse(
          selection: request.selection,
          message: AiMessage(role: AiRole.assistant, text: buffer.toString()),
          usage: usage,
          finishReason: finish,
          thinkingOnly: buffer.toString().trim().isEmpty && hasThinking,
        ),
      );
    } on AiException {
      rethrow;
    } catch (_) {
      token.throwIfCancelled();
      throw const AiException(
        AiErrorCode.internal,
        'Local AI inference failed.',
      );
    } finally {
      remove();
    }
  }

  @override
  Future<void> dispose() async {
    final engine = _engine;
    _engine = null;
    _path = null;
    _contextSize = null;
    _configuredContext = null;
    _configuredGpuLayers = null;
    _model?.activeContextSize = null;
    _model = null;
    await engine?.dispose();
  }
}

/// Keep the current input intact. Only discard old turns after the loaded
/// model's rendered template and tokenizer show they no longer fit.
Future<List<LlamaChatMessage>> fitLocalChatContext(
  List<LlamaChatMessage> messages, {
  required int contextSize,
  int outputTokens = 1,
  required Future<int> Function(List<LlamaChatMessage>) countTokens,
}) async {
  final original = List<LlamaChatMessage>.of(messages);
  final fullCount = await countTokens(original);
  if (fullCount + outputTokens <= contextSize) return original;
  final system = messages.where((m) => m.role == LlamaChatRole.system).toList();
  final turns = messages.where((m) => m.role != LlamaChatRole.system).toList();
  final starts = [
    for (var i = 0; i < turns.length; i++)
      if (turns[i].role == LlamaChatRole.user) i,
  ];
  // The latest input is indivisible. Do not clip it to make a request fit.
  final latest = [...system, ...turns.skip(starts.isEmpty ? 0 : starts.last)];
  final latestCount = await countTokens(latest);
  if (latestCount + outputTokens > contextSize || starts.isEmpty) {
    throw AiException(
      AiErrorCode.invalidRequest,
      'The model tokenizer counted $latestCount input tokens for a $contextSize-token context. '
      '$outputTokens tokens are reserved for the answer. Shorten the input, reduce the output budget or increase context in model settings.',
    );
  }
  if (starts.length <= 2) return latest;
  // Search whole exchanges instead of retokenizing successively shorter full
  // histories. This bounds template/tokenizer calls logarithmically.
  var low = 1, high = starts.length - 2;
  var best = latest;
  var last = latest;
  while (low <= high) {
    final middle = (low + high) ~/ 2;
    final candidate = [...system, ...turns.skip(starts[middle])];
    last = candidate;
    if (await countTokens(candidate) + outputTokens <= contextSize) {
      best = candidate;
      high = middle - 1;
    } else {
      low = middle + 1;
    }
  }
  // Keep the runtime's final rendered template in sync with the returned list.
  if (!identical(last, best)) await countTokens(best);
  return best;
}
