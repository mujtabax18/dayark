import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../hardware/ai_hardware.dart';
import '../model_manager/model_catalogue.dart';
import 'ai_defaults.dart';
import 'ai_local_models.dart';

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
  final Map<String, String> _selectedVariants = {};
  final _scrollController = ScrollController();

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

  AiModelRecommendation _fit(AiCatalogueModel model) => const AiModelRecommender().classify(
    _hardware, model, installed: widget.models.installed.where((m) => m.id == model.id).firstOrNull?.detectedModel,
  );

  IconData _fitIcon(AiModelFit fit) => switch (fit) {
    AiModelFit.lightweight => Icons.bolt,
    AiModelFit.smooth => Icons.check_circle_outline,
    AiModelFit.balanced => Icons.speed,
    AiModelFit.heavy || AiModelFit.veryHeavy => Icons.local_fire_department_outlined,
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

  void _details(AiCatalogueModel? model, {AiLocalInstallation? installed}) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => ListenableBuilder(
        listenable: widget.models,
        builder: (context, _) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  model?.name ?? installed!.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (model != null) ...[
                  Text(
                    '${model.quantization}${installed == null ? ' · Context detected after download' : ''}',
                  ),
                  if (model.metadata['familyReleaseDate'] case final date?)
                    Text('Family released: $date'),
                  Text(_fit(model).label),
                  ..._fit(model).reasons.map((reason) => Text(reason)),
                  Text('License: ${model.license}'),
                  Text('Languages: ${model.languages.join(', ')}'),
                  Text(
                    'Estimated model memory: ${_size(_fit(model).memoryBytes)}',
                  ),
                  if (model.metadata['evidence'] case final evidence?)
                    Text(
                      'Publisher information: ${evidence.replaceAll('_', ' ')}',
                    ),
                  if (model.metadata['notes'] case final notes?) Text(notes),
                  TextButton.icon(
                    onPressed: () => _openUrl(model.source),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Publisher / license'),
                  ),
                  if (model.downloadUrl case final url?)
                    TextButton.icon(
                      onPressed: () => _openUrl(url),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Open download link'),
                    ),
                ],
                if (installed != null) ...[
                  if (installed.detectedModel case final detected?) ...[
                    Text('Architecture: ${detected.architecture ?? 'Unknown'}'),
                    Text('Native context: ${detected.nativeContextSize ?? 'Unknown'} tokens'),
                    Text('Automatic context: ${detected.contextSize} tokens'),
                    if (detected.activeContextSize != null) Text('Active context: ${detected.activeContextSize} tokens'),
                    if (detected.fileType != null) Text('GGUF file type: ${detected.fileType}'),
                    if (detected.performance case final performance?) ...[
                      if (performance.tokensPerSecond != null) Text('Last run: ${performance.tokensPerSecond!.toStringAsFixed(1)} tokens/s'),
                      if (performance.peakProcessRssBytes != null) Text('Sampled process RAM: ${_size(performance.peakProcessRssBytes)}'),
                      if (performance.loadMilliseconds != null) Text('Last load: ${performance.loadMilliseconds} ms'),
                    ],
                  ],
                  Text('Revision: ${installed.revision}'),
                  SelectableText('SHA-256: ${installed.sha256}'),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (widget.models.loadedId == installed.id)
                        TextButton.icon(
                          onPressed: widget.models.busy
                              ? null
                              : widget.models.unload,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: const Text('Unload'),
                        ),
                      TextButton.icon(
                        onPressed: widget.models.busy
                            ? null
                            : () => widget.models.measure(installed.id),
                        icon: const Icon(Icons.speed),
                        label: const Text('Benchmark'),
                      ),
                    ],
                  ),
                  if (widget.models.benchmark != null)
                    Text(widget.models.benchmark!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(
    AiCatalogueModel? model, {
    AiLocalInstallation? installed,
    bool recommended = false,
  }) {
    final session = widget.models;
    final fit = model == null ? null : _fit(model);
    final id = model?.id ?? installed!.id;
    recommended = fit?.fit.recommended ?? false;
    final active = session.loadedId == id;
    final selected = widget.selectedId == id;
    final theme = Theme.of(context);
    return Card(
      color: active ? theme.colorScheme.primaryContainer : null,
      shape: active || recommended
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.colorScheme.primary,
                width: active ? 2 : 1,
              ),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (active)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.check_circle,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                Expanded(
                  child: Text(
                    model?.name ?? installed!.name,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (recommended)
                  Tooltip(
                    message: 'Best model and quantization for this family on your device',
                    child: Icon(
                      Icons.auto_awesome,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (model?.parameters case final count?)
                  '${count < 1 ? '${(count * 1000).round()}M' : '${count}B'} params',
                if (model != null) model.quantization,
                '${model?.artifact == null && installed == null ? '≈' : ''}${_size(installed?.bytes ?? model?.artifact?.bytes ?? model?.estimatedDiskBytes)}',
                if (fit != null) '≈${_size(fit.memoryBytes)} RAM',
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
            if (fit != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _fitIcon(fit.fit),
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        fit.label,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                if (active || selected || recommended)
                  Text(
                    active
                        ? 'Active'
                        : selected
                        ? 'Selected'
                        : 'Recommended',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => _details(model, installed: installed),
                  child: const Text('View More'),
                ),
                if (installed != null) ...[
                  IconButton(
                    tooltip: 'Use model',
                    onPressed: session.busy
                        ? null
                        : () => Navigator.pop(context, id),
                    icon: Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                  ),
                  IconButton(
                    tooltip: active ? 'Model active' : 'Load model',
                    onPressed: session.busy || active
                        ? null
                        : () => session.load(id),
                    icon: const Icon(Icons.play_arrow_rounded),
                  ),
                  IconButton(
                    tooltip: 'Delete model',
                    onPressed: session.busy ? null : () => _delete(installed),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ] else
                  IconButton(
                    tooltip: 'Download ${model!.quantization}',
                    onPressed: session.busy || !model.downloadable
                        ? null
                        : () => _install(model),
                    icon: const Icon(Icons.download_outlined),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Iterable<Widget> _downloadRows(AiModelFamily family) sync* {
    final groups = <String, List<AiCatalogueModel>>{};
    for (final model in family.models) {
      groups.putIfAbsent(model.name, () => []).add(model);
    }
    for (final group in groups.entries) {
      final variants = group.value;
      final recommended = variants
          .where((m) => m.id == family.recommendedId)
          .firstOrNull;
      final selected =
          variants
              .where((m) => m.id == _selectedVariants[group.key])
              .firstOrNull ??
          recommended ??
          variants.first;
      Widget recommendation(AiCatalogueModel model) =>
          model.id == family.recommendedId
          ? Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                Icons.auto_awesome,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : const SizedBox.shrink();
      yield Column(
        key: ValueKey('download-model-${group.key}'),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.key,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      DropdownButton<String>(
                        key: ValueKey('model-version-${group.key}'),
                        value: selected.id,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        menuMaxHeight: 420,
                        borderRadius: BorderRadius.circular(16),
                        items: variants
                            .map(
                              (model) => DropdownMenuItem(
                                value: model.id,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${model.quantization} · ${model.artifact == null ? '≈' : ''}${_size(model.artifact?.bytes ?? model.estimatedDiskBytes)}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    recommendation(model),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: widget.models.busy
                            ? null
                            : (id) {
                                if (id != null) {
                                  setState(
                                    () => _selectedVariants[group.key] = id,
                                  );
                                }
                              },
                      ),
                      Row(children: [Icon(_fitIcon(_fit(selected).fit), size: 16), const SizedBox(width: 4), Expanded(child: Text(_fit(selected).label, style: Theme.of(context).textTheme.bodySmall))]),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Model details',
                  onPressed: () => _details(selected),
                  icon: const Icon(Icons.info_outline, size: 20),
                ),
                IconButton.filled(
                  tooltip: 'Download ${selected.quantization}',
                  onPressed: widget.models.busy || !selected.downloadable
                      ? null
                      : () => _install(selected),
                  icon: const Icon(Icons.download_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
      );
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
              f.models.where((m) => !excluded.contains(m.id)).toList(),
              f.recommendedId,
            ),
          )
          .where((f) => f.models.isNotEmpty)
          .toList();
      final visibleCount = families.fold<int>(0, (n, f) => n + f.models.length);
      return Scaffold(
        appBar: AppBar(
          title: const Text('Local model manager'),
          actions: [
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
                      ...models.installed.map(
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
