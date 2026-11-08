part of '../MultimediaDashboard.dart';

class _MediaCollectionsSheetState
    extends ConsumerState<_MediaCollectionsSheet> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final collectionsAsync = ref.watch(mediaCollectionsProvider);

    return SafeArea(
      child: SizedBox(
        height: MediaQueryData.fromView(View.of(context)).size.height * 0.72,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Media collections',
                          style: TextStyle(
                            color: neutral.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Create folders and organize the same item in more than one collection.',
                          style: TextStyle(
                            color: neutral.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'New collection',
                    onPressed: _busy ? null : _createCollection,
                    icon: const Icon(Icons.create_new_folder_outlined),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.all_inbox_outlined),
              title: const Text('All media'),
              trailing: widget.selectedCollectionId == null
                  ? const Icon(Icons.check_circle, color: AppColors.primary)
                  : null,
              onTap: () => Navigator.pop(context, -1),
            ),
            const Divider(height: 1),
            Expanded(
              child: collectionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Could not load collections: $error'),
                  ),
                ),
                data: (collections) {
                  if (collections.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.folder_open_outlined, size: 48),
                            const SizedBox(height: 12),
                            const Text(
                              'No collections yet',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Create a collection, then use the folder button on any media card to add items.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: neutral.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: collections.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final collection = collections[index];
                      return ListTile(
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(collection.name),
                        subtitle: Text(
                          '${collection.itemCount} item${collection.itemCount == 1 ? '' : 's'}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.selectedCollectionId == collection.id)
                              const Icon(
                                Icons.check_circle,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            PopupMenuButton<String>(
                              enabled: !_busy,
                              onSelected: (action) {
                                if (action == 'rename') {
                                  _renameCollection(collection);
                                } else if (action == 'delete') {
                                  _deleteCollection(collection);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'rename',
                                  child: Text('Rename'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    'Delete collection',
                                    style: TextStyle(color: AppColors.danger),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: collection.id == null
                            ? null
                            : () => Navigator.pop(context, collection.id),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createCollection() async {
    final name = await _promptForCollectionName(context);
    if (name == null || !mounted) return;
    await _run(() => ref.read(mediaServiceProvider).createCollection(name));
  }

  Future<void> _renameCollection(MediaCollection collection) async {
    if (collection.id == null) return;
    final name = await _promptForCollectionName(
      context,
      initialValue: collection.name,
      title: 'Rename collection',
    );
    if (name == null || !mounted) return;
    await _run(
      () => ref.read(mediaServiceProvider).renameCollection(collection.id!, name),
    );
  }

  Future<void> _deleteCollection(MediaCollection collection) async {
    if (collection.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete collection?'),
        content: Text(
          '“${collection.name}” will be removed. The media files inside it will stay in your library.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      () => ref.read(mediaServiceProvider).deleteCollection(collection.id!),
    );
  }

  Future<void> _run(Future<dynamic> Function() operation) async {
    setState(() => _busy = true);
    try {
      await operation();
      ref.invalidate(mediaCollectionsProvider);
      ref.invalidate(filteredMediaListProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Collection update failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _MediaCollectionPicker extends ConsumerWidget {
  const _MediaCollectionPicker({required this.media});

  final MediaFile media;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neutral = context.themeColors.neutral;
    final mediaId = media.id!;
    final collectionsAsync = ref.watch(mediaCollectionsProvider);
    final membershipAsync = ref.watch(mediaCollectionIdsProvider(mediaId));

    return SafeArea(
      child: SizedBox(
        height: MediaQueryData.fromView(View.of(context)).size.height * 0.58,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add to collections',
                          style: TextStyle(
                            color: neutral.textPrimary,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          media.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: neutral.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _createAndAdd(context, ref, mediaId),
                    icon: const Icon(Icons.create_new_folder_outlined),
                    label: const Text('New'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: collectionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Could not load collections: $error'),
                ),
                data: (collections) {
                  if (collections.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        'No collections yet. Tap New to create one.',
                        style: TextStyle(color: neutral.textSecondary),
                      ),
                    );
                  }
                  return membershipAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Could not load membership: $error'),
                    ),
                    data: (selectedIds) => ListView.builder(
                      shrinkWrap: true,
                      itemCount: collections.length,
                      itemBuilder: (context, index) {
                        final collection = collections[index];
                        final id = collection.id;
                        final checked = id != null && selectedIds.contains(id);
                        return CheckboxListTile(
                          value: checked,
                          secondary: const Icon(Icons.folder_outlined),
                          title: Text(collection.name),
                          subtitle: Text('${collection.itemCount} items'),
                          onChanged: id == null
                              ? null
                              : (value) async {
                                  await ref
                                      .read(mediaServiceProvider)
                                      .setMediaInCollection(
                                        mediaId: mediaId,
                                        collectionId: id,
                                        included: value == true,
                                      );
                                  ref.invalidate(
                                    mediaCollectionIdsProvider(mediaId),
                                  );
                                  ref.invalidate(mediaCollectionsProvider);
                                  ref.invalidate(filteredMediaListProvider);
                                },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _createAndAdd(
    BuildContext context,
    WidgetRef ref,
    int mediaId,
  ) async {
    final name = await _promptForCollectionName(context);
    if (name == null || !context.mounted) return;
    try {
      final collectionId =
          await ref.read(mediaServiceProvider).createCollection(name);
      await ref.read(mediaServiceProvider).setMediaInCollection(
            mediaId: mediaId,
            collectionId: collectionId,
            included: true,
          );
      ref.invalidate(mediaCollectionsProvider);
      ref.invalidate(mediaCollectionIdsProvider(mediaId));
      ref.invalidate(filteredMediaListProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create collection: $error')),
        );
      }
    }
  }
}

Future<String?> _promptForCollectionName(
  BuildContext context, {
  String initialValue = '',
  String title = 'New collection',
}) async {
  var draftName = initialValue;

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextFormField(
        initialValue: initialValue,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        maxLength: 60,
        decoration: const InputDecoration(
          labelText: 'Collection name',
          hintText: 'e.g. Work, Receipts, Family',
        ),
        onChanged: (value) => draftName = value,
        onFieldSubmitted: (value) {
          final cleaned = value.trim();
          if (cleaned.isNotEmpty) {
            FocusScope.of(dialogContext).unfocus();
            Navigator.pop(dialogContext, cleaned);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusScope.of(dialogContext).unfocus();
            Navigator.pop(dialogContext);
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final cleaned = draftName.trim();
            if (cleaned.isNotEmpty) {
              FocusScope.of(dialogContext).unfocus();
              Navigator.pop(dialogContext, cleaned);
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

