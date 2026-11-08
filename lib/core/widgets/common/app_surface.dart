import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../theme/theme_x.dart';

enum AppSurfaceLevel { page, card, raised, muted }

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.level = AppSurfaceLevel.card,
    this.padding,
    this.margin,
    this.borderRadius,
    this.border = true,
    this.clipBehavior = Clip.antiAlias,
    this.onTap,
  });

  final Widget child;
  final AppSurfaceLevel level;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final bool border;
  final Clip clipBehavior;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final radius = borderRadius ?? AppRadius.large;
    final background = switch (level) {
      AppSurfaceLevel.page => context.themeColors.neutral.background,
      AppSurfaceLevel.card => scheme.surfaceContainerLow,
      AppSurfaceLevel.raised => scheme.surfaceContainerHigh,
      AppSurfaceLevel.muted => scheme.surfaceContainerHighest,
    };

    final content = Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: border
            ? BorderSide(color: scheme.outlineVariant)
            : BorderSide.none,
      ),
      clipBehavior: clipBehavior,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );

    if (margin == null) return content;
    return Padding(padding: margin!, child: content);
  }
}
