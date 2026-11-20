import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

import '../hardware/ai_hardware.dart';
import '../model_manager/model_catalogue.dart';
import 'ai_defaults.dart';
import 'ai_local_models.dart';

part 'ai_local_models_cards.dart';
part 'ai_local_models_details.dart';
part 'ai_local_models_library.dart';

class AiLocalModelsScreen extends StatefulWidget {
  const AiLocalModelsScreen({
    super.key,
    required this.models,
    required this.defaults,
    this.selectedId,
  });
  final AiLocalModels models;
  final AiDefaults defaults;
  final String? selectedId;
  @override
  State<AiLocalModelsScreen> createState() => _AiLocalModelsScreenState();
}

class _AiLocalModelsScreenState extends State<AiLocalModelsScreen> {
  void _update(VoidCallback change) => setState(change);
  final _scrollController = ScrollController();
  final Map<String, String> _selectedVariants = {};
  final Set<String> _favourites = {};
  final Set<String> _comparison = {};
  List<String> _recent = [];
  String _section = 'All models', _query = '', _sort = 'Name';
  String? _quantization;
  bool _compatibleOnly = false;
  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _size(int? bytes) {
    if (bytes == null) return 'Unknown';
    if (bytes < aiGiB) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MiB';
    }
    return '${(bytes / aiGiB).toStringAsFixed(1)} GiB';
  }

  AiCatalogueModel? _entry(String id) =>
      widget.defaults.catalogue.models.where((m) => m.id == id).firstOrNull;

  AiHardwareReport get _hardware =>
      widget.models.hardware ??
      AiHardwareReport(
        platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
        cpu: 'Unknown',
        logicalCores: 0,
        runtimeSupported: widget.models.supported ? null : false,
      );

  AiModelRecommendation _fit(AiCatalogueModel model) =>
      const AiModelRecommender().classify(
        _hardware,
        model,
        installed: widget.models.installed
            .where((m) => m.id == model.id)
            .firstOrNull
            ?.detectedModel,
      );

  IconData _fitIcon(AiModelFit fit) => switch (fit) {
    AiModelFit.lightweight => Icons.bolt,
    AiModelFit.smooth => Icons.check_circle_outline,
    AiModelFit.balanced => Icons.speed,
    AiModelFit.heavy ||
    AiModelFit.veryHeavy => Icons.local_fire_department_outlined,
    AiModelFit.unsupported => Icons.block,
    AiModelFit.unknown => Icons.memory,
  };

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(body)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _install(AiCatalogueModel model) async {
    if (kIsWeb && model.downloadUrl != null) {
      await _openUrl(model.downloadUrl!);
      return;
    }
    final a = model.artifact;
    final fit = _fit(model);
    final warning = '${fit.label}: ${fit.reasons.join(' ')}\n\n';
    if (await _confirm(
      'Download ${model.name} · ${model.quantization}?',
      '$warning${_size(a?.bytes ?? model.estimatedDiskBytes)}${a == null ? ' (estimate)' : ''} from ${model.source.host}.\n\n'
          'License: ${model.license}\n'
          '${a == null ? 'Exact size, immutable revision and SHA-256 will be resolved from the publisher before downloading.' : 'Revision: ${a.revision}\nSHA-256: ${a.sha256}'}\n\n'
          'Installation verifies size and checksum. Runtime compatibility is confirmed when loading.',
      'Download and install',
    )) {
      await widget.models.install(model);
      if (mounted &&
          _scrollController.hasClients &&
          widget.models.installed.any((m) => m.id == model.id)) {
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Future<void> _delete(AiLocalInstallation model) async {
    if (await _confirm(
      'Delete ${model.name}?',
      'Remove ${_size(model.bytes)} from this device? Profiles using it will need another installed model.',
      'Delete',
    )) {
      await widget.models.delete(model.id);
    }
  }

  Future<void> _openUrl(Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Unable to open link.')));
    }
  }

  Widget _progress() {
    final session = widget.models;
    final entry = session.downloadingId == null
        ? null
        : _entry(session.downloadingId!);
    final downloading = session.downloadingId != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    downloading
                        ? '${entry?.name ?? session.downloadingId} · ${entry?.quantization ?? ''}'
                        : 'Working…',
                  ),
                ),
                IconButton(
                  tooltip: 'Cancel operation',
                  onPressed: session.cancel,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            LinearProgressIndicator(value: session.progress),
            if (downloading)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${session.progress == null
                      ? 'Preparing download'
                      : session.progress! >= 1
                      ? 'Verifying'
                      : 'Downloading ${(session.progress! * 100).toStringAsFixed(1)}%'}'
                  ' · ${_size(session.downloadedBytes)} / ${session.progress == null ? '≈' : ''}${_size(session.downloadTotalBytes)}',
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.models,
    builder: (context, _) {
      final models = widget.models;
      final h = _hardware;
      final excluded = {
        ...models.installed.map((m) => m.id),
        if (models.downloadingId != null) models.downloadingId!,
      };
      final allFamilies = AiModelFamily.grouped(h, widget.defaults.catalogue);
      final recommendedIds = allFamilies.map((f) => f.recommendedId).toSet();
      final families = allFamilies
          .map(
            (f) => AiModelFamily(
              f.name,
              f.models
                  .where(
                    (m) =>
                        !excluded.contains(m.id) &&
                        _matches(m.id, m.name, recommendedIds),
                  )
                  .toList()
                ..sort(_compare),
              f.recommendedId,
            ),
          )
          .where((f) => f.models.isNotEmpty)
          .toList();
      families.sort((a, b) => _compare(a.models.first, b.models.first));
      final visibleCount = families.fold<int>(0, (n, f) => n + f.models.length);
      return Scaffold(
        appBar: AppBar(
          title: const Text('Local model manager'),
          actions: [
            if (_comparison.isNotEmpty)
              TextButton(
                onPressed: _compareModels,
                child: Text('Compare (${_comparison.length})'),
              ),
            if (models.supportsImport)
              IconButton(
                tooltip: 'Import local GGUF',
                icon: const Icon(Icons.file_open_outlined),
                onPressed: models.busy
                    ? null
                    : () async {
                        final files = await FilePicker.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['gguf'],
                        );
                        final file = files.firstOrNull;
                        if (file?.path != null) {
                          await models.importFile(file!.path!, name: file.name);
                        }
                      },
              ),
            IconButton(
              tooltip: 'Refresh hardware and installations',
              onPressed: models.busy ? null : models.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search models, families and quantizations',
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final section in [
                        'Recommended',
                        'Installed',
                        'Favourites',
                        'Recently used',
                        'All models',
                        'Downloads',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(section),
                            selected: _section == section,
                            onSelected: (_) =>
                                setState(() => _section = section),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DropdownButton<String>(
                        value: _sort,
                        items: [
                          for (final sort in [
                            'Name',
                            'Download size',
                            'Memory estimate',
                            'Favourites',
                            'Recently used',
                          ])
                            DropdownMenuItem(value: sort, child: Text(sort)),
                        ],
                        onChanged: (value) => setState(() => _sort = value!),
                      ),
                      DropdownButton<String>(
                        hint: const Text('All quantizations'),
                        value: _quantization,
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('All quantizations'),
                          ),
                          for (final q
                              in widget.defaults.catalogue.models
                                  .map((m) => m.quantization)
                                  .toSet()
                                  .toList()
                                ..sort())
                            DropdownMenuItem(value: q, child: Text(q)),
                        ],
                        onChanged: (value) =>
                            setState(() => _quantization = value),
                      ),
                      FilterChip(
                        label: const Text('Recommended memory fit'),
                        selected: _compatibleOnly,
                        onSelected: (value) =>
                            setState(() => _compatibleOnly = value),
                      ),
                      Text(
                        'Storage: ${_size(models.installed.fold<int>(0, (total, m) => total + m.bytes))}',
                      ),
                    ],
                  ),
                ),
                if (models.busy)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: _progress(),
                  ),
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Downloaded models',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (models.installed.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('No models downloaded yet.'),
                        ),
                      ...models.installed
                          .where((m) => _matches(m.id, m.name, recommendedIds))
                          .map(
                            (m) => _row(
                              _entry(m.id),
                              installed: m,
                              recommended: recommendedIds.contains(m.id),
                            ),
                          ),
                      if (models.status != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            models.status!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        leading: const Icon(Icons.memory),
                        title: Text(
                          'Your device · ${_size(h.totalMemoryBytes)} RAM',
                        ),
                        subtitle: Text(
                          h.cpu,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        children: [
                          ListTile(
                            title: Text(
                              'Available RAM: ${_size(h.availableMemoryBytes)}\nFree storage: ${_size(h.freeStorageBytes)}\nGPU: ${h.gpu ?? 'Unknown'}',
                            ),
                            subtitle: Text(h.notes.join('\n')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Download catalogue',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '$visibleCount available variants · recommendations are advisory',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (families.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'All catalogue models are downloaded or downloading.',
                          ),
                        ),
                      ...families.expand(_downloadRows),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
