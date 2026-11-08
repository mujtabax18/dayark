import 'dart:io';

import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:cross_file/cross_file.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:share_plus/share_plus.dart';

import '../../../utlis/widgets/snackbar.dart';
import '../../../utlis/platform_capabilities.dart';
import '../controllers/ScanGroupViewController.dart';
import '../controllers/provideers/scanGroupViewControllerProvider.dart';
import '../controllers/states/ScanGroupViewState.dart';
import '../data/models/scan_model.dart';
import '../services/scan_gallery_service.dart';
import '../services/scan_pdf_service.dart';
import '../services/scan_permission_service.dart';
import '../wigets/add_more_tile.dart';
import 'pdf_viewer_screen.dart';
import 'scanner_detail_screen.dart';
import '../../navigation/widgets/desktop_content_frame.dart';

class ScanGroupViewScreen extends ConsumerStatefulWidget {
  const ScanGroupViewScreen({super.key, required this.groupId});

  final int groupId;

  @override
  ConsumerState<ScanGroupViewScreen> createState() =>
      _ScanGroupViewScreenState();
}

class _ScanGroupViewScreenState extends ConsumerState<ScanGroupViewScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scanGroupViewControllerProvider(widget.groupId));
    final controller = ref.read(
      scanGroupViewControllerProvider(widget.groupId).notifier,
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(state.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Rename document',
            onPressed: () => editTitle(context, controller, state.title),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenu(value, state, controller),
            itemBuilder: (_) => [
              if (documentScannerCaptureSupported)
                const PopupMenuItem(
                  value: 'add_camera',
                  child: Text('Scan more pages'),
                ),
              const PopupMenuItem(
                value: 'add_files',
                child: Text('Import image pages'),
              ),
              const PopupMenuItem(
                value: 'favorite',
                child: Text('Toggle favorite'),
              ),
              const PopupMenuItem(
                value: 'info',
                child: Text('Document information'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete document'),
              ),
            ],
          ),
        ],
      ),
      body: DesktopContentFrame(
        child: Stack(
          children: [
            if (state.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (state.scans.isEmpty)
              const Center(child: Text('No pages in this document.'))
            else
              ReorderableGridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.76,
                ),
                itemCount: state.scans.length,
                onReorder: (oldIndex, newIndex) {
                  controller.reorderLocallyAndPersist(
                    oldIndex: oldIndex,
                    newIndex: newIndex,
                  );
                },
                itemBuilder: (_, index) {
                  final scan = state.scans[index];
                  final selected = state.selectedIds.contains(scan.id);
                  return _PageCard(
                    key: ValueKey(scan.id),
                    scan: scan,
                    pageNumber: index + 1,
                    selectionMode: state.selectionMode,
                    selected: selected,
                    onTap: () => _openPage(scan, controller),
                    onLongPress: () {
                      if (scan.id == null) return;
                      controller.enableSelectionMode(true);
                      controller.toggleSelection(scan.id!);
                    },
                    onSelectionTap: () {
                      if (scan.id != null) controller.toggleSelection(scan.id!);
                    },
                    onDuplicate: () => controller.duplicateScan(scan),
                    onDelete: scan.id == null
                        ? null
                        : () =>
                              confirmDeleteScan(context, controller, scan.id!),
                  );
                },
              ),
            if (_busy)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x33000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomActionBar(
        state: state,
        controller: controller,
        onExportPdf: (scans) => _exportPdf(state.title, scans),
        onSharePdf: (scans) => _sharePdf(state.title, scans),
        onSaveGallery: (scans) => _saveGallery(state.title, scans),
        onAdd: _showAddActions,
      ),
    );
  }

  Future<void> _handleMenu(
    String value,
    ScanGroupViewState state,
    ScanGroupViewController controller,
  ) async {
    switch (value) {
      case 'add_camera':
        await _scanMore(controller);
        break;
      case 'add_files':
        await _importMore(controller);
        break;
      case 'favorite':
        await controller.toggleGroupFavorite();
        _message('Document favorite updated.');
        break;
      case 'info':
        await _showInfo(state);
        break;
      case 'delete':
        await confirmGroupDelete(context, controller);
        break;
    }
  }

  Future<void> _showAddActions() async {
    final controller = ref.read(
      scanGroupViewControllerProvider(widget.groupId).notifier,
    );
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (documentScannerCaptureSupported)
              ListTile(
                leading: const Icon(Icons.document_scanner_outlined),
                title: const Text('Scan more pages'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _scanMore(controller);
                },
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Import existing image pages'),
              onTap: () {
                Navigator.pop(sheetContext);
                _importMore(controller);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanMore(ScanGroupViewController controller) async {
    if (!documentScannerCaptureSupported) return;
    final granted = await ScanPermissionService.requestCamera();
    if (!granted) {
      _message('Camera permission was not granted.');
      return;
    }
    final paths = await CunningDocumentScanner.getPictures(
      isGalleryImportAllowed: true,
    );
    if (paths == null || paths.isEmpty) return;
    await _run(() => controller.addScans(paths));
  }

  Future<void> _importMore(ScanGroupViewController controller) async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
    );
    final paths = result?.whereType<String>().toList(growable: false);
    if (paths == null || paths.isEmpty) return;
    await _run(() => controller.addScans(paths));
  }

  Future<void> _openPage(
    ScanEntry scan,
    ScanGroupViewController controller,
  ) async {
    final state = ref.read(scanGroupViewControllerProvider(widget.groupId));
    if (state.selectionMode) {
      if (scan.id != null) controller.toggleSelection(scan.id!);
      return;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ScannerDetailScreen(scan: scan)));
    await controller.load();
  }

  Future<void> _exportPdf(String title, List<ScanEntry> scans) async {
    await _run(() async {
      final file = await ScanPdfService.createPdf(title: title, scans: scans);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(file: file, title: title),
        ),
      );
    });
  }

  Future<void> _sharePdf(String title, List<ScanEntry> scans) async {
    await _run(() async {
      final file = await ScanPdfService.createPdf(title: title, scans: scans);
      await SharePlus.instance.share(
        ShareParams(title: title, files: [XFile(file.path)]),
      );
    });
  }

  Future<void> _saveGallery(String title, List<ScanEntry> scans) async {
    await _run(() async {
      final count = await ScanGalleryService.saveGroup(
        title: title,
        scans: scans,
      );
      if (mounted) {
        showSnackbar(
          context,
          'Saved successfully',
          '$count image(s) saved to gallery',
          ContentType.success,
        );
      }
    });
  }

  Future<void> _showInfo(ScanGroupViewState state) async {
    final totalBytes = state.scans.fold<int>(
      0,
      (sum, scan) => sum + scan.fileSize,
    );
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(state.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Text('${state.scans.length} page(s)'),
              Text('${_formatBytes(totalBytes)} managed offline storage'),
              Text(
                '${state.scans.where((scan) => scan.version > 1).length} edited page(s)',
              ),
              const SizedBox(height: 10),
              const Text(
                'Drag pages to reorder them. PDF export follows the visible page order.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        showSnackbar(
          context,
          'Operation failed',
          error.toString(),
          ContentType.failure,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PageCard extends StatelessWidget {
  const _PageCard({
    super.key,
    required this.scan,
    required this.pageNumber,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onSelectionTap,
    required this.onDuplicate,
    required this.onDelete,
  });

  final ScanEntry scan;
  final int pageNumber;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onSelectionTap;
  final VoidCallback onDuplicate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final file = File(scan.currentPath);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: selectionMode ? onSelectionTap : onTap,
        onLongPress: onLongPress,
        child: Stack(
          fit: StackFit.expand,
          children: [
            file.existsSync()
                ? Image.file(
                    file,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Center(child: Icon(Icons.broken_image_outlined)),
                  )
                : const Center(child: Icon(Icons.broken_image_outlined)),
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Page $pageNumber${scan.version > 1 ? ' • v${scan.version}' : ''}',
                  style: const TextStyle(color: Colors.white, fontSize: 9),
                ),
              ),
            ),
            if (selectionMode)
              Positioned(
                top: 6,
                left: 6,
                child: Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: Colors.white,
                ),
              )
            else
              Positioned(
                top: 0,
                right: 0,
                child: PopupMenuButton<String>(
                  iconColor: Colors.white,
                  color: Theme.of(context).colorScheme.surface,
                  onSelected: (value) {
                    if (value == 'duplicate') onDuplicate();
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.state,
    required this.controller,
    required this.onExportPdf,
    required this.onSharePdf,
    required this.onSaveGallery,
    required this.onAdd,
  });

  final ScanGroupViewState state;
  final ScanGroupViewController controller;
  final Future<void> Function(List<ScanEntry>) onExportPdf;
  final Future<void> Function(List<ScanEntry>) onSharePdf;
  final Future<void> Function(List<ScanEntry>) onSaveGallery;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scans = state.selectionMode ? controller.selectedScans : state.scans;
    final enabled = scans.isNotEmpty;
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: state.selectionMode
            ? [
                IconButton(
                  tooltip: 'Select all',
                  onPressed: controller.selectAll,
                  icon: const Icon(Icons.select_all),
                ),
                IconButton(
                  tooltip: 'Export selected PDF',
                  onPressed: enabled ? () => onExportPdf(scans) : null,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                ),
                IconButton(
                  tooltip: 'Duplicate selected',
                  onPressed: enabled ? controller.duplicateSelectedScans : null,
                  icon: const Icon(Icons.copy_all_outlined),
                ),
                IconButton(
                  tooltip: 'Delete selected',
                  onPressed: enabled ? controller.deleteSelectedScans : null,
                  icon: const Icon(Icons.delete_outline),
                ),
                IconButton(
                  tooltip: 'Cancel selection',
                  onPressed: controller.clearSelection,
                  icon: const Icon(Icons.close),
                ),
              ]
            : [
                IconButton(
                  tooltip: 'Add pages',
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                ),
                IconButton(
                  tooltip: 'Edit and export PDF',
                  onPressed: enabled ? () => onExportPdf(scans) : null,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                ),
                IconButton(
                  tooltip: 'Share PDF',
                  onPressed: enabled ? () => onSharePdf(scans) : null,
                  icon: const Icon(Icons.share_outlined),
                ),
                IconButton(
                  tooltip: 'Save pages to gallery',
                  onPressed: enabled ? () => onSaveGallery(scans) : null,
                  icon: const Icon(Icons.photo_library_outlined),
                ),
                IconButton(
                  tooltip: 'Select pages',
                  onPressed: enabled
                      ? () => controller.enableSelectionMode(true)
                      : null,
                  icon: const Icon(Icons.checklist),
                ),
              ],
      ),
    );
  }
}
