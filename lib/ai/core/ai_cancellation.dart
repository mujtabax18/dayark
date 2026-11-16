import 'dart:async';

import 'ai_error.dart';

/// One token per operation. Adapters should stop native/network work on cancel.
class AiCancellationToken {
  final Completer<void> _cancelled = Completer<void>();
  final Set<void Function()> _listeners = {};

  /// Returns a disposer; adapters must call it when their operation ends.
  void Function() onCancel(void Function() listener) {
    if (isCancelled) {
      listener();
      return () {};
    }
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  bool get isCancelled => _cancelled.isCompleted;
  Future<void> get whenCancelled => _cancelled.future;
  void cancel() {
    if (isCancelled) return;
    _cancelled.complete();
    final listeners = List<void Function()>.of(_listeners);
    _listeners.clear();
    for (final listener in listeners) {
      try {
        listener();
      } catch (_) {
        // One adapter's cleanup failure must not prevent other cancellation.
      }
    }
  }

  void throwIfCancelled() {
    if (isCancelled) {
      throw const AiException(AiErrorCode.cancelled, 'AI request cancelled.');
    }
  }
}
