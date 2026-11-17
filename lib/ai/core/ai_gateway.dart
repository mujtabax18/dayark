import 'ai_attachments.dart';

import 'dart:async';

import 'ai_stream.dart';
import '../models/ai_models.dart';
import '../models/ai_request.dart';
import '../models/ai_provider_models.dart';
import 'ai_managed_provider.dart';
import 'ai_operation.dart';
import 'ai_cancellation.dart';
import 'ai_error.dart';
import 'ai_provider.dart';

class AiRetryPolicy {
  AiRetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 250),
    this.attemptTimeout = const Duration(seconds: 60),
    this.waitForLocalStream = false,
    Duration? initialStreamTimeout,
    Duration? streamInactivityTimeout,
  }) : initialStreamTimeout = initialStreamTimeout ?? attemptTimeout,
       streamInactivityTimeout = streamInactivityTimeout ?? attemptTimeout {
    if (maxAttempts < 1 ||
        maxAttempts > 10 ||
        initialDelay.isNegative ||
        attemptTimeout <= Duration.zero ||
        this.initialStreamTimeout <= Duration.zero ||
        this.streamInactivityTimeout <= Duration.zero) {
      throw ArgumentError('Invalid AI retry policy.');
    }
  }

  /// Disable stream timers for local inference; caller cancellation still applies.
  final bool waitForLocalStream;
  final int maxAttempts;
  final Duration initialDelay;
  final Duration attemptTimeout;
  final Duration initialStreamTimeout, streamInactivityTimeout;
  factory AiRetryPolicy.localInference() => AiRetryPolicy(
    waitForLocalStream: true,
    initialStreamTimeout: const Duration(minutes: 5),
    streamInactivityTimeout: const Duration(minutes: 2),
  );
}

/// The only communication path to AI providers. Does not access app data.
class AiGateway {
  AiGateway({
    required Iterable<AiProvider> providers,
    AiRetryPolicy? retryPolicy,
  }) : retryPolicy = retryPolicy ?? AiRetryPolicy() {
    for (final provider in providers) {
      if (provider.id.trim().isEmpty || _providers.containsKey(provider.id)) {
        throw ArgumentError('Provider IDs must be nonempty and unique.');
      }
      _providers[provider.id] = provider;
    }
  }
  final Map<String, AiProvider> _providers = {};
  final AiRetryPolicy retryPolicy;

  Future<AiResponse> generate(
    AiRequest request, {
    AiCancellationToken? cancellationToken,
  }) async {
    final token = cancellationToken ?? AiCancellationToken();
    token.throwIfCancelled();
    final provider = _validate(request);
    for (var attempt = 0; attempt < retryPolicy.maxAttempts; attempt++) {
      token.throwIfCancelled();
      try {
        final response = await runAiOperation(
          (attemptToken) =>
              provider.generate(request, cancellationToken: attemptToken),
          token,
          retryPolicy.attemptTimeout,
        );
        token.throwIfCancelled();
        if (response.selection.providerId != request.selection.providerId ||
            response.selection.modelId != request.selection.modelId) {
          throw const AiException(
            AiErrorCode.invalidResponse,
            'AI provider returned a response for another model.',
          );
        }
        return response;
      } catch (error) {
        token.throwIfCancelled();
        final failure = error is AiException
            ? error
            : const AiException(AiErrorCode.internal, 'AI provider failed.');
        if (!failure.retryable ||
            failure.code == AiErrorCode.cancelled ||
            attempt + 1 == retryPolicy.maxAttempts) {
          throw failure;
        }
      }
      await waitForAiRetry(retryPolicy.initialDelay * (1 << attempt), token);
    }
    throw StateError('Unreachable retry state.');
  }

  AiProvider _validate(AiRequest request) {
    final provider = _providers[request.selection.providerId];
    if (provider == null) {
      throw const AiException(
        AiErrorCode.providerUnavailable,
        'Selected AI provider is unavailable.',
      );
    }
    if (provider.isRemote &&
        (!request.allowRemoteProcessing ||
            (request.containsPrivateContext &&
                !request.allowPrivateContextOnline))) {
      throw const AiException(
        AiErrorCode.permissionDenied,
        'Remote AI processing requires explicit authorization.',
      );
    }
    try {
      final capabilities = provider.capabilitiesFor(request.selection.modelId);
      if (request.messages.fold<int>(0, (sum, m) => sum + m.text.length) >
          4 * 1024 * 1024) {
        throw const AiException(
          AiErrorCode.invalidRequest,
          'This conversation is too large. Start a new chat.',
        );
      }
      final settings = request.settings;
      if ((settings.temperature != null &&
              (!capabilities.temperature ||
                  (capabilities.maxTemperature != null &&
                      settings.temperature! > capabilities.maxTemperature!))) ||
          (settings.maxOutputTokens != null &&
              !capabilities.outputTokenLimit) ||
          (settings.contextWindowTokens != null &&
              !capabilities.contextWindow) ||
          (settings.thinking != null && !capabilities.thinking) ||
          request.messages
              .expand((m) => m.attachments)
              .any(
                (a) =>
                    !isAiTextDocument(a) &&
                    !capabilities.attachments.contains(a.kind),
              )) {
        throw const AiException(
          AiErrorCode.unsupportedCapability,
          'The selected model does not support the requested input or settings.',
        );
      }
    } on AiException {
      rethrow;
    } catch (_) {
      throw const AiException(
        AiErrorCode.invalidRequest,
        'Unable to validate the selected model.',
      );
    }
    return provider;
  }

