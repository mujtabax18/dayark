import '../../core/ai_stream.dart';

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
  int? _configuredContext;
  AiLocalModel? _model;
  int? _loadMilliseconds;

  @override
  Future<void> load(AiLocalModel model, AiCancellationToken token) async {
    token.throwIfCancelled();
    if (_path == model.path && _configuredContext == model.contextSize) {
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
      final int requestedContext = configured;
      token.throwIfCancelled();
      try {
        await engine.setModel(
          LlamaModel(ModelSource.path(model.path)),
          params: ModelParams(
            contextSize: requestedContext,
            device: (model.gpuLayers ?? 0) > 0 ? ComputeDevice.auto : ComputeDevice.cpu,
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
              params: ModelParams(contextSize: context, device: ComputeDevice.cpu, gpuLayers: 0),
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
      final fitted = await fitLocalChatContext(
        messages,
        contextSize: _contextSize!,
        countTokens: (candidate) async {
          token.throwIfCancelled();
          final template = await engine.chatTemplate(candidate);
          return template.tokenCount ??
              (await engine.tokenize(template.prompt)).length;
        },
      );
      final template = await engine.chatTemplate(fitted);
      final promptTokens = template.tokenCount ?? (await engine.tokenize(template.prompt)).length;
      final remaining = _contextSize! - promptTokens;
      if (remaining <= 0) throw const AiException(AiErrorCode.invalidRequest, 'No context remains for the response.');
      final timer = Stopwatch()..start();
      var peakRss = ProcessInfo.currentRss;
      await for (final chunk in engine.create(
        fitted,
        params: GenerationParams(
          temp: request.settings.temperature ?? 0.8,
          // Bound output by the actual remaining context; EOS or Stop can end earlier.
          maxTokens: math.min(request.settings.maxOutputTokens ?? remaining, remaining),
        ),
      )) {
        token.throwIfCancelled();
        peakRss = math.max(peakRss, ProcessInfo.currentRss);
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
        final speed = count != null && count > 0 && timer.elapsedMicroseconds > 0
            ? count * Duration.microsecondsPerSecond / timer.elapsedMicroseconds : null;
        model.performance = AiLocalPerformance(contextSize: _contextSize!, tokensPerSecond: speed,
          peakProcessRssBytes: peakRss, loadMilliseconds: _loadMilliseconds);
        try {
          await File('${model.path}.perf').writeAsString(jsonEncode({
            'contextSize': _contextSize!, 'tokensPerSecond': speed,
            'peakProcessRssBytes': peakRss, 'loadMilliseconds': _loadMilliseconds,
          }));
        } catch (_) { /* Telemetry persistence must not fail chat. */ }
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
  required Future<int> Function(List<LlamaChatMessage>) countTokens,
}) async {
  final fitted = List<LlamaChatMessage>.of(messages);
  while (true) {
    final tokens = await countTokens(fitted);
    if (tokens < contextSize) return fitted;
    final first = fitted.indexWhere((m) => m.role != LlamaChatRole.system);
    if (first < 0 || first == fitted.length - 1) {
      throw AiException(
        AiErrorCode.invalidRequest,
        'The model tokenizer counted $tokens input tokens for a $contextSize-token context. '
        'Shorten the input or turn off the additional prompt in AI settings.',
      );
    }
    fitted.removeAt(first);
    // Do not leave an orphaned assistant turn at the start of the chat.
    while (first < fitted.length - 1 &&
        fitted[first].role == LlamaChatRole.assistant) {
      fitted.removeAt(first);
    }
  }
}
