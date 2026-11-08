part of '../MultimediaDashboard.dart';

class _CollectionEmptyState extends StatelessWidget {
  const _CollectionEmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Icon(
                  Icons.photo_library_outlined,
                  size: 42,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Create your first collection',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: neutral.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Collections work like albums in your phone gallery. Group related photos, videos, audio and PDFs without duplicating the original file.',
                textAlign: TextAlign.center,
                style: TextStyle(color: neutral.textSecondary, height: 1.45),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('Create collection'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionGalleryCard extends ConsumerWidget {
  const _CollectionGalleryCard({
    required this.collection,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  final MediaCollection collection;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neutral = context.themeColors.neutral;
    final collectionId = collection.id;
    final previewAsync = collectionId == null
        ? null
        : ref.watch(mediaCollectionPreviewProvider(collectionId));

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
                  child: previewAsync == null
                      ? const _CollectionPreviewPlaceholder(
                          icon: Icons.folder_outlined,
                        )
                      : previewAsync.when(
                          loading: () => ColoredBox(
                            color: neutral.background,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          error: (_, __) => const _CollectionPreviewPlaceholder(
                            icon: Icons.folder_outlined,
                          ),
                          data: (items) => _CollectionPreviewMosaic(items: items),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          collection.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: neutral.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${collection.itemCount} ${collection.itemCount == 1 ? 'item' : 'items'}',
                          style: TextStyle(
                            color: neutral.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Collection options',
                    onSelected: (value) {
                      if (value == 'rename') onRename();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'rename',
                        child: Text('Rename'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete collection'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionPreviewMosaic extends StatelessWidget {
  const _CollectionPreviewMosaic({required this.items});

  final List<MediaFile> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _CollectionPreviewPlaceholder(
        icon: Icons.photo_library_outlined,
      );
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return const _CollectionPreviewPlaceholder(
            icon: Icons.add_photo_alternate_outlined,
            compact: true,
          );
        }
        return _CollectionPreviewCell(media: items[index]);
      },
    );
  }
}

class _CollectionPreviewCell extends StatelessWidget {
  const _CollectionPreviewCell({required this.media});

  final MediaFile media;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    if (media.isImage) {
      return Image.file(
        File(media.currentPath),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _CollectionPreviewPlaceholder(
          icon: Icons.broken_image_outlined,
          compact: true,
        ),
      );
    }

    final icon = media.isVideo
        ? Icons.movie_outlined
        : media.isAudio
            ? Icons.graphic_eq_rounded
            : media.isPdf
                ? Icons.picture_as_pdf_outlined
                : Icons.insert_drive_file_outlined;
    return ColoredBox(
      color: neutral.background,
      child: Center(
        child: Icon(icon, color: AppColors.primary, size: 30),
      ),
    );
  }
}

class _CollectionPreviewPlaceholder extends StatelessWidget {
  const _CollectionPreviewPlaceholder({
    required this.icon,
    this.compact = false,
  });

  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return ColoredBox(
      color: neutral.background,
      child: Center(
        child: Icon(
          icon,
          size: compact ? 26 : 48,
          color: neutral.textDisabled,
        ),
      ),
    );
  }
}

class _ImportActionTile extends StatelessWidget {
  const _ImportActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}

class _EmbeddedDesktopNavigator extends StatefulWidget {
  const _EmbeddedDesktopNavigator({
    super.key,
    required this.detail,
    required this.onClose,
  });

  final Widget detail;
  final VoidCallback onClose;

  @override
  State<_EmbeddedDesktopNavigator> createState() =>
      _EmbeddedDesktopNavigatorState();
}

class _EmbeddedDesktopNavigatorState extends State<_EmbeddedDesktopNavigator> {
  late final NavigatorObserver _observer;

  @override
  void initState() {
    super.initState();
    _observer = _DesktopDetailObserver(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onClose();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      observers: [_observer],
      onGenerateInitialRoutes: (_, __) => [
        MaterialPageRoute<dynamic>(
          settings: const RouteSettings(name: '/media-desktop-base'),
          builder: (_) => const SizedBox.shrink(),
        ),
        MaterialPageRoute<dynamic>(
          settings: const RouteSettings(name: '/media-desktop-detail'),
          builder: (_) => widget.detail,
        ),
      ],
      onGenerateRoute: (_) => null,
    );
  }
}

class _DesktopDetailObserver extends NavigatorObserver {
  _DesktopDetailObserver(this.onRootPopped);

  final VoidCallback onRootPopped;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (route.settings.name == '/media-desktop-detail' &&
        previousRoute?.settings.name == '/media-desktop-base') {
      onRootPopped();
    }
  }
}

class _MediaCollectionsSheet extends ConsumerStatefulWidget {
  const _MediaCollectionsSheet({required this.selectedCollectionId});

  final int? selectedCollectionId;

  @override
  ConsumerState<_MediaCollectionsSheet> createState() =>
      _MediaCollectionsSheetState();
}

