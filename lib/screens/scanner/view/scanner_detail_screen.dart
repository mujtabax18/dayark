import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:share_plus/share_plus.dart';

import '../controllers/provideers/scanGroupRepoProvider.dart';
import '../controllers/provideers/scannerRepoProvider.dart';
import '../data/models/scan_model.dart';
import '../../navigation/widgets/desktop_content_frame.dart';

class ScannerDetailScreen extends ConsumerStatefulWidget {
  const ScannerDetailScreen({super.key, required this.scan});

  final ScanEntry scan;

  @override
  ConsumerState<ScannerDetailScreen> createState() =>
      _ScannerDetailScreenState();
}

class _ScannerDetailScreenState extends ConsumerState<ScannerDetailScreen> {
  late ScanEntry _scan;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _scan = widget.scan;
  }

  @override
  Widget build(BuildContext context) {
    final file = File(_scan.currentPath);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.72),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _scan.title.trim().isEmpty ? 'Scan page' : _scan.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Version ${_scan.version}',
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Edit page',
            onPressed: _busy ? null : _edit,
            icon: const Icon(Icons.tune),
          ),
          IconButton(
            tooltip: _scan.isFavorite
                ? 'Remove page favorite'
                : 'Favorite page',
            onPressed: _busy ? null : _toggleFavorite,
            icon: Icon(_scan.isFavorite ? Icons.star : Icons.star_border),
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenu,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'details', child: Text('Page details')),
              PopupMenuItem(value: 'share', child: Text('Share image')),
              PopupMenuItem(
                value: 'reset',
                child: Text('Reset to original'),
              ),
            ],
          ),
        ],
      ),
      body: DesktopContentFrame(
        child: Stack(
        children: [
          Positioned.fill(
            child: file.existsSync()
                ? PhotoView(
                    imageProvider: FileImage(file),
                    backgroundDecoration:
                        const BoxDecoration(color: Colors.black),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 5,
                  )
                : const Center(
                    child: Text(
                      'This page image is missing. Restore a scanner backup.',
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
      ),
    );
  }

  Future<void> _handleMenu(String value) async {
    switch (value) {
      case 'details':
        await _editDetails();
        break;
      case 'share':
        await _share();
        break;
      case 'reset':
        await _reset();
        break;
    }
  }

  Future<void> _edit() async {
    final source = File(_scan.currentPath);
    if (!await source.exists()) return;
    final updated = await Navigator.of(context).push<ScanEntry>(
      MaterialPageRoute(
        builder: (editorContext) => ProImageEditor.file(
          source,
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (bytes) async {
              final saved = await ref
                  .read(scannerServiceProvider)
                  .saveEditedVersion(
                    scan: _scan,
                    bytes: bytes,
                    action: 'page_edit',
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
      setState(() => _scan = updated);
      _refresh();
      _message('Edited page saved as version ${updated.version}.');
    }
  }

  Future<void> _editDetails() async {
    final title = TextEditingController(text: _scan.title);
    final notes = TextEditingController(text: _scan.notes);
    final searchableText = TextEditingController(text: _scan.ocrText);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Page details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Page title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notes,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: searchableText,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Searchable text / manual OCR text',
                  helperText:
                      'Stored offline and included in scanner backups.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == true) {
      await ref.read(scannerServiceProvider).updateDetails(
            _scan,
            title: title.text,
            notes: notes.text,
            ocrText: searchableText.text,
          );
      setState(() {
        _scan = _scan.copyWith(
          title: title.text.trim(),
          notes: notes.text.trim(),
          ocrText: searchableText.text.trim(),
          updatedAt: DateTime.now().toIso8601String(),
        );
      });
      _refresh();
    }
    title.dispose();
    notes.dispose();
    searchableText.dispose();
  }

  Future<void> _toggleFavorite() async {
    await ref.read(scannerServiceProvider).toggleFavorite(_scan);
    setState(() => _scan = _scan.copyWith(isFavorite: !_scan.isFavorite));
    _refresh();
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset page?'),
        content: const Text(
          'The original scan will become the current version. Existing edited '
          'files remain protected by backup/history until deleted with the page.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      final updated =
          await ref.read(scannerServiceProvider).resetToOriginal(_scan);
      if (mounted) setState(() => _scan = updated);
      _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    final file = File(_scan.currentPath);
    if (!await file.exists()) return;
    await SharePlus.instance.share(
      ShareParams(
        title: _scan.title.isEmpty ? 'Scanned page' : _scan.title,
        files: [XFile(file.path)],
      ),
    );
  }

  void _refresh() {
    ref.invalidate(scanGroupPreviewProvider);
    ref.invalidate(filteredScanGroupPreviewProvider);
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
