part of '../QuotesScreen.dart';

class _QuotationCard extends StatelessWidget {
  const _QuotationCard({
    required this.quotation,
    required this.onFavorite,
    required this.onCopy,
    required this.onShare,
    required this.shareLabel,
    required this.shareIcon,
    required this.onImage,
    required this.onEdit,
    required this.onDelete,
  });

  final Quotation quotation;
  final VoidCallback onFavorite;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final String shareLabel;
  final FaIconData shareIcon;
  final VoidCallback onImage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Container(
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: neutral.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.habit.withOpacity(.10),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    quotation.category,
                    style: TextStyle(
                      color: AppColors.habit,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (quotation.source == 'prompt') ...[
                  const SizedBox(width: 7),
                  Tooltip(
                    message: 'Added through prompt workflow',
                    child: CenteredFaIcon(
                      FontAwesomeIcons.wandMagicSparkles,
                      color: AppColors.habit,
                      size: 12,
                    ),
                  ),
                ],
                const Spacer(),
                IconButton(
                  tooltip: quotation.isFavorite
                      ? 'Remove from favorites'
                      : 'Add to favorites',
                  onPressed: onFavorite,
                  icon: CenteredFaIcon(
                    quotation.isFavorite
                        ? FontAwesomeIcons.solidHeart
                        : FontAwesomeIcons.heart,
                    size: 17,
                    color: quotation.isFavorite ? AppColors.danger : null,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              quotation.text,
              style: TextStyle(
                color: neutral.textPrimary,
                fontSize: 17,
                height: 1.42,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (quotation.author.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
              child: Text(
                '— ${quotation.author}',
                style: TextStyle(
                  color: neutral.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Divider(height: 1, color: neutral.divider),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            child: Row(
              children: [
                _CardAction(
                  icon: FontAwesomeIcons.copy,
                  label: 'Copy',
                  onTap: onCopy,
                ),
                _CardAction(
                  icon: shareIcon,
                  label: shareLabel,
                  onTap: onShare,
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: onImage,
                    icon: const CenteredFaIcon(
                      FontAwesomeIcons.image,
                      size: 14,
                    ),
                    label: const Text('Create image'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final FaIconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextButton.icon(
        onPressed: onTap,
        icon: CenteredFaIcon(icon, size: 14),
        label: Text(label),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final FaIconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: TextButton.icon(
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        onPressed: onTap,
        icon: CenteredFaIcon(icon, size: 13),
        label: Text(label),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd, required this.onPrompt});

  final VoidCallback onAdd;
  final VoidCallback onPrompt;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.habit.withOpacity(.10),
                shape: BoxShape.circle,
              ),
              child: CenteredFaIcon(
                FontAwesomeIcons.quoteLeft,
                color: AppColors.habit,
                size: 28,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Build your motivation library',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: neutral.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Add your own quotation or build an offline prompt for any categories you choose.',
              textAlign: TextAlign.center,
              style: TextStyle(color: neutral.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onPrompt,
                  icon: const CenteredFaIcon(
                    FontAwesomeIcons.wandMagicSparkles,
                    size: 15,
                  ),
                  label: const Text('Build prompt'),
                ),
                ElevatedButton.icon(
                  onPressed: onAdd,
                  icon: const CenteredFaIcon(FontAwesomeIcons.plus, size: 15),
                  label: const Text('Add quotation'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
