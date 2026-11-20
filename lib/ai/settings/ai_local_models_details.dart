part of 'ai_local_models_screen.dart';

extension _AiModelDetails on _AiLocalModelsScreenState {
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
                    Text(
                      'Native context: ${detected.nativeContextSize ?? 'Unknown'} tokens',
                    ),
                    Text('Automatic context: ${detected.contextSize} tokens'),
                    if (detected.activeContextSize != null)
                      Text(
                        'Active context: ${detected.activeContextSize} tokens',
                      ),
                    if (detected.fileType != null)
                      Text('GGUF file type: ${detected.fileType}'),
                    if (detected.performance case final performance?) ...[
                      if (performance.tokensPerSecond != null)
                        Text(
                          'Last run: ${performance.tokensPerSecond!.toStringAsFixed(1)} tokens/s',
                        ),
                      if (performance.peakProcessRssBytes != null)
                        Text(
                          'Sampled process RAM: ${_size(performance.peakProcessRssBytes)}',
                        ),
                      if (performance.loadMilliseconds != null)
                        Text('Last load: ${performance.loadMilliseconds} ms'),
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
}
