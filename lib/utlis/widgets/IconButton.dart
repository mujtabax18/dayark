import 'package:flutter/material.dart';

class CustomIconButton extends StatelessWidget {
  const CustomIconButton({
    super.key,
    this.onTap,
    this.padding,
    this.margin,
    this.decoration,
    this.icon,
    this.label,
    this.labelStyle,
    this.spacing,
  });

  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BoxDecoration? decoration;
  final IconData? icon;
  final String? label;
  final TextStyle? labelStyle;
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(14);

    return Padding(
      padding: margin ?? const EdgeInsets.all(8),
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: decoration ??
              BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: radius,
              ),
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: padding ?? const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) Icon(icon, color: scheme.primary),
                  if (icon != null && label != null)
                    SizedBox(height: spacing ?? 6),
                  if (label != null)
                    Text(
                      label!,
                      style: labelStyle ?? Theme.of(context).textTheme.labelMedium,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
