import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../model_manager/model_catalogue.dart';
import 'ai_defaults.dart';
import 'ai_local_models.dart';

class AiLocalModelsScreen extends StatefulWidget {
  const AiLocalModelsScreen({
    super.key,
    required this.models,
    required this.defaults,
  });
  final AiLocalModels models;
  final AiDefaults defaults;
  @override
  State<AiLocalModelsScreen> createState() => _AiLocalModelsScreenState();
}

class _AiLocalModelsScreenState extends State<AiLocalModelsScreen> {
  String _size(int? bytes) =>
      bytes == null ? 'Unknown' : '${(bytes / aiGiB).toStringAsFixed(2)} GiB';
  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
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
    final a = model.artifact!;
    if (await _confirm(
      'Download ${model.name}?',
      '${_size(a.bytes)} will be downloaded from ${a.url.host}.\n\n'
          'License: ${model.license}\nSource: ${model.source}\n'
          'Revision: ${a.revision}\nSHA-256: ${a.sha256}\n\n'
          'This authorizes this model download only. Installation verifies size and checksum. '
          'Runtime compatibility is confirmed when loading.',
      'Download and install',
    )) {
      await widget.models.install(model);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.models,
    builder: (context, _) {
      final models = widget.models;
      final h = models.hardware;
      final recommendations = h == null
          ? <AiModelRecommendation>[]
          : const AiModelRecommender().recommend(h, widget.defaults.catalogue);
      return PopScope(
        canPop: !models.busy,
        child: Scaffold(
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
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (models.busy) ...[
                    LinearProgressIndicator(value: models.progress),
                    Text(
                      models.progress == null
                          ? 'Working…'
                          : 'Downloading ${(models.progress! * 100).toStringAsFixed(1)}%',
                    ),
                    TextButton(
                      onPressed: models.cancel,
                      child: const Text('Cancel operation'),
                    ),
                  ],
                  if (models.status != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(models.status!),
                    ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your device',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            h == null
                                ? 'Hardware report unavailable.'
                                : '${h.cpu} · ${h.logicalCores} cores\n'
                                      'Available RAM: ${_size(h.availableMemoryBytes)} / ${_size(h.totalMemoryBytes)}\n'
                                      'Free model storage: ${_size(h.freeStorageBytes)}\nGPU: ${h.gpu ?? 'Unknown'} · VRAM: ${_size(h.vramBytes)}',
                          ),
                          if (!models.supported)
                            const Text(
                              'Local inference is unsupported on this device. Choose an online or self-hosted provider.',
                            ),
                          if (h != null) ...h.notes.map((note) => Text(note)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Installed models',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (models.installed.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'No models installed. Choose a verified download below.',
                      ),
                    ),
                  ...models.installed.map(
                    (m) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${_size(m.bytes)} · ${models.loadedId == m.id ? 'Loaded' : 'Installed'}\nRevision: ${m.revision}',
                            ),
                            Wrap(
                              spacing: 8,
                              children: [
                                FilledButton(
                                  onPressed: models.busy
                                      ? null
                                      : () => Navigator.pop(context, m.id),
                                  child: const Text('Use model'),
                                ),
                                OutlinedButton(
                                  onPressed: models.busy || !models.supported
                                      ? null
                                      : () => models.load(m.id),
                                  child: const Text('Load'),
                                ),
                                if (models.loadedId == m.id)
                                  OutlinedButton(
                                    onPressed: models.busy
                                        ? null
                                        : models.unload,
                                    child: const Text('Unload'),
                                  ),
                                OutlinedButton(
                                  onPressed: models.busy || !models.supported
                                      ? null
                                      : () => models.measure(m.id),
                                  child: const Text('Benchmark'),
                                ),
                                TextButton(
                                  onPressed: models.busy
                                      ? null
                                      : () async {
                                          if (await _confirm(
                                            'Delete ${m.name}?',
                                            'Remove ${_size(m.bytes)} from this device? Profiles using it will need another installed model.',
                                            'Delete',
                                          )) {
                                            await models.delete(m.id);
                                          }
                                        },
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (models.benchmark != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(models.benchmark!),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Download catalogue',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Text(
                    'Estimates include a RAM/storage reserve. A candidate still needs a successful load test. Larger entries without verified artifacts cannot be downloaded.',
                  ),
                  ...widget.defaults.catalogue.models.map((m) {
                    final fit = recommendations
                        .where((r) => r.model.id == m.id)
                        .firstOrNull;
                    final installed = models.installed
                        .where((i) => i.id == m.id)
                        .firstOrNull;
                    final current =
                        installed != null &&
                        installed.sha256 == m.artifact?.sha256.toLowerCase() &&
                        installed.revision == m.artifact?.revision;
                    final enabled =
                        !models.busy &&
                        models.supported &&
                        m.artifact != null &&
                        !current &&
                        fit?.fit != AiModelFit.insufficient;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${m.quantization} · ${m.contextSize} context\n'
                              'Estimated RAM: ${_size(m.estimatedRamBytes)} · Download: ${_size(m.artifact?.bytes ?? m.estimatedDiskBytes)}\n'
                              'Languages: ${m.languages.join(', ')}\nLicense: ${m.license}',
                            ),
                            Text(
                              m.artifact == null
                                  ? 'Not downloadable — verified artifact required.'
                                  : current
                                  ? 'Installed — up to date'
                                  : fit?.fit == AiModelFit.candidate
                                  ? 'Hardware fit: candidate'
                                  : fit?.fit == AiModelFit.insufficient
                                  ? 'Hardware fit: insufficient'
                                  : 'Hardware fit: unknown',
                            ),
                            if (fit != null)
                              ...fit.reasons.map((reason) => Text(reason)),
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    if (!await launchUrl(
                                          m.source,
                                          mode: LaunchMode.externalApplication,
                                        ) &&
                                        context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Unable to open publisher page.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text('Publisher / license'),
                                ),
                                FilledButton(
                                  onPressed: enabled ? () => _install(m) : null,
                                  child: Text(
                                    installed == null ? 'Download' : 'Update',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
