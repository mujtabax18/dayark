import '../../core/ai_stream.dart';

import 'dart:io';

import 'package:llamadart/llamadart.dart';

import '../../core/ai_cancellation.dart';
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

  @override
  Future<void> load(AiLocalModel model, AiCancellationToken token) async {
    token.throwIfCancelled();
    if (_path == model.path && _contextSize == model.contextSize) return;
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
    try {
      try {
        await engine.setModel(
          LlamaModel(ModelSource.path(model.path)),
          params: ModelParams(
            contextSize: model.contextSize,
            device: ComputeDevice.auto,
            // Android auto otherwise selects CPU even with Vulkan bundled.
            preferredBackend: Platform.isAndroid
                ? GpuBackend.vulkan
                : GpuBackend.auto,
            // Keep most layers on CPU instead of attempting full GPU residency.
            gpuLayers: Platform.isAndroid || Platform.isIOS ? 4 : 8,
          ),
        );
      } catch (_) {
        token.throwIfCancelled();
        // Retry driver, backend or VRAM failures without GPU allocations.
        await engine.setModel(
          LlamaModel(ModelSource.path(model.path)),
          params: ModelParams(
            contextSize: model.contextSize,
            device: ComputeDevice.cpu,
            gpuLayers: 0,
          ),
        );
      }
      token.throwIfCancelled();
      _path = model.path;
      _contextSize = model.contextSize;
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
    if (request.settings.contextWindowTokens != null &&
        request.settings.contextWindowTokens! != _contextSize) {
      throw const AiException(
        AiErrorCode.unsupportedCapability,
        'Context size must match the configured local model.',
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
      await for (final chunk in engine.create(
        messages,
        params: GenerationParams(
          temp: request.settings.temperature ?? 0.8,
          // llama.cpp's Dart loop requires a positive token count. This sentinel
          // removes the app's default output quota; EOS, native context and Stop govern completion.
          maxTokens: request.settings.maxOutputTokens ?? 0x7fffffff,
        ),
      )) {
        token.throwIfCancelled();
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
    await engine?.dispose();
  }
}
