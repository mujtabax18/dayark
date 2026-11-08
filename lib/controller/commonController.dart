import 'package:flutter_riverpod/flutter_riverpod.dart';

// final sensitiveValueVisibilityProvider = StateProvider<bool>((ref) => false);
class VisibilityNotifier extends Notifier<bool> {
  // 1. The initial state is set in the build method.
  @override
  bool build() {
    return false;
  }

  // 2. Add methods to modify the state.
  void toggle() {
    state = !state;
  }

  void setVisibility(bool visible) {
    state = visible;
  }
}

// The provider is now a NotifierProvider that exposes the boolean state
final sensitiveValueVisibilityProvider =
    NotifierProvider<VisibilityNotifier, bool>(VisibilityNotifier.new);
