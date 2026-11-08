import 'package:flutter/material.dart';

/// Keeps feature pages comfortable on large desktop windows without changing
/// their existing phone/tablet layout or feature behavior.
class DesktopContentFrame extends StatelessWidget {
  const DesktopContentFrame({
    super.key,
    required this.child,
    this.maxWidth = 1320,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 1100) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth > maxWidth
            ? maxWidth
            : constraints.maxWidth;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            height: constraints.maxHeight,
            child: child,
          ),
        );
      },
    );
  }
}
