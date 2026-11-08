import 'package:flutter/material.dart';

import 'life_archive_media.dart';

/// Opens the existing native full-screen, swipeable and zoomable photo viewer.
/// Invalid or deleted local paths are skipped instead of showing broken pages.
Future<void> showFullscreenFamilyPhotos(BuildContext context, List<String> paths,
    {int initialIndex = 0, String? title}) {
  final valid = paths.where((path) => LifeArchiveMedia.canDisplay(path)).toList();
  if (valid.isEmpty) return Future<void>.value();
  final wanted = initialIndex >= 0 && initialIndex < paths.length
      ? paths[initialIndex] : valid.first;
  final index = valid.indexOf(wanted);
  return Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
    builder: (_) => FullscreenFamilyPhoto(
        paths: valid, initialIndex: index < 0 ? 0 : index, title: title),
  ));
}


/// Lightweight native Flutter photo pager. No 3rd-party graph/gallery plugin.
class FamilyPhotoGallery extends StatefulWidget {
  const FamilyPhotoGallery({
    super.key,
    required this.paths,
    this.height = 235,
  });

  final List<String> paths;
  final double height;

  @override
  State<FamilyPhotoGallery> createState() => _FamilyPhotoGalleryState();
}

class _FamilyPhotoGalleryState extends State<FamilyPhotoGallery> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paths = widget.paths.where((path) => LifeArchiveMedia.canDisplay(path)).toList();
    if (paths.isEmpty) {
      return SizedBox(height: widget.height,
        child: const Center(child: Icon(Icons.photo_library_outlined, size: 50)));
    }
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(children: [
          Positioned.fill(child: PageView.builder(
            controller: _controller,
            itemCount: paths.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) => GestureDetector(
              onTap: () => showFullscreenFamilyPhotos(context, paths, initialIndex: index),
              child: LifeArchiveMedia.image(paths[index], fit: BoxFit.cover,
                cacheWidth: 1200, width: double.infinity,
                errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined))),
            ),
          )),
          Positioned(bottom: 10, right: 10,
            child: DecoratedBox(
              decoration: BoxDecoration(color: Colors.black54,
                borderRadius: BorderRadius.circular(30)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                child: Text('${_index.clamp(0, paths.length - 1) + 1} / ${paths.length}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class FullscreenFamilyPhoto extends StatefulWidget {
  const FullscreenFamilyPhoto({super.key, required this.paths,
      required this.initialIndex, this.title});
  final List<String> paths;
  final int initialIndex;
  final String? title;

  @override
  State<FullscreenFamilyPhoto> createState() => _FullscreenFamilyPhotoState();
}

class _FullscreenFamilyPhotoState extends State<FullscreenFamilyPhoto> {
  late final PageController _pager = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text(widget.title == null
          ? '${_index + 1} of ${widget.paths.length}'
          : '${widget.title} · ${_index + 1}/${widget.paths.length}',
          maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
    body: PageView.builder(
      controller: _pager,
      itemCount: widget.paths.length,
      onPageChanged: (index) => setState(() => _index = index),
      itemBuilder: (context, index) => InteractiveViewer(
        minScale: 1, maxScale: 5,
        child: Center(child: LifeArchiveMedia.image(widget.paths[index], fit: BoxFit.contain)),
      ),
    ),
  );
}
