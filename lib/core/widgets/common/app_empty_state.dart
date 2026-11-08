import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../theme/theme_x.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    this.accent,
    this.actionIcon = Icons.add_rounded,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;
  final Color? accent;
  final IconData actionIcon;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final effectiveAccent = accent ?? scheme.primary;
    final iconBackground = effectiveAccent.withOpacity(
      context.isDarkMode ? .20 : .11,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 56 : 72,
                height: compact ? 56 : 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: compact ? 28 : 34,
                  color: effectiveAccent,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: context.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.themeColors.neutral.textSecondary,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
