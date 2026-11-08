import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controller/commonController.dart';

class EyeIconButton extends ConsumerWidget {
  const EyeIconButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVisible = ref.watch(sensitiveValueVisibilityProvider);

    return IconButton(
      icon: Icon(
        isVisible ? Icons.lock : Icons.lock_open,
        size: 20,
      ),
      onPressed: () {
        ref.read(sensitiveValueVisibilityProvider.notifier).state = !isVisible;
      },
    );
  }
}
