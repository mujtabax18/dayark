import 'package:flutter/foundation.dart';

/// App-wide signal used after destructive database operations or full restores.
///
/// The database itself is a singleton, while Riverpod providers and Stateful
/// widgets can keep successfully loaded rows in memory. Bumping this signal
/// recreates the application data ProviderScope so every database-backed
/// provider and screen-local selection starts from the current database state.
class AppDataResetSignal {
  AppDataResetSignal._();

  static final AppDataResetSignal instance = AppDataResetSignal._();

  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  void notifyReset() {
    revision.value = revision.value + 1;
  }
}
