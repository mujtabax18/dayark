import 'dart:async';

import '../../core/ai_cancellation.dart';
import '../../core/ai_capabilities.dart';
import '../../core/ai_error.dart';
import '../../core/ai_managed_provider.dart';
import '../../models/ai_models.dart';
import '../../models/ai_provider_models.dart';
import '../../models/ai_request.dart';
import 'offline_runtime.dart';
import 'unsupported_runtime.dart'
    if (dart.library.io) 'llamadart_runtime.dart'
    as native;

class OfflineAiProvider implements AiManagedProvider {
  OfflineAiProvider({
    this.id = 'offline',
    required Iterable<AiLocalModel> models,
    this._runtime,
  }) {
    if (id.trim().isEmpty) throw ArgumentError('Provider ID is required.');
    for (final model in models) {
      if (_models.containsKey(model.id)) {
        throw ArgumentError('Duplicate local model ID.');
      }
      _models[model.id] = model;
    }
  }
  @override
  final String id;
  @override
  bool get isRemote => false;
  final Map<String, AiLocalModel> _models = {};
  AiOfflineRuntime? _runtime;
  Future<void>? _active;
  AiCancellationToken? _activeToken;
  bool _closed = false;
  Future<void>? _disposal;

  @override
  AiCapabilities capabilitiesFor(String modelId) =>
      AiCapabilities(contextWindow: true);

  AiLocalModel _model(String? modelId) {
    final model = modelId == null
        ? _models.values.firstOrNull
        : _models[modelId];
    if (model == null) {
      throw const AiException(
        AiErrorCode.providerUnavailable,
        'Selected local AI model is not configured.',
      );
    }
    return model;
  }

  void _ensureOpen() {
    if (_closed) {
      throw const AiException(
        AiErrorCode.providerUnavailable,
        'Offline provider is closed.',
      );
    }
  }

  Future<T> _exclusive<T>(
    AiCancellationToken token,
    Future<T> Function(AiOfflineRuntime) operation,
  ) async {
    _ensureOpen();
    token.throwIfCancelled();
    if (_active != null) {
      throw const AiException(
        AiErrorCode.providerUnavailable,
        'Local AI engine is busy.',
      );
    }
    final done = Completer<void>();
    _active = done.future;
    _activeToken = token;
    try {
      return await operation(_runtime ??= native.createOfflineRuntime());
    } on AiException {
      rethrow;
    } catch (_) {
      token.throwIfCancelled();
      throw const AiException(
        AiErrorCode.internal,
        'Offline AI operation failed.',
      );
    } finally {
      _active = null;
      _activeToken = null;
      done.complete();
    }
  }

  @override
  Future<AiResponse> generate(
    AiRequest request, {
    required AiCancellationToken cancellationToken,
  }) => _exclusive(cancellationToken, (runtime) async {
    if (request.selection.providerId != id) {
      throw const AiException(
        AiErrorCode.invalidRequest,
        'Request selected another provider.',
      );
    }
    if (request.messages.any((m) => m.attachments.isNotEmpty)) {
      throw const AiException(
        AiErrorCode.unsupportedCapability,
        'Offline adapter currently accepts text only.',
      );
    }
    final model = _model(request.selection.modelId);
    if ((request.settings.contextWindowTokens != null &&
            request.settings.contextWindowTokens != model.contextSize) ||
        (request.settings.maxOutputTokens != null &&
            request.settings.maxOutputTokens! >= model.contextSize)) {
      throw const AiException(
        AiErrorCode.invalidRequest,
        'Settings exceed or differ from the configured local context.',
      );
    }
    await runtime.load(model, cancellationToken);
    cancellationToken.throwIfCancelled();
    return runtime.generate(request, cancellationToken);
  });

  @override
  Future<AiModelPage> listModels({
    String? cursor,
    required AiCancellationToken cancellationToken,
  }) async {
    _ensureOpen();
    cancellationToken.throwIfCancelled();
    if (cursor != null) {
      throw const AiException(
        AiErrorCode.invalidRequest,
        'Local model listing has no cursor.',
      );
    }
    return AiModelPage(
      models: _models.values.map(
        (model) => AiModelInfo(
          selection: AiModelSelection(providerId: id, modelId: model.id),
          name: model.name,
          capabilities: capabilitiesFor(model.id),
          inputTokenLimit: model.contextSize,
        ),
      ),
    );
  }

  @override
  Future<void> checkConnection({
    String? modelId,
    required AiCancellationToken cancellationToken,
  }) => _exclusive(cancellationToken, (runtime) async {
    await runtime.load(_model(modelId), cancellationToken);
    cancellationToken.throwIfCancelled();
  });

  /// Explicit loading uses the same exclusive engine ownership as generation.
  Future<void> loadModel(
    String modelId, {
    AiCancellationToken? cancellationToken,
  }) => checkConnection(
    modelId: modelId,
    cancellationToken: cancellationToken ?? AiCancellationToken(),
  );

  Future<void> unloadModel({AiCancellationToken? cancellationToken}) =>
      _exclusive(cancellationToken ?? AiCancellationToken(), (runtime) async {
        await runtime.dispose();
      });

  /// Serializes file replacement/deletion against native loading and inference.
  /// On failure the old registration survives and can be loaded again.
  Future<void> maintainModel(
    String modelId,
    Future<AiLocalModel?> Function() mutation, {
    AiCancellationToken? cancellationToken,
  }) => _exclusive(cancellationToken ?? AiCancellationToken(), (runtime) async {
    await runtime.dispose();
    final replacement = await mutation();
    if (replacement != null && replacement.id != modelId) {
      throw ArgumentError('Replacement model ID differs.');
    }
    if (replacement == null) {
      _models.remove(modelId);
    } else {
      _models[modelId] = replacement;
    }
  });

  /// Waits for cancelled native work to settle before releasing its memory.
  Future<void> dispose() => _disposal ??= _dispose();
  Future<void> _dispose() async {
    _closed = true;
    _activeToken?.cancel();
    await _active;
    await _runtime?.dispose();
  }
}
