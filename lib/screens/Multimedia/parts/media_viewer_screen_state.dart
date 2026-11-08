part of '../MediaViewerScreen.dart';

class _MediaViewerScreenState extends ConsumerState<MediaViewerScreen> {
  late MediaFile _media;
  bool _showControls = true;
  VideoPlayerController? _videoController;
  AudioPlayer? _audioPlayer;
  bool _initializing = true;
  String? _playerError;

  @override
  void initState() {
    super.initState();
    _media = widget.mediaFile;
    _initializeViewer();
  }

  Future<void> _initializeViewer() async {
    final file = File(_media.currentPath);
    if (!await file.exists()) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _playerError =
              'This file is missing. Restore a portable ZIP backup to recover it.';
        });
      }
      return;
    }

    try {
      if (_media.isVideo) {
        final controller = VideoPlayerController.file(file);
        await controller.initialize();
        await controller.setLooping(true);
        _videoController = controller;
      } else if (_media.isAudio) {
        final player = AudioPlayer();
        await player.setFilePath(file.path);
        _audioPlayer = player;
      }
    } catch (error) {
      _playerError = 'Could not open this media: $error';
    }

    if (mounted) setState(() => _initializing = false);
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final darkBackground = _media.isImage || _media.isVideo;
    return Scaffold(
      backgroundColor: darkBackground ? Colors.black : null,
      extendBodyBehindAppBar: darkBackground,
      appBar: _showControls
          ? AppBar(
              backgroundColor: darkBackground
                  ? Colors.black.withValues(alpha: 0.62)
                  : null,
              surfaceTintColor: Colors.transparent,
              foregroundColor: darkBackground ? Colors.white : null,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _media.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    '${_media.mediaType.toUpperCase()} • Version ${_media.version}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
              actions: [
                if (_media.isImage)
                  IconButton(
                    tooltip: 'Edit image',
                    onPressed: _editImage,
                    icon: const Icon(Icons.tune),
                  ),
                if (_media.isVideo)
                  IconButton(
                    tooltip: 'Edit video',
                    onPressed: _editVideo,
                    icon: const Icon(Icons.video_settings_outlined),
                  ),
                if (_media.isPdf)
                  IconButton(
                    tooltip: 'Edit PDF',
                    onPressed: _editPdf,
                    icon: const Icon(Icons.edit_document),
                  ),
                IconButton(
                  tooltip: _media.isFavorite
                      ? 'Remove from favorites'
                      : 'Add to favorites',
                  onPressed: _toggleFavorite,
                  icon: Icon(
                    _media.isFavorite ? Icons.star : Icons.star_border,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: _handleMenu,
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'share', child: Text('Share')),
                    const PopupMenuItem(
                        value: 'history', child: Text('Version history')),
                    const PopupMenuItem(value: 'rename', child: Text('Rename')),
                    const PopupMenuItem(
                        value: 'duplicate', child: Text('Duplicate')),
                    const PopupMenuItem(value: 'info', child: Text('File info')),
                    if (!_media.isImage && !_media.isVideo && !_media.isAudio)
                      const PopupMenuItem(
                          value: 'external', child: Text('Open externally')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'trash',
                      child: Text('Move to trash'),
                    ),
                  ],
                ),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: () {
          if (_media.isImage || _media.isVideo) {
            setState(() => _showControls = !_showControls);
          }
        },
        child: SafeArea(
          top: !darkBackground,
          bottom: !darkBackground,
          child: _buildViewer(),
        ),
      ),
    );
  }

  Widget _buildViewer() {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_playerError != null) {
      return _ErrorView(message: _playerError!);
    }
    if (_media.isImage) return _buildImage();
    if (_media.isVideo) return _buildVideo();
    if (_media.isAudio) return _buildAudio();
    return _buildDocument();
  }

  Widget _buildImage() {
    return PhotoView(
      imageProvider: FileImage(File(_media.currentPath)),
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      heroAttributes: PhotoViewHeroAttributes(tag: 'media-${_media.id}'),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 4,
      errorBuilder: (_, __, ___) => const _ErrorView(
        message: 'The image could not be decoded.',
      ),
    );
  }

  Widget _buildVideo() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return const _ErrorView(message: 'The video is not available.');
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
        ),
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (_, value, __) => AnimatedOpacity(
            opacity: value.isPlaying ? 0 : 1,
            duration: const Duration(milliseconds: 180),
            child: IconButton.filled(
              iconSize: 44,
              onPressed: () => value.isPlaying
                  ? controller.pause()
                  : controller.play(),
              icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildAudio() {
    final player = _audioPlayer;
    if (player == null) {
      return const _ErrorView(message: 'The audio file is not available.');
    }
    final neutral = context.themeColors.neutral;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.graphic_eq, size: 78),
          ),
          const SizedBox(height: 28),
          Text(
            _media.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: neutral.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          StreamBuilder<Duration>(
            stream: player.positionStream,
            builder: (_, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final duration = player.duration ?? Duration.zero;
              final max = duration.inMilliseconds <= 0
                  ? 1.0
                  : duration.inMilliseconds.toDouble();
              return Column(
                children: [
                  Slider(
                    value: position.inMilliseconds.clamp(0, max.toInt()).toDouble(),
                    max: max,
                    onChanged: (value) =>
                        player.seek(Duration(milliseconds: value.round())),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_durationLabel(position)),
                      Text(_durationLabel(duration)),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          StreamBuilder<PlayerState>(
            stream: player.playerStateStream,
            builder: (_, snapshot) {
              final state = snapshot.data;
              final playing = state?.playing ?? false;
              final processing = state?.processingState;
              if (processing == ProcessingState.loading ||
                  processing == ProcessingState.buffering) {
                return const CircularProgressIndicator();
              }
              return IconButton.filled(
                iconSize: 42,
                onPressed: () async {
                  if (processing == ProcessingState.completed) {
                    await player.seek(Duration.zero);
                    await player.play();
                  } else if (playing) {
                    await player.pause();
                  } else {
                    await player.play();
                  }
                },
                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDocument() {
    final neutral = context.themeColors.neutral;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _media.isPdf
                  ? Icons.picture_as_pdf_outlined
                  : Icons.insert_drive_file_outlined,
              size: 92,
              color: AppColors.primary,
            ),
            const SizedBox(height: 18),
            Text(
              _media.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: neutral.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This file is stored offline in the media library.',
              textAlign: TextAlign.center,
              style: TextStyle(color: neutral.textSecondary),
            ),
            const SizedBox(height: 22),
            if (_media.isPdf) ...[
              FilledButton.icon(
                onPressed: _editPdf,
                icon: const Icon(Icons.edit_document),
                label: const Text('Open PDF editor'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _openExternal,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open externally'),
              ),
            ] else
              FilledButton.icon(
                onPressed: _openExternal,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open file'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleMenu(String value) async {
    switch (value) {
      case 'share':
        await _share();
        break;
      case 'history':
        await _openHistory();
        break;
      case 'rename':
        await _rename();
        break;
      case 'duplicate':
        await _duplicate();
        break;
      case 'info':
        await _showInfo();
        break;
      case 'external':
        await _openExternal();
        break;
      case 'trash':
        await _moveToTrash();
        break;
    }
  }

  Future<void> _editImage() async {
    final file = File(_media.currentPath);
    if (!await file.exists()) return;

    final updated = await Navigator.of(context).push<MediaFile>(
      MaterialPageRoute(
        builder: (editorContext) => ProImageEditor.file(
          file,
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (bytes) async {
              final saved = await ref.read(mediaServiceProvider).saveEditedVersion(
                    media: _media,
                    bytes: bytes,
                    action: 'image_edit',
                    metadata: {'editor': 'pro_image_editor'},
                  );
              if (editorContext.mounted) {
                Navigator.of(editorContext).pop(saved);
              }
            },
          ),
        ),
      ),
    );
    if (updated != null && mounted) {
      await _applyUpdatedMedia(updated);
      refreshMediaLibrary(ref);
      _message('Version ${updated.version} saved.');
    }
  }

  Future<void> _editVideo() async {
    final updated = await Navigator.of(context).push<MediaFile>(
      MaterialPageRoute(
        builder: (_) => VideoEditorScreen(media: _media),
      ),
    );
    if (updated != null && mounted) {
      await _applyUpdatedMedia(updated);
      refreshMediaLibrary(ref);
      _message('Video version ${updated.version} saved.');
    }
  }

  Future<void> _editPdf() async {
    await Navigator.of(context).push<MediaFile>(
      MaterialPageRoute(
        builder: (_) => MediaPdfEditorScreen(media: _media),
      ),
    );
    final id = _media.id;
    if (id == null || !mounted) return;
    final updated = await ref.read(mediaServiceProvider).getMediaById(id);
    if (updated != null && mounted) {
      await _applyUpdatedMedia(updated);
      refreshMediaLibrary(ref);
    }
  }

  Future<void> _applyUpdatedMedia(MediaFile updated) async {
    await _videoController?.dispose();
    await _audioPlayer?.dispose();
    _videoController = null;
    _audioPlayer = null;
    if (!mounted) return;
    setState(() {
      _media = updated;
      _initializing = true;
      _playerError = null;
    });
    await _initializeViewer();
  }

  Future<void> _share() async {
    final file = File(_media.currentPath);
    if (!await file.exists()) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        title: _media.title,
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    await ref.read(mediaServiceProvider).toggleFavorite(_media);
    setState(() => _media = _media.copyWith(isFavorite: !_media.isFavorite));
    refreshMediaLibrary(ref);
  }

  Future<void> _openHistory() async {
    final id = _media.id;
    if (id == null) return;
    final restored = await Navigator.of(context).push<MediaFile>(
      MaterialPageRoute(
        builder: (_) => MediaHistoryScreen(media: _media),
      ),
    );
    if (restored != null && mounted) {
      await _applyUpdatedMedia(restored);
      refreshMediaLibrary(ref);
    }
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: _media.title);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename media'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null || title.isEmpty || _media.id == null) return;
    await ref.read(mediaServiceProvider).renameMedia(_media.id!, title);
    setState(() => _media = _media.copyWith(title: title));
    refreshMediaLibrary(ref);
  }

  Future<void> _duplicate() async {
    final duplicate = await ref.read(mediaServiceProvider).duplicateMedia(_media);
    refreshMediaLibrary(ref);
    if (mounted) _message('${duplicate.title} created.');
  }

  Future<void> _openExternal() async {
    final result = await OpenFilex.open(_media.currentPath);
    if (result.type != ResultType.done && mounted) {
      _message(result.message);
    }
  }

  Future<void> _moveToTrash() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to trash?'),
        content: const Text(
          'The original and all edited versions remain recoverable until you permanently delete them from Trash.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Move to trash'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(mediaServiceProvider).moveToTrash(_media);
    refreshMediaLibrary(ref);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _showInfo() async {
    final neutral = context.themeColors.neutral;
    final file = File(_media.currentPath);
    final actualBytes = await file.exists() ? await file.length() : 0;
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: neutral.card,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'File details',
                style: TextStyle(
                  color: neutral.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _InfoRow(label: 'Type', value: _media.mediaType),
              _InfoRow(label: 'Version', value: '${_media.version}'),
              _InfoRow(label: 'Size', value: _formatBytes(actualBytes)),
              _InfoRow(label: 'MIME', value: _media.mimeType ?? 'Unknown'),
              _InfoRow(
                label: 'Updated',
                value: DateFormat('yyyy-MM-dd HH:mm').format(
                  DateTime.tryParse(_media.updatedAt) ?? DateTime.now(),
                ),
              ),
              _InfoRow(label: 'Current path', value: _media.currentPath),
              _InfoRow(label: 'Original path', value: _media.originalPath),
              if (_media.checksum?.isNotEmpty == true)
                _InfoRow(label: 'SHA-256', value: _media.checksum!),
            ],
          ),
        ),
      ),
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _durationLabel(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = value.inHours;
    return hours > 0
        ? '$hours:$minutes:$seconds'
        : '${value.inMinutes}:$seconds';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

