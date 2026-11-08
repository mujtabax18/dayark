import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({
    super.key,
    required this.file,
    this.title = 'PDF editor',
  });

  final File file;
  final String title;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (!await widget.file.exists()) {
        throw const FileSystemException('PDF file does not exist.');
      }
      final bytes = await widget.file.readAsBytes();
      if (mounted) setState(() => _bytes = bytes);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(Uint8List bytes) async {
    setState(() => _saving = true);
    try {
      await widget.file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      setState(() => _bytes = bytes);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF changes saved offline.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _printPdf() async {
    final bytes = _bytes;
    if (bytes == null) return;
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> _sharePdf() async {
    if (!await widget.file.exists()) return;
    await SharePlus.instance.share(
      ShareParams(
        title: widget.title,
        files: [XFile(widget.file.path)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            tooltip: 'Share PDF',
            onPressed: _bytes == null ? null : _sharePdf,
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: 'Print PDF',
            onPressed: _bytes == null ? null : _printPdf,
            icon: const Icon(Icons.print_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : PdfEditorView(
                  bytes: _bytes!,
                  onSave: _save,
                ),
    );
  }
}
