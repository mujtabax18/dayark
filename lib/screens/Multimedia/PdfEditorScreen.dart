import 'dart:io';
import 'dart:typed_data';

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:metersystem/services/runtime/app_storage_paths.dart';

import '../../controller/mediaController.dart';
import '../../models/MediaFile.dart';

class MediaPdfEditorScreen extends ConsumerStatefulWidget {
  const MediaPdfEditorScreen({
    super.key,
    required this.media,
  });

  final MediaFile media;

  @override
  ConsumerState<MediaPdfEditorScreen> createState() =>
      _MediaPdfEditorScreenState();
}

class _MediaPdfEditorScreenState extends ConsumerState<MediaPdfEditorScreen> {
  Uint8List? _bytes;
  late MediaFile _media;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _media = widget.media;
    _load();
  }

  Future<void> _load() async {
    final file = File(_media.currentPath);
    try {
      if (!await file.exists()) {
        throw FileSystemException('The PDF file is missing.', file.path);
      }
      final bytes = await file.readAsBytes();
      if (mounted) {
        setState(() {
          _bytes = bytes;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not open PDF: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_saving) Navigator.of(context).pop(_media);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _media.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          bottom: _saving
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(3),
                  child: LinearProgressIndicator(),
                )
              : null,
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }

    return PdfEditorView(
      key: ValueKey('${_media.id}-${_media.version}'),
      bytes: _bytes!,
      onSave: _savePdf,
    );
  }

  Future<void> _savePdf(Uint8List bytes) async {
    if (_saving) return;
    setState(() => _saving = true);

    File? temporaryFile;
    try {
      final directory = await getTemporaryDirectory();
      temporaryFile = File(
        p.join(
          directory.path,
          'edited_pdf_${DateTime.now().microsecondsSinceEpoch}.pdf',
        ),
      );
      await temporaryFile.writeAsBytes(bytes, flush: true);

      final saved = await ref.read(mediaServiceProvider).saveEditedFileVersion(
            media: _media,
            outputFile: temporaryFile,
            action: 'pdf_edit',
            metadata: {
              'editor': 'dart_pdf_editor',
              'saved_bytes': bytes.length,
            },
          );

      refreshMediaLibrary(ref);
      if (mounted) {
        setState(() {
          _media = saved;
          _bytes = bytes;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF version ${saved.version} saved.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF save failed: $error')),
        );
      }
    } finally {
      if (temporaryFile != null && await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
      if (mounted) setState(() => _saving = false);
    }
  }
}
