import 'dart:io';

import 'package:llamadart/llamadart.dart';

import '../../core/ai_cancellation.dart';
import '../../core/ai_error.dart';
import '../../models/ai_models.dart';
import '../../models/ai_request.dart';
import 'offline_runtime.dart';

AiOfflineRuntime createOfflineRuntime() => LlamadartRuntime();

/// CPU llama.cpp runtime, created lazily and used only with local file sources.
/// Own one instance per OfflineAiProvider. No downloads or network fallback.
class LlamadartRuntime implements AiOfflineRuntime {
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
      await engine.setModel(
        LlamaModel(ModelSource.path(model.path)),
        params: ModelParams(
          contextSize: model.contextSize,
          device: ComputeDevice.cpu,
          gpuLayers: 0,
        ),
      );
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
          maxTokens: request.settings.maxOutputTokens ?? 1024,
        ),
      )) {
        token.throwIfCancelled();
        buffer.write(chunk.text);
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
      if (buffer.toString().trim().isEmpty) {
        throw const AiException(
          AiErrorCode.invalidResponse,
          'Local model returned no text.',
        );
      }
      return AiResponse(
        selection: request.selection,
        message: AiMessage(role: AiRole.assistant, text: buffer.toString()),
        usage: usage,
        finishReason: finish,
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
