part of '../MultimediaDashboard.dart';

class _MediaCard extends StatelessWidget {
  const _MediaCard({
    required this.media,
    required this.onOpen,
    required this.onFavorite,
    required this.onCollections,
    required this.onTrash,
  });

  final MediaFile media;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;
  final VoidCallback onCollections;
  final VoidCallback onTrash;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final file = File(media.currentPath);

    return Material(
      color: neutral.card,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (media.isImage)
                    Hero(
                      tag: 'media-${media.id}',
                      child: Image.file(
                        file,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _MediaTypePlaceholder(media: media),
                      ),
                    )
                  else
                    _MediaTypePlaceholder(media: media),
                  Positioned(
                    top: 7,
                    left: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.68),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        media.hasEdits ? 'v${media.version}' : media.mediaType,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: IconButton.filledTonal(
                      visualDensity: VisualDensity.compact,
                      tooltip: media.isFavorite
                          ? 'Remove from favorites'
                          : 'Add to favorites',
                      onPressed: onFavorite,
                      icon: Icon(
                        media.isFavorite ? Icons.star : Icons.star_border,
                        size: 19,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 4, 7),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          media.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: neutral.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('MMM d, yyyy').format(
                            DateTime.tryParse(media.updatedAt) ??
                                DateTime.now(),
                          ),
                          style: TextStyle(
                            color: neutral.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Add to collections',
                    visualDensity: VisualDensity.compact,
                    onPressed: onCollections,
                    icon: const Icon(Icons.folder_outlined, size: 19),
                  ),
                  IconButton(
                    tooltip: 'Move to trash',
                    visualDensity: VisualDensity.compact,
                    onPressed: onTrash,
                    icon: const Icon(Icons.delete_outline, size: 19),
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

class _MediaTypePlaceholder extends StatelessWidget {
  const _MediaTypePlaceholder({required this.media});

  final MediaFile media;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final icon = switch (media.mediaType) {
      'video' => Icons.movie_outlined,
      'audio' => Icons.graphic_eq,
      'pdf' => Icons.picture_as_pdf_outlined,
      'image' => Icons.broken_image_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
    return Container(
      color: neutral.background,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            (media.extension ?? media.mediaType).toUpperCase(),
            style: TextStyle(
              color: neutral.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: neutral.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: neutral.textSecondary, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: neutral.textDisabled),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: neutral.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: neutral.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaTrashScreen extends ConsumerWidget {
  const _MediaTrashScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neutral = context.themeColors.neutral;
    const query = MediaQuery(includeDeleted: true);
    final allAsync = ref.watch(filteredMediaListProvider(query));

    return Scaffold(
      backgroundColor: neutral.background,
      appBar: AppBar(
        title: const Text('Media trash'),
        backgroundColor: neutral.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: allAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (all) {
          final deleted = all.where((item) => item.isDeleted).toList();
          if (deleted.isEmpty) {
            return const _MessageState(
              icon: Icons.delete_sweep_outlined,
              title: 'Trash is empty',
              message: 'Deleted media stays here until permanently removed.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: deleted.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = deleted[index];
              return Card(
                child: ListTile(
                  leading: Icon(
                    item.isImage
                        ? Icons.image_outlined
                        : item.isVideo
                        ? Icons.movie_outlined
                        : item.isAudio
                        ? Icons.graphic_eq
                        : Icons.insert_drive_file_outlined,
                  ),
                  title: Text(item.title),
                  subtitle: Text('Version ${item.version}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'restore') {
                        await ref
                            .read(mediaServiceProvider)
                            .restoreFromTrash(item);
                      } else {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete permanently?'),
                            content: const Text(
                              'This removes the original, every edited version and all history. This cannot be undone.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await ref
                              .read(mediaServiceProvider)
                              .permanentDelete(item);
                        }
                      }
                      refreshMediaLibrary(ref);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'restore', child: Text('Restore')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete permanently'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
