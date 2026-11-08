part of '../MultimediaDashboard.dart';

class _ViewModeToggle extends StatelessWidget {
  const _ViewModeToggle({required this.value, required this.onChanged});

  final _MediaHomeView value;
  final ValueChanged<_MediaHomeView> onChanged;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: neutral.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ViewModeButton(
              icon: Icons.photo_library_outlined,
              label: 'Collections',
              selected: value == _MediaHomeView.collections,
              onTap: () => onChanged(_MediaHomeView.collections),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _ViewModeButton(
              icon: Icons.grid_view_rounded,
              label: 'Library',
              selected: value == _MediaHomeView.library,
              onTap: () => onChanged(_MediaHomeView.library),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewModeButton extends StatelessWidget {
  const _ViewModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: .12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? AppColors.primary : neutral.textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? AppColors.primary : neutral.textSecondary,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
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

class _DesktopSectionLabel extends StatelessWidget {
  const _DesktopSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
      child: Text(
        label,
        style: TextStyle(
          color: neutral.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: .9,
        ),
      ),
    );
  }
}

class _DesktopMediaNavItem extends StatelessWidget {
  const _DesktopMediaNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: .10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: selected ? AppColors.primary : neutral.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? AppColors.primary
                          : neutral.textPrimary,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (count != null)
                  Container(
                    constraints: const BoxConstraints(minWidth: 24),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: .13)
                          : neutral.background,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: selected
                            ? AppColors.primary
                            : neutral.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopStatCard extends StatelessWidget {
  const _DesktopStatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: neutral.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: neutral.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: neutral.textSecondary,
                    fontSize: 11,
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

class _SystemCollectionCard extends ConsumerWidget {
  const _SystemCollectionCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neutral = context.themeColors.neutral;
    final previewAsync = ref.watch(mediaLibraryPreviewProvider);
    return Material(
      color: neutral.card,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: previewAsync.when(
                    loading: () => ColoredBox(
                      color: neutral.background,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (_, __) => const _CollectionPreviewPlaceholder(
                      icon: Icons.perm_media_outlined,
                    ),
                    data: (items) => _CollectionPreviewMosaic(items: items),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.perm_media_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'All media',
                          style: TextStyle(
                            color: neutral.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Browse your full library',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: neutral.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateCollectionCard extends StatelessWidget {
  const _CreateCollectionCard({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Material(
      color: AppColors.primary.withValues(alpha: .045),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onCreate,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: .25),
            ),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.create_new_folder_outlined,
                  color: AppColors.primary,
                  size: 30,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'New collection',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: neutral.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Create an album for related media',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: neutral.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

