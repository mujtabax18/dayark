import 'dart:async';

import 'ai_cancellation.dart';
import 'ai_error.dart';

/// Scoped cancellation listeners: completed calls cannot cancel a later request.
Future<T> runAiOperation<T>(
  Future<T> Function(AiCancellationToken) operation,
  AiCancellationToken caller,
  Duration timeout,
) async {
  caller.throwIfCancelled();
  final attempt = AiCancellationToken();
  final result = Completer<T>();
  final remove = caller.onCancel(() {
    if (!result.isCompleted) {
      result.completeError(
        const AiException(AiErrorCode.cancelled, 'AI request cancelled.'),
      );
      attempt.cancel();
    }
  });
  final timer = Timer(timeout, () {
    if (!result.isCompleted) {
      result.completeError(
        const AiException(
          AiErrorCode.timeout,
          'AI provider timed out.',
          retryable: true,
        ),
      );
      attempt.cancel();
    }
  });
  Future<T>.sync(() => operation(attempt)).then(
    (value) {
      if (!result.isCompleted) result.complete(value);
    },
    onError: (Object error, StackTrace stack) {
      if (!result.isCompleted) result.completeError(error, stack);
    },
  );
  try {
    final value = await result.future;
    caller.throwIfCancelled();
    return value;
  } finally {
    timer.cancel();
    remove();
  }
}

Future<void> waitForAiRetry(Duration delay, AiCancellationToken token) async {
  token.throwIfCancelled();
  final done = Completer<void>();
  final timer = Timer(delay, () => done.complete());
  final remove = token.onCancel(() {
    if (!done.isCompleted) done.complete();
  });
  try {
    await done.future;
    token.throwIfCancelled();
  } finally {
    timer.cancel();
    remove();
  }
}
