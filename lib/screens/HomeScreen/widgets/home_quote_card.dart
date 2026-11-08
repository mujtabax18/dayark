import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_tokens.dart';
import '../../../models/quotation.dart';
import '../../../utlis/app_router.dart';
import '../controller/home_quote_provider.dart';

class HomeQuoteCard extends ConsumerWidget {
  const HomeQuoteCard({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quote = ref.watch(homeQuoteProvider);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.large,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(RoutesStr.quotes),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: AppRadius.large,
            border: Border.all(color: scheme.outlineVariant),
            gradient: LinearGradient(
              colors: [
                scheme.primaryContainer.withOpacity(isDark ? .30 : .46),
                scheme.secondaryContainer.withOpacity(isDark ? .16 : .30),
              ],
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
            ),
          ),
          child: Stack(
            children: [
              PositionedDirectional(
                end: -18,
                bottom: -24,
                child: Container(
                  width: compact ? 86 : 112,
                  height: compact ? 86 : 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary.withOpacity(isDark ? .10 : .08),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  compact ? AppSpacing.sm : AppSpacing.md,
                  AppSpacing.sm,
                  compact ? AppSpacing.sm : AppSpacing.md,
                ),
                child: quote.when(
                  data: (value) => _QuoteContent(
                    quotation: value,
                    compact: compact,
                  ),
                  loading: () => SizedBox(
                    height: compact ? 56 : 74,
                    child: const Center(
                      child: SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  error: (_, __) => _QuoteContent(
                    quotation: null,
                    compact: compact,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuoteContent extends StatelessWidget {
  const _QuoteContent({
    required this.quotation,
    required this.compact,
  });

  final Quotation? quotation;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final quote = quotation;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: compact ? 34 : 40,
          height: compact ? 34 : 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primary.withOpacity(.13),
            borderRadius: AppRadius.small,
          ),
          child: Icon(
            Icons.format_quote_rounded,
            size: compact ? 20 : 24,
            color: scheme.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: quote == null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quotation of the day',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.primary,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Add quotations to your offline Quotation Studio and they will appear here.',
                      maxLines: compact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            quote.category.trim().isEmpty
                                ? 'Quotation of the day'
                                : quote.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: scheme.primary,
                                    ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      quote.text,
                      maxLines: compact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.28,
                          ),
                    ),
                    if (!compact && quote.author.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '— ${quote.author.trim()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
