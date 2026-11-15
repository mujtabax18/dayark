import 'package:flutter/foundation.dart';

/// Lightweight notification for open archive screens after remote commits.
class SyncContentSignal {
  SyncContentSignal._();
  static final revision = ValueNotifier<int>(0);
  static void notify() {
    revision.value++;
  }
}
