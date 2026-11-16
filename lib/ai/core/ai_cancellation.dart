import 'dart:async';

import 'ai_error.dart';

/// One token per operation. Adapters should stop native/network work on cancel.
class AiCancellationToken {
  final Completer<void> _cancelled = Completer<void>();
  bool get isCancelled => _cancelled.isCompleted;
  Future<void> get whenCancelled => _cancelled.future;
  void cancel() {
    if (!isCancelled) _cancelled.complete();
  }

  void throwIfCancelled() {
    if (isCancelled) {
      throw const AiException(AiErrorCode.cancelled, 'AI request cancelled.');
    }
  }
}