  /// Streams are never replayed automatically after exposing provisional output.
  Stream<AiStreamEvent> stream(
    AiRequest request, {
    AiCancellationToken? cancellationToken,
  }) async* {
    final token = cancellationToken ?? AiCancellationToken();
    token.throwIfCancelled();
    final provider = _validate(request);
    if (provider is! AiStreamingProvider) {
      final response = await generate(request, cancellationToken: token);
      yield AiStreamEvent.completed(response);
      return;
    }
    final streamToken = AiCancellationToken();
    final remove = token.onCancel(streamToken.cancel);
    final iterator = StreamIterator<AiStreamEvent>(
      (provider as AiStreamingProvider).stream(
        request,
        cancellationToken: streamToken,
      ),
    );
    var completed = false;
    var receivedEvent = false;
    final text = StringBuffer();
    try {
      while (await runAiOperation(
        (attempt) {
          final detach = attempt.onCancel(streamToken.cancel);
          return iterator.moveNext().whenComplete(detach);
        },
        token,
        retryPolicy.waitForLocalStream
            ? null
            : receivedEvent
            ? retryPolicy.streamInactivityTimeout
            : retryPolicy.initialStreamTimeout,
      )) {
        receivedEvent = true;
        token.throwIfCancelled();
        final event = iterator.current;
        if (completed) {
          throw const AiException(
            AiErrorCode.invalidResponse,
            'Unexpected data after the final response.',
          );
        }
        if (event.response case final response?) {
          if (response.selection.providerId != request.selection.providerId ||
              response.selection.modelId != request.selection.modelId ||
              (text.isNotEmpty && text.toString() != response.message.text)) {
            throw const AiException(
              AiErrorCode.invalidResponse,
              'Stream response did not match the selected model or text.',
            );
          }
          completed = true;
        } else {
          text.write(event.text);
          if (text.length > 4 * 1024 * 1024) {
            throw const AiException(
              AiErrorCode.invalidResponse,
              'AI response exceeds the supported size.',
            );
          }
        }
        yield event;
      }
      if (!completed) {
        throw const AiException(
          AiErrorCode.invalidResponse,
          'AI response was interrupted before completion.',
        );
      }
    } on AiException {
      rethrow;
    } catch (_) {
      token.throwIfCancelled();
      throw const AiException(
        AiErrorCode.invalidResponse,
        'Unable to read the AI response stream.',
      );
    } finally {
      remove();
      streamToken.cancel();
      // Cancellation cleanup must not replace a timeout or provider error.
      try {
        await iterator.cancel();
      } catch (_) {}
    }
  }

  AiManagedProvider _managed(String providerId, bool allowRemoteProcessing) {
    final provider = _providers[providerId];
    if (provider == null) {
      throw const AiException(
        AiErrorCode.providerUnavailable,
        'Selected AI provider is unavailable.',
      );
    }
    if (provider.isRemote && !allowRemoteProcessing) {
      throw const AiException(
        AiErrorCode.permissionDenied,
        'Remote AI processing requires explicit authorization.',
      );
    }
    if (provider is! AiManagedProvider) {
      throw const AiException(
        AiErrorCode.unsupportedCapability,
        'Provider management is unavailable.',
      );
    }
    return provider;
  }

  Future<AiModelPage> listModels({
    required String providerId,
    String? cursor,
    bool allowRemoteProcessing = false,
    AiCancellationToken? cancellationToken,
  }) async {
    final token = cancellationToken ?? AiCancellationToken();
    token.throwIfCancelled();
    final provider = _managed(providerId, allowRemoteProcessing);
    try {
      return await runAiOperation(
        (attempt) =>
            provider.listModels(cursor: cursor, cancellationToken: attempt),
        token,
        retryPolicy.attemptTimeout,
      );
    } on AiException {
      rethrow;
    } catch (_) {
      throw const AiException(
        AiErrorCode.internal,
        'AI model discovery failed.',
      );
    }
  }

  Future<AiConnectionResult> testConnection({
    required String providerId,
    String? modelId,
    bool allowRemoteProcessing = false,
    AiCancellationToken? cancellationToken,
  }) async {
    final token = cancellationToken ?? AiCancellationToken();
    try {
      token.throwIfCancelled();
      final provider = _managed(providerId, allowRemoteProcessing);
      await runAiOperation(
        (attempt) => provider.checkConnection(
          modelId: modelId,
          cancellationToken: attempt,
        ),
        token,
        retryPolicy.attemptTimeout,
      );
      return const AiConnectionResult.connected();
    } on AiException catch (error) {
      if (error.code == AiErrorCode.cancelled) rethrow;
      return AiConnectionResult.failed(error);
    } catch (_) {
      return const AiConnectionResult.failed(
        AiException(AiErrorCode.internal, 'AI connection test failed.'),
      );
    }
  }
}
